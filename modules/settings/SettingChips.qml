import QtQuick
import qs.config
import qs.modules.bar

// One option out of many, like SettingChoice, but the options go on to the next line when
// there are more than fit beside the label.
SettingRow {
    id: root

    property var options: [] // { id, label }
    property string current: ""
    property real room: 400 // how wide the options may spread before wrapping

    signal picked(string id)

    Flow {
        id: flow

        // As wide as one line of them, up to the room there is
        width: Math.min(root.room, line.implicitWidth)
        spacing: 6

        // The options measured side by side, to know when they need a second line
        Row {
            id: line

            visible: false
            spacing: flow.spacing

            Repeater {
                model: root.options

                Item {
                    required property var modelData

                    width: measure.implicitWidth + 30
                    height: 1

                    Text {
                        id: measure

                        text: parent.modelData.label
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                }
            }
        }

        Repeater {
            model: root.options

            Item {
                id: option

                required property var modelData

                readonly property bool active: modelData.id === root.current

                width: name.implicitWidth + 30
                height: 34

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: Theme.windowLit
                    opacity: option.active ? 0.2 : pointer.containsMouse ? 0.09 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.fast }
                    }
                }

                Text {
                    id: name

                    anchors.centerIn: parent
                    text: option.modelData.label
                    color: option.active ? Theme.text : Qt.alpha(Theme.text, 0.7)
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                StarRipple {
                    id: ripple
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        ripple.burst(mouse.x, mouse.y);
                        root.picked(option.modelData.id);
                    }
                }
            }
        }
    }
}
