pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The warm screen for the evening, through hyprsunset. If it isn't running yet, the first
// press starts it.
Singleton {
    id: root

    property bool available: false // hyprsunset is installed
    property bool running: false // and answering through hyprctl
    property int temperature: 6500
    readonly property bool on: temperature < 5800
    readonly property int warm: Config.nightWarmth

    // Moving the slider while it's on warms the screen right away
    onWarmChanged: {
        if (on && running) {
            writer.exec(["hyprctl", "hyprsunset", "temperature", String(warm)]);
            temperature = warm;
        }
    }

    function toggle() {
        if (running)
            writer.exec(["hyprctl", "hyprsunset", ...(on ? ["identity"] : ["temperature", String(warm)])]);
        else if (!on) {
            Quickshell.execDetached(["hyprsunset", "-t", String(warm)]);
            settle.restart();
        }
        temperature = on ? 6500 : warm;
        running = true;
    }

    Process {
        id: writer
    }

    Process {
        command: ["sh", "-c", "command -v hyprsunset"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: reader

        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text);
                root.running = !isNaN(value);
                // Without hyprsunset, nothing is warming the screen
                root.temperature = root.running ? value : 6500;
            }
        }
    }

    // Asks again once a freshly started hyprsunset has had time to answer
    Timer {
        id: settle

        interval: 1500
        onTriggered: reader.running = true
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: reader.running = true
    }
}
