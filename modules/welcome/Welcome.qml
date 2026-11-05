import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// The welcome, at every start until you tick it off. It waits for a fresh start of the
// shell: a live reload while you work on ETEA never brings it back.
Scope {
    id: root

    property int age: -1 // seconds since the shell started
    property bool asked: false

    function greet() {
        if (asked || !Config.ready || age < 0)
            return;
        asked = true;
        Menus.welcomeOpen = Config.welcome && age < 60;
    }

    onAgeChanged: greet()

    Connections {
        target: Config

        function onReadyChanged() {
            root.greet();
        }
    }

    // The shell is the parent of this little shell, so its age is the shell's
    Process {
        running: true
        command: ["sh", "-c", "ps -o etimes= -p $PPID"]
        stdout: StdioCollector {
            onStreamFinished: root.age = parseInt(text) || 0
        }
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            Menus.welcomeOpen = true;
        }
    }

    PanelWindow {
        id: panel

        property real shown: Menus.welcomeOpen ? 1 : 0

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:welcome"
        WlrLayershell.keyboardFocus: Menus.welcomeOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Behavior on shown {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        onVisibleChanged: {
            if (visible)
                sky.forceActiveFocus();
        }

        // Dark enough to read on, light enough to watch your choices land behind
        Rectangle {
            anchors.fill: parent
            color: Theme.launcherShade
            opacity: panel.shown * 0.72
        }

        WelcomeSky {
            id: sky

            anchors.fill: parent
            opacity: panel.shown
            active: Menus.welcomeOpen
            onFinished: Menus.welcomeOpen = false
        }
    }
}
