#!/bin/bash

KSCREEN_DIR="$HOME/.local/share/kscreen"
LOCK_FILE="/run/user/$(id -u)/kscreen-fix-live.lock"
READY_FILE="/run/user/$(id -u)/dsi1-rotation-ready"

rm -f "$READY_FILE"

fix_file() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except (json.JSONDecodeError, OSError):
    sys.exit(0)

if not isinstance(data, list):
    sys.exit(0)

dsi = next((o for o in data if o.get('metadata', {}).get('name') == 'DSI-1'), None)
if dsi is None:
    sys.exit(0)

changed = False

if dsi.get('priority') != 1:
    old_prio = dsi['priority']
    for o in data:
        if o is dsi:
            o['priority'] = 1
        elif o.get('priority', 0) < old_prio:
            o['priority'] += 1
    changed = True

if dsi.get('rotation') != 8:
    dsi['rotation'] = 8
    changed = True

if dsi.get('scale') != 1.35:
    dsi['scale'] = 1.35
    changed = True

if dsi.get('pos', {}).get('x') != 0 or dsi.get('pos', {}).get('y') != 0:
    dsi['pos'] = {'x': 0, 'y': 0}
    changed = True

hdmi = next((o for o in data if o.get('metadata', {}).get('name') == 'HDMI-A-1'), None)
if hdmi is not None:
    if hdmi.get('pos', {}).get('x') != 948 or hdmi.get('pos', {}).get('y') != 0:
        hdmi['pos'] = {'x': 948, 'y': 0}
        changed = True

if not changed:
    sys.exit(0)

with open(path, 'w') as f:
    json.dump(data, f, indent=4)
    f.write('\n')

print(f"Fixed DSI-1 in {path}", flush=True)
PYEOF
}

# kscreen-doctor exit codes and messages cannot be trusted on this system
# (verified 2026-07-08): naming a missing output (HDMI-A-1 detached) turns the
# ENTIRE apply into a silent no-op that still exits 0 and prints the wanted
# config, while a genuinely applied change can exit 134 (heap-corruption
# SIGABRT after the apply). `-o` also often SIGABRTs AFTER printing correct
# state. So: never name an output that isn't currently listed, and verify by
# reading back stdout only, ignoring exit codes.
dsi1_scale_ok() {
    kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' |
        grep 'DSI-1' | grep -q 'Scale: 1.35'
}

# One invocation = one atomic config apply (a single modeset). Back-to-back
# kscreen-doctor calls have core-dumped on this system (see journal). The
# HDMI-A-1 arg is included only when that output exists — see above. Read the
# scale back after applying and retry until it verifiably holds.
fix_live() {
    (
        flock -x 9
        local i state args
        for ((i = 1; i <= 5; i++)); do
            state=$(kscreen-doctor -o 2>/dev/null)
            args=(output.DSI-1.rotation.right output.DSI-1.scale.1.35
                output.DSI-1.position.0,0)
            [[ "$state" == *HDMI-A-1* ]] && args+=(output.HDMI-A-1.position.948,0)
            kscreen-doctor "${args[@]}" 2>/dev/null
            sleep 1
            if dsi1_scale_ok; then
                echo "Fixed live DSI-1 rotation/scale/position (verified, attempt $i, ${#args[@]} ops)"
                return 0
            fi
        done
        echo "DSI-1 scale 1.35 did NOT stick after 5 attempts"
        return 1
    ) 9>"$LOCK_FILE"
}

# Load a one-shot KWin script to sweep all non-mpv windows to DSI-1.
# DSI-1 is identified by name via supportInformation(), with x=0 as fallback.
sweep_to_dsi1() {
    local tmpfile name
    tmpfile=$(mktemp /tmp/kwin-sweep-XXXXXX.js)
    name="kwin-sweep-dsi1-$$-$RANDOM"
    cat > "$tmpfile" << 'SWEEPEOF'
var dsi1 = 0;
try {
    var info = workspace.supportInformation();
    var m = info.match(/Screen (\d+):\n-+\nName: DSI-1/);
    if (m) {
        dsi1 = parseInt(m[1]);
    } else {
        for (var i = 0; i < workspace.numScreens; i++) {
            var geo = workspace.clientArea(7, i, 1);
            if (geo && geo.x === 0) { dsi1 = i; break; }
        }
    }
} catch(e) {}
var clients = workspace.clientList();
for (var i = 0; i < clients.length; i++) {
    var c = clients[i];
    if (!c || !c.normalWindow) continue;
    if (String(c.resourceClass).toLowerCase() === "mpv") continue;
    if (c.screen !== dsi1) workspace.sendClientToScreen(c, dsi1);
}
SWEEPEOF
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmpfile" "$name" 2>/dev/null || true
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start 2>/dev/null || true
    sleep 1
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$name" 2>/dev/null || true
    rm -f "$tmpfile"
}

# dsi1-early-scale.service normally applies rotation/scale before plasmashell
# first draws, so DSI-1 is usually already correct by the time this service
# starts. In that case touch the ready file immediately so autostart apps
# (see touch-player-launch.sh) can launch right away. Only when the check
# fails (early-scale missed or state regressed) fall back to the original
# wait-fix-sweep path, which also sweeps back windows that drifted onto
# HDMI-A-1 during a live portrait->landscape flip. Judge by stdout only --
# see the exit-code caveats above; an empty read means the backend isn't
# answering yet, so poll briefly before deciding.
(
    boot_ok=""
    for ((i = 0; i < 30; i++)); do
        state=$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
        if [[ -n "$state" ]]; then
            if grep 'DSI-1' <<<"$state" | grep 'Scale: 1.35' | grep -q 'Rotation: 8'; then
                boot_ok=1
                echo "DSI-1 already rotated/scaled at boot; ready immediately"
            fi
            break
        fi
        sleep 0.1
    done
    if [[ -z "$boot_ok" ]]; then
        sleep 5 && fix_live && sleep 1 && sweep_to_dsi1
    fi
    touch "$READY_FILE"
) &

# Watch kscreen config files for priority/rotation fixes, then re-apply live.
# Rotation (portrait<->landscape) goes through this path, not DRM hotplug, and
# can flip which screen *index* maps to which output without changing any
# individual window's screen index -- so client.screenChanged never fires for
# windows stranded on a re-mapped index. Sweep explicitly by name every time.
inotifywait -m -e close_write,moved_to --format '%f' "$KSCREEN_DIR" 2>/dev/null | while read -r name; do
    if [[ ${#name} -eq 32 && "$name" =~ ^[0-9a-f]+$ ]]; then
        fix_file "$KSCREEN_DIR/$name"
        fix_live
        sleep 1
        sweep_to_dsi1
    fi
done &

# Watch for DRM hotplug events, restore DSI-1 settings, then sweep windows back
udevadm monitor --udev --subsystem-match=drm 2>/dev/null | while read -r line; do
    if [[ "$line" == *"change"* ]]; then
        sleep 2
        fix_live
        sleep 1
        sweep_to_dsi1
    fi
done &

wait
