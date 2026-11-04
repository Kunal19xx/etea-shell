import QtQuick
import Quickshell
import qs.config
import qs.services

// The time up front, the date right next to it. A click opens the calendar.
Item {
    id: root

    readonly property date now: Config.clockSeconds ? Time.exact : Time.now

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Config.time(root.now, { seconds: Config.clockSeconds })
            font.features: { "tnum": 1 }
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.textSize + 6
            font.weight: Font.Medium
        }

        Text {
            visible: Config.dateFormat !== "off"
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale(Config.locale).toString(root.now, Lang.t(Config.dateFormat === "short" ? "ddd d MMM" : "dddd d MMMM"))
            color: Theme.textSoft
            font.family: Theme.font
            font.pixelSize: Theme.textSize
            font.letterSpacing: 0.3
        }
    }

    Hover {
        onPressed: Menus.togglePanel("left")
    }
}
