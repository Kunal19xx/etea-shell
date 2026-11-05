import QtQuick
import QtQuick.Layouts
import qs.config

// The few keys worth knowing on day one
GridLayout {
    columns: 2
    columnSpacing: 28
    rowSpacing: 12

    Repeater {
        model: [
            { keys: ["Super"], label: Lang.t("Ouvrir le lanceur") },
            { keys: ["Super", "Tab"], label: Lang.t("Monter en orbite") },
            { keys: ["Super", "1 … 0"], label: Lang.t("Aller à une page") },
            { keys: ["Super", ","], label: Lang.t("Réglages") },
            { keys: ["Super", "L"], label: Lang.t("Verrouiller") },
            { keys: ["Super", "/"], label: Lang.t("Tous les raccourcis") },
            { keys: [Lang.t("Coin de la barre")], label: Lang.t("Ouvrir le panneau de ce côté") },
            { keys: ["Super", Lang.t("glisser")], label: Lang.t("Déplacer un widget, ou une fenêtre") }
        ]

        RowLayout {
            id: shortcut

            required property var modelData

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 6

            Repeater {
                model: shortcut.modelData.keys

                Rectangle {
                    required property string modelData

                    implicitWidth: key.implicitWidth + 18
                    implicitHeight: 26
                    radius: 8
                    color: Qt.alpha(Theme.windowLit, 0.16)

                    Text {
                        id: key

                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: shortcut.modelData.label
                elide: Text.ElideRight
                color: Qt.alpha(Theme.text, 0.75)
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
    }
}
