function watchMpv(client) {
    if (String(client.resourceClass).toLowerCase() !== "mpv") return;
    print("[keep-mpv] tracking window: " + client.caption);
    client.minimizedChanged.connect(function() {
        if (client.minimized) {
            client.minimized = false;
            print("[keep-mpv] restored mpv from minimize");
        }
    });
}

workspace.clientAdded.connect(watchMpv);

workspace.clientMinimized.connect(function(client) {
    if (String(client.resourceClass).toLowerCase() === "mpv") {
        client.minimized = false;
        print("[keep-mpv] blocked minimize on mpv");
    }
});
