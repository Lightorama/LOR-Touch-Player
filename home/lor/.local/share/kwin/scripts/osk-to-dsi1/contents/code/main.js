// Keep non-MPV windows on DSI-1. mpv is the only app allowed on HDMI-A-1.
// Also ensures the OSK appears on DSI-1 since KWin places it on the active output.
//
// DSI-1 is identified by name via workspace.supportInformation(), which maps
// "Screen N: Name: DSI-1" reliably regardless of screen index or geometry.

function findDsi1Index() {
    try {
        var info = workspace.supportInformation();
        var m = info.match(/Screen (\d+):\n-+\nName: DSI-1/);
        if (m) return parseInt(m[1]);
        print("[osk-dsi1] DSI-1 not found in supportInformation, falling back to x=0");
    } catch (e) {
        print("[osk-dsi1] findDsi1Index error: " + e);
    }
    // Fallback: first screen at x=0
    for (var i = 0; i < workspace.numScreens; i++) {
        try {
            var geo = workspace.clientArea(KWin.ScreenArea, i, 1);
            if (geo && geo.x === 0) return i;
        } catch (e2) {}
    }
    return 0;
}

function enforceScreen(client) {
    if (!client || !client.normalWindow) return;
    if (String(client.resourceClass).toLowerCase() === "mpv") return;

    var dsi1 = findDsi1Index();
    print("[osk-dsi1] clientAdded: " + client.resourceClass + " screen=" + client.screen + " dsi1=" + dsi1);

    if (client.screen !== dsi1) {
        workspace.sendClientToScreen(client, dsi1);
        print("[osk-dsi1] moved " + client.resourceClass + " to DSI-1");
    }

    client.screenChanged.connect(function() {
        if (String(client.resourceClass).toLowerCase() === "mpv") return;
        var dsi1 = findDsi1Index();
        if (client.screen !== dsi1) {
            workspace.sendClientToScreen(client, dsi1);
            print("[osk-dsi1] screenChanged: moved " + client.resourceClass + " back to DSI-1");
        }
    });
}

function sweepAllClients() {
    var dsi1 = findDsi1Index();
    print("[osk-dsi1] sweep: dsi1 index=" + dsi1);
    var clients = workspace.clientList();
    for (var i = 0; i < clients.length; i++) {
        var c = clients[i];
        if (!c || !c.normalWindow) continue;
        if (String(c.resourceClass).toLowerCase() === "mpv") continue;
        if (c.screen !== dsi1) {
            workspace.sendClientToScreen(c, dsi1);
            print("[osk-dsi1] sweep: moved " + c.resourceClass + " to DSI-1");
        }
    }
}

try {
    workspace.numberScreensChanged.connect(function(count) {
        print("[osk-dsi1] screen count changed to " + count + ", sweeping clients");
        sweepAllClients();
    });
} catch (e) {
    print("[osk-dsi1] numberScreensChanged unavailable: " + e);
}

sweepAllClients();
workspace.clientAdded.connect(enforceScreen);
