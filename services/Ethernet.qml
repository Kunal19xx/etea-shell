pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether a cable carries the connection. Quickshell's Networking only lists Wi-Fi cards,
// so this asks NetworkManager itself, again each time it says something changed.
Singleton {
    id: root

    property bool connected: false

    Process {
        id: reader

        running: true
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: root.connected = text.split("\n").some(line => line === "ethernet:connected")
        }
    }

    // A cable plugged in or out, a connection going up or down: read again, once it's settled
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: reader.running = true
    }
}
