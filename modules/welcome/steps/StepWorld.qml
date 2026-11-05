import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.modules.stage
import qs.services

// Every planet turning on its own, the one you live on marked by a star
RowLayout {
    spacing: 8

    Repeater {
        model: Planets.all

        Item {
            id: choice

            required property var modelData
            readonly property bool current: modelData.id === Theme.planet.id

            Layout.fillWidth: true
            Layout.preferredHeight: 168

            PlanetView {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 124
                height: 124
                planet: choice.modelData
                spinning: true
                scale: pointer.containsMouse || choice.current ? 1.06 : 1

                Behavior on scale {
                    NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 128
                text: choice.modelData.name
                color: choice.current ? Theme.text : Qt.alpha(Theme.text, 0.65)
                font.family: Theme.font
                font.pixelSize: 14
            }

            Star {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 152
                size: 4
                lit: true
                animated: false
                opacity: choice.current ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.fast }
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
                    Planet.changeWorld(choice.modelData.id);
                }
            }
        }
    }
}
