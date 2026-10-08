# Shared by the lor-display scripts (sourced, not executed).
#
# The DSI-1 scale is a per-unit setting in ~/.config/lor-display.conf:
#     SCALE=1.5
# Missing file, missing key or an out-of-range value => default 1.35, which is
# what every unit shipped with. The file is parsed, never sourced, because
# Touch Player (or support) writes it.

LOR_DISPLAY_CONF="$HOME/.config/lor-display.conf"
LOR_DISPLAY_DEFAULT_SCALE=1.35
LOR_DISPLAY_MIN_SCALE=1.0
LOR_DISPLAY_MAX_SCALE=1.75   # tested OK with Touch Player + Plasma Mobile panels
# DSI-1 is a 720x1280 panel rotated to landscape: 1280 physical px wide.
DSI1_PANEL_WIDTH=1280

# Prints the normalized scale if $1 is a number within range, else fails.
lor_display_valid_scale() {
    awk -v v="$1" -v lo="$LOR_DISPLAY_MIN_SCALE" -v hi="$LOR_DISPLAY_MAX_SCALE" '
        BEGIN {
            if (v !~ /^[0-9]+(\.[0-9]+)?$/ || v + 0 < lo || v + 0 > hi) exit 1
            printf "%g\n", v
        }'
}

# Sets SCALE (e.g. 1.35) and HDMI_X (HDMI-A-1 x-position = DSI-1 logical
# width, so HDMI sits flush to the right of DSI-1 with no gap or overlap).
# KWin rounds the logical size (1280/1.35 = 948.1 -> 948).
lor_display_load() {
    local raw=""
    SCALE=$LOR_DISPLAY_DEFAULT_SCALE
    if [[ -r "$LOR_DISPLAY_CONF" ]]; then
        raw=$(sed -n 's/^[[:space:]]*SCALE[[:space:]]*=[[:space:]]*["'\'']\{0,1\}\([^"'\''[:space:]]*\).*$/\1/p' \
            "$LOR_DISPLAY_CONF" | tail -n 1)
        if [[ -n "$raw" ]]; then
            if ! SCALE=$(lor_display_valid_scale "$raw"); then
                echo "lor-display: ignoring invalid SCALE='$raw' in $LOR_DISPLAY_CONF, using $LOR_DISPLAY_DEFAULT_SCALE" >&2
                SCALE=$LOR_DISPLAY_DEFAULT_SCALE
            fi
        fi
    fi
    HDMI_X=$(awk -v w="$DSI1_PANEL_WIDTH" -v s="$SCALE" 'BEGIN { printf "%d", w / s + 0.5 }')
}

# True if the given (ANSI-stripped) `kscreen-doctor -o` text shows DSI-1 at
# $SCALE. Compared numerically: kscreen-doctor prints e.g. "Scale: 1.5".
lor_display_state_scale_ok() {
    grep 'DSI-1' <<<"$1" | awk -v want="$SCALE" '
        match($0, /Scale: [0-9.]+/) {
            got = substr($0, RSTART + 7, RLENGTH - 7) + 0
            d = got - want; if (d < 0) d = -d
            if (d < 0.005) ok = 1
        }
        END { exit !ok }'
}

lor_display_state() {
    kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
}

# Keep Xwayland (X11 apps) at the same scale. KWin reads this at startup, so a
# change here takes effect on the next boot.
lor_display_sync_xwayland() {
    local cur
    cur=$(kreadconfig5 --file kwinrc --group Xwayland --key Scale 2>/dev/null)
    if ! awk -v a="$cur" -v b="$SCALE" 'BEGIN { d = a - b; if (d < 0) d = -d; exit !(a != "" && d < 0.005) }'; then
        kwriteconfig5 --file kwinrc --group Xwayland --key Scale "$SCALE"
        echo "lor-display: set kwinrc [Xwayland] Scale=$SCALE (takes effect next boot)"
    fi
}
