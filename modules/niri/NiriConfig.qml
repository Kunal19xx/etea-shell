import QtQuick
import Quickshell
import Quickshell.Io

// On niri, the shortcuts reach ETEA through niri's own binds, written to
// ~/.config/niri/etea.kdl, which the niri config includes. niri merges binds key by key,
// so these only replace the keys they name and live-reloads the file when it changes.
Scope {
    id: root

    readonly property string path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/niri/etea.kdl`

    // Key, what niri shows for it, and the IPC call it makes
    readonly property var binds: [
        ["Mod+Space", "Launcher", "launcher toggle"],
        ["Mod+L", "Lock", "lock lock"],
        ["Mod+A", "Logbook", "panels left"],
        ["Mod+N", "Control centre", "panels right"],
        ["Mod+V", "Clipboard history", "clipboard toggle"],
        ["Mod+Shift+S", "Capture (Tab for video)", "capture toggle"],
        ["Mod+I", "Settings", "settings toggle"],
        ["Ctrl+Mod+T", "Wallpaper", "skies open"],
        ["Mod+Escape", "Session menu", "session toggle"],
        ["Ctrl+Alt+Delete", "Session menu", "session toggle"]
    ]

    readonly property string text: {
        const shell = Quickshell.shellPath("").replace(/\/$/, "");
        const lines = binds.map(([key, title, call]) => {
            const args = ["qs", "-p", shell, "ipc", "call"].concat(call.split(" "));
            return `    ${key} hotkey-overlay-title="ETEA: ${title}" { spawn ${args.map(arg => JSON.stringify(arg)).join(" ")}; }`;
        });
        return `// Written by ETEA Shell each time it starts on niri; changes here don't last.\n// Include it last in config.kdl: include optional=true "etea.kdl"\n\nbinds {\n${lines.join("\n")}\n}\n`;
    }

    // Written only when it differs, so niri isn't asked to reload for nothing
    FileView {
        id: file

        path: root.path
        printErrors: false
        onLoaded: {
            if (text() !== root.text)
                setText(root.text);
        }
        onLoadFailed: setText(root.text)
    }
}
