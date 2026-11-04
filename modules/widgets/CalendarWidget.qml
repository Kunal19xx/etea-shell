import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar
import qs.services

// The month and its moon in a porthole, the card the logbook keeps in the bar.
Item {
    id: root

    property var options: ({})

    implicitWidth: 330
    implicitHeight: content.implicitHeight + 40

    HandCard {
        anchors.fill: parent
        seed: "calendar"
        tint: "#b9a2f0"
        rise: 0.07
        alive: Planet.pageEmpty
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: Qt.locale(Config.locale).toString(Time.now, "MMMM yyyy")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 17
            }

            MoonDisc {
                id: moon

                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                at: Time.now
            }
        }

        Text {
            text: moon.phaseName
            color: Qt.alpha(Theme.text, 0.7)
            font.family: Theme.font
            font.pixelSize: 12
        }

        MonthGrid {
            Layout.fillWidth: true
            month: Time.now
            today: Time.now
            heading: "#b9a2f0"
        }
    }
}
