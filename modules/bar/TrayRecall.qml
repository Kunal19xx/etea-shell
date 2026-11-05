import QtQuick
import Quickshell
import Quickshell.Io

// Once the shell is up, the apps that were already running get their tray icon back
Scope {
    // The watcher needs a moment to be on the bus
    Timer {
        interval: 2000
        running: true
        onTriggered: recall.running = true
    }

    Process {
        id: recall

        command: ["bash", Quickshell.shellPath("scripts/tray-recall.sh")]
    }
}
