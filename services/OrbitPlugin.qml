pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The orbit plugin, when Hyprland has it: Hyprland turns the windows itself, live, and the
// shell only turns the planet behind them. Without it, the stage's stand-ins do it all.
Singleton {
    id: root

    property bool loaded: false
    // Page changes are the plugin's to draw, as long as the planet is the transition
    readonly property bool turns: loaded && !Compositor.niri && Config.pageTransition === "planet"

    // The planet as the stage draws it, so both turn around the same centre at the same pace
    readonly property string settings: `hl.config({ plugin = { orbit = {
        enabled = ${turns ? 1 : 0},
        pages = ${Config.pages},
        duration = ${Math.round(Theme.pageSpin)},
        terrain_height = ${Theme.terrainHeight},
        terrain_curve = ${Theme.terrainCurve}
    } } })`

    onSettingsChanged: tell()

    function tell() {
        if (!loaded || teller.running)
            return;
        teller.command = ["hyprctl", "eval", settings];
        teller.running = true;
    }

    // A switch whose transition the shell draws itself: the plugin stays out of that one
    function quietFocus(page) {
        return `(function() if hl.plugin and hl.plugin.orbit then hl.plugin.orbit.still() end return hl.dsp.focus({ workspace = ${page} }) end)()`;
    }

    function look() {
        if (Compositor.niri)
            return;
        finder.running = false;
        finder.running = true;
    }

    Process {
        id: finder

        command: ["hyprctl", "plugin", "list", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.loaded = JSON.parse(text).some(plugin => plugin.name === "orbit");
                } catch (e) {
                    root.loaded = false;
                }
                root.tell();
            }
        }
    }

    // The values can be pushed again faster than hyprctl answers, so catch up once it's done
    Process {
        id: teller

        onExited: {
            if (command[2] !== root.settings)
                root.tell();
        }
    }

    // Plugins come and go with the config, and a reload forgets what we told it
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.look();
        }
    }

    Component.onCompleted: look()
}
