import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.stage

// One world per screen, all the way at the back, under the windows.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        screen: modelData
        color: Theme.skyTop
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "etea:background"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        World {
            id: world

            anchors.fill: parent
            // Hyprland's slide moves the windows only, the world stays where it is. With the
            // orbit plugin the stage stays out of the way, so this world turns with the page.
            angle: Config.pageTransition === "slide" ? 0 : Planet.resting + (Planet.nativeTurn ? Planet.travel : 0)
            interactive: true
        }

        // How smoothly this world turned under the plugin's windows
        FrameMeter {
            name: "orbit"
            running: Planet.nativeTurn && Compositor.focusedOutput === modelData.name
        }

        // The background of the focused screen, saved to a file, to check a change unseen
        Connections {
            target: Skies

            function onBackgroundWanted(path) {
                if (Compositor.focusedOutput === modelData.name)
                    world.grabToImage(result => console.info(`ETEA background grab: ${result.saveToFile(path) ? path : "failed"}`));
            }
        }
    }
}
