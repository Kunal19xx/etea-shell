import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.modules.settings
import qs.services

// After a change that could leave a screen dark or unreadable: keep it, or go back. It
// shows on every lit screen, and without an answer the old picture comes back on its own.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            property real shown: Screens.asking ? 1 : 0
            readonly property bool focused: modelData === Compositor.focusedScreen

            screen: modelData
            visible: shown > 0.01
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 420
            implicitHeight: 190
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "etea:screens"
            WlrLayershell.keyboardFocus: Screens.asking && focused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Behavior on shown {
                NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
            }

            Item {
                id: card

                x: 10
                y: 10 + (1 - panel.shown) * 30
                width: 400
                height: 170
                opacity: Math.min(1, panel.shown)
                focus: true

                Keys.onReturnPressed: Screens.keep()
                Keys.onEnterPressed: Screens.keep()
                Keys.onEscapePressed: Screens.undo()

                HandCard {
                    anchors.fill: parent
                    seed: "screens"
                    tint: "#9fd3c7"
                    // The light sinks as the seconds run out
                    rise: 0.04 + 0.2 * Screens.countdown / 15
                    alive: panel.visible
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 6

                    Text {
                        text: Lang.t("Garder cet affichage ?")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 18
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Lang.t("L'ancien revient dans {0} s.", Screens.countdown)
                        color: Qt.alpha(Theme.text, 0.65)
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 10

                        SettingButton {
                            label: Lang.t("Revenir")
                            quiet: true
                            onPicked: Screens.undo()
                        }

                        SettingButton {
                            label: Lang.t("Garder")
                            onPicked: Screens.keep()
                        }
                    }
                }
            }
        }
    }
}
