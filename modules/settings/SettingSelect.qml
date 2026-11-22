import QtQuick
import QtQuick.Controls
import qs.config
import qs.modules.bar

// One option out of many, in a list that unfolds under it. A star marks the one in use.
SettingRow {
    id: root

    property var options: [] // { id, label }
    property string current: ""
    readonly property var chosen: options.find(option => option.id === current) ?? options[0]

    signal picked(string id)

    Item {
        id: button

        implicitWidth: Math.max(150, widest.implicitWidth + 60)
        implicitHeight: 38
        scale: pointer.pressed ? 0.95 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
        }

        // The longest label sets the width, so the button keeps its size as you choose
        Text {
            id: widest

            visible: false
            text: root.options.reduce((longest, option) => option.label.length > longest.length ? option.label : longest, "")
            font.family: Theme.font
            font.pixelSize: 14
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.windowLit
            opacity: list.opened ? 0.3 : pointer.containsMouse ? 0.22 : 0.12

            Behavior on opacity {
                NumberAnimation { duration: Theme.fast }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.chosen?.label ?? ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
        }

        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: "down"
            size: 16
            rotation: list.opened ? 180 : 0

            Behavior on rotation {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
            }
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
                list.opened ? list.close() : list.open();
            }
        }

        // The list unfolds from the button, on a card of its own
        Popup {
            id: list

            y: button.height + 6
            width: Math.max(button.width, widest.implicitWidth + 50 + leftPadding + rightPadding)
            padding: 8
            transformOrigin: Item.Top

            background: HandCard {
                seed: "select-" + root.key
                radius: 14
                rise: 0.1
                starSpacing: 0
                alive: list.visible
            }

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
                NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast }
            }

            contentItem: Column {
                id: column

                spacing: 2

                Repeater {
                    model: root.options

                    Item {
                        id: option

                        required property var modelData

                        readonly property bool active: modelData.id === root.current

                        width: list.availableWidth
                        height: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Theme.windowLit
                            opacity: option.active ? 0.2 : hover.containsMouse ? 0.1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.fast }
                            }
                        }

                        Star {
                            x: 16 - size
                            anchors.verticalCenter: parent.verticalCenter
                            size: option.active ? 5 : 2.5
                            lit: option.active
                            animated: false

                            Behavior on size {
                                NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
                            }
                        }

                        Text {
                            id: name

                            x: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: option.modelData.label
                            color: option.active ? Theme.text : Qt.alpha(Theme.text, 0.75)
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        StarRipple {
                            id: pick
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => pick.burst(mouse.x, mouse.y)
                            onClicked: {
                                root.picked(option.modelData.id);
                                list.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
