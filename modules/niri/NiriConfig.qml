import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// On niri, the shortcuts reach ETEA through niri's own binds, and the windows wear ETEA's
// gaps, border and corners, all written to ~/.config/niri/etea.kdl, which the niri config
// includes. niri merges binds key by key and the layout field by field, so this only
// replaces what it names, and it live-reloads the file when it changes.
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

    // niri wants #rrggbbaa
    function hex(color, alpha) {
        const byte = value => Math.round(value * 255).toString(16).padStart(2, "0");
        return `#${byte(color.r)}${byte(color.g)}${byte(color.b)}${byte(alpha)}`;
    }

    // Every window gets the same thin line of the world's light: no focus look on niri.
    // niri's gaps are the inner ones, the struts add what the outer ones have beyond.
    readonly property string looks: {
        const line = hex(Theme.windowLit, Theme.traceLine);
        const edge = Math.max(0, Theme.windowGapOuter - Theme.windowGapInner);
        return `layout {
    gaps ${Theme.windowGapInner}
    struts {
        left ${edge}
        right ${edge}
        top ${edge}
        bottom ${edge}
    }
    focus-ring {
        off
    }
    border {
        on
        width ${Theme.traceWidth}
        active-color "${line}"
        inactive-color "${line}"
        urgent-color "${line}"
    }
}

window-rule {
    geometry-corner-radius ${Theme.windowRadius}
    clip-to-geometry true
}
`;
    }

    readonly property string text: {
        const shell = Quickshell.shellPath("").replace(/\/$/, "");
        const lines = binds.map(([key, title, call]) => {
            const args = ["qs", "-p", shell, "ipc", "call"].concat(call.split(" "));
            return `    ${key} hotkey-overlay-title="ETEA: ${title}" { spawn ${args.map(arg => JSON.stringify(arg)).join(" ")}; }`;
        });
        return `// Written by ETEA Shell each time it starts on niri; changes here don't last.\n// Include it last in config.kdl: include optional=true "etea.kdl"\n\nbinds {\n${lines.join("\n")}\n}\n\n${looks}`;
    }

    // Written only when it differs, so niri isn't asked to reload for nothing, and a moment
    // after a slider stops
    onTextChanged: write.restart()

    Timer {
        id: write

        interval: 300
        onTriggered: {
            if (file.text() !== root.text)
                file.setText(root.text);
        }
    }

    // Super on its own opens the launcher, through a small listener niri can't replace
    Process {
        id: superTap

        running: true
        command: ["python3", Quickshell.shellPath("scripts/super-tap.py"), Quickshell.shellPath("").replace(/\/$/, "")]
        stderr: SplitParser {
            onRead: line => console.warn("ETEA", line)
        }
        // Back after a crash, but not when it can't read the keyboard at all
        onExited: code => {
            if (code !== 1)
                retap.restart();
        }
    }

    Timer {
        id: retap

        interval: 3000
        onTriggered: superTap.running = true
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        onLoaded: write.restart()
        onLoadFailed: write.restart()
    }
}
