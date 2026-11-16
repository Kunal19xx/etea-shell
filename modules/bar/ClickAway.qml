import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// On niri, which has no focus grab, a click anywhere outside a panel or menu closes it:
// a clear veil over the windows, under the open card, catches that click.
PanelWindow {
    id: root

    property bool active: false

    signal clicked()

    screen: Compositor.focusedScreen
    visible: active && Compositor.niri
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "etea:click-away"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.clicked()
    }
}
