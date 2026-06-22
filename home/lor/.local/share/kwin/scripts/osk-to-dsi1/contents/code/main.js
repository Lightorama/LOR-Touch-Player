// Keep non-MPV windows on DSI-1 and warp cursor to DSI-1 so KWin's
// activeOutput() returns DSI-1 when the OSK is triggered.
// KWin places the OSK on activeOutput(), which follows the mouse cursor
// position when the keyboard is shown.

var DSI1_CENTER = Qt.point(474, 266); // center of DSI-1 (948x533)

function enforceScreen(client) {
    if (!client || !client.normalWindow) return;
    if (String(client.resourceClass).toLowerCase() === "mpv") return;

    print("[osk-dsi1] clientAdded: " + client.resourceClass + " screen=" + client.screen);

    if (client.screen === 1) {
        workspace.sendClientToScreen(client, 0);
        print("[osk-dsi1] moved to DSI-1, cursor warp to " + DSI1_CENTER);
    }

    // Re-check on any subsequent screen changes (e.g. drag to HDMI-A-1)
    client.screenChanged.connect(function() {
        if (client.screen === 1 &&
            String(client.resourceClass).toLowerCase() !== "mpv") {
            workspace.sendClientToScreen(client, 0);
        }
    });
}

workspace.clientAdded.connect(enforceScreen);
