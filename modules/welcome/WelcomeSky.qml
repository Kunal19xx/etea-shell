import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar
import qs.modules.settings

// Six stars across the sky, one per step. The ones you've been through stay lit and
// threaded together, and at the end they gather into the three stars of ETEA.
Item {
    id: root

    property bool active: true
    property int step: 0
    property int shownStep: 0 // trails step while the card swaps its content
    property real bloom: 0 // 0 while setting up, 1 once the logo has lit
    readonly property bool ending: step === steps.length

    readonly property var steps: [
        { label: Lang.t("Langue"), title: Lang.t("Ta langue"), line: Lang.t("Tout le shell la parle, et tu pourras en changer quand tu veux."), page: "StepLanguage.qml" },
        { label: Lang.t("Monde"), title: Lang.t("Choisis ton monde"), line: Lang.t("Chaque planète change le ciel, le sol et les couleurs d'un coup. Regarde derrière."), page: "StepWorld.qml" },
        { label: Lang.t("Barre"), title: Lang.t("Ta barre"), line: Lang.t("Où elle se pose, sa taille, son style, et si elle s'efface."), page: "StepBar.qml" },
        { label: Lang.t("Bureau"), title: Lang.t("Ton bureau"), line: Lang.t("La texture du ciel, le relief du terrain et la musique qui danse dessus."), page: "StepDesktop.qml" },
        { label: Lang.t("Verrouillage"), title: Lang.t("Ton verrouillage"), line: Lang.t("Ce qui se dessine pendant que tu tapes ton mot de passe."), page: "StepLock.qml" },
        { label: Lang.t("Raccourcis"), title: Lang.t("Quelques raccourcis"), line: Lang.t("De quoi te repérer dès maintenant. Tous les autres sont sur Super + /."), page: "StepShortcuts.qml" }
    ]

    // Where each star sits along its path, then where it lands in the logo
    readonly property real bandTop: height * 0.09
    readonly property real logoSize: Math.min(320, height * 0.3)
    readonly property point logoAt: Qt.point(width / 2 - logoSize / 2, height * 0.38 - logoSize / 2)
    readonly property var path: [[0.2, 0.7], [0.32, 0.28], [0.44, 0.58], [0.56, 0.2], [0.68, 0.64], [0.8, 0.34]]
    readonly property var logo: [[205, 295], [205, 295], [392, 128], [392, 128], [400, 380], [400, 380]]

    signal finished()

    function pointAt(i) {
        if (ending)
            return Qt.point(logoAt.x + logo[i][0] / 512 * logoSize, logoAt.y + logo[i][1] / 512 * logoSize);
        return Qt.point(path[i][0] * width, bandTop + path[i][1] * 200);
    }

    function go(i) {
        if (!ending && i !== step)
            step = Math.max(0, Math.min(steps.length, i));
    }

    focus: true
    onActiveChanged: {
        if (!active)
            return;
        landing.stop();
        step = 0;
        shownStep = 0;
        bloom = 0;
        forceActiveFocus();
    }
    // ending may not have caught up yet, so ask step itself
    onStepChanged: step === steps.length ? landing.restart() : swap.restart()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape)
            root.finished();
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.ending ? root.finished() : root.go(root.step + 1);
        else if (event.key === Qt.Key_Left)
            root.go(root.step - 1);
        else
            return;
        event.accepted = true;
    }

    // The card fades out, takes the new step, and comes back
    SequentialAnimation {
        id: swap

        NumberAnimation { target: body; property: "opacity"; to: 0; duration: Theme.fast; easing.type: Easing.InCubic }
        ScriptAction { script: root.shownStep = root.step }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    // The stars fly into place, then the logo lights
    SequentialAnimation {
        id: landing

        PauseAnimation { duration: 1100 }
        NumberAnimation { target: root; property: "bloom"; to: 1; duration: 700; easing.type: Easing.OutCubic }
    }

    // The thread between the steps you've been through
    Repeater {
        model: root.steps.length - 1

        Rectangle {
            id: thread

            required property int index
            readonly property point from: root.pointAt(index)
            readonly property point to: root.pointAt(index + 1)
            readonly property bool drawn: index < root.step && !root.ending

            x: from.x
            y: from.y - height / 2
            width: drawn ? Math.hypot(to.x - from.x, to.y - from.y) : 0
            height: 1
            color: Theme.link
            opacity: root.ending ? 0 : 0.55
            transform: Rotation {
                origin.x: 0
                origin.y: thread.height / 2
                angle: Math.atan2(thread.to.y - thread.from.y, thread.to.x - thread.from.x) * 180 / Math.PI
            }

            Behavior on width {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }
        }
    }

    Repeater {
        model: root.steps

        Item {
            id: point

            required property int index
            required property var modelData
            readonly property bool here: index === root.step
            readonly property bool passed: index < root.step

            x: root.pointAt(index).x
            y: root.pointAt(index).y
            opacity: 1 - root.bloom

            Behavior on x {
                NumberAnimation { duration: 900 + point.index * 40; easing.type: Easing.InOutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 900 + point.index * 40; easing.type: Easing.InOutCubic }
            }

            Star {
                anchors.centerIn: parent
                size: root.ending ? 7 : point.here ? 12 : point.passed ? 8 : 5
                lit: point.here || point.passed || root.ending
                animated: false

                Behavior on size {
                    NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 22
                text: point.modelData.label
                color: Theme.text
                opacity: root.ending ? 0 : point.here ? 1 : point.passed ? 0.7 : 0.4
                font.family: Theme.font
                font.pixelSize: 13

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }
            }

            MouseArea {
                x: -30
                y: -24
                width: 60
                height: 64
                enabled: !root.ending
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(point.index)
            }
        }
    }

    HandCard {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(root.bandTop + 270, root.height - height - 90)
        width: 720
        height: body.implicitHeight + 72
        seed: "welcome"
        rise: 0.06
        tint: Theme.windowLit
        alive: root.active && !root.ending
        opacity: root.ending ? 0 : 1
        visible: opacity > 0

        Behavior on height {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }

        ColumnLayout {
            id: body

            readonly property var page: root.steps[root.shownStep]

            x: 40
            y: 36
            width: card.width - 80
            spacing: 14

            Text {
                text: body.page.title
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 30
                font.weight: Font.Light
            }

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                text: body.page.line
                wrapMode: Text.Wrap
                color: Qt.alpha(Theme.text, 0.65)
                font.family: Theme.font
                font.pixelSize: 13
            }

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: item?.implicitHeight ?? 0
                source: Qt.resolvedUrl(`steps/${body.page.page}`)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10

                SettingButton {
                    visible: root.shownStep > 0
                    label: Lang.t("Retour")
                    quiet: true
                    onPicked: root.go(root.step - 1)
                }

                Item {
                    Layout.fillWidth: true
                }

                SettingButton {
                    label: root.shownStep === root.steps.length - 1 ? Lang.t("Terminer") : Lang.t("Suivant")
                    onPicked: root.go(root.step + 1)
                }
            }
        }
    }

    // The logo, lit by the six stars
    Image {
        x: root.logoAt.x
        y: root.logoAt.y
        width: root.logoSize
        height: root.logoSize
        source: Quickshell.shellPath("assets/logo.png")
        sourceSize: Qt.size(512, 512)
        mipmap: true
        opacity: root.bloom
        scale: 0.8 + 0.2 * root.bloom
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.logoAt.y + root.logoSize + 28
        spacing: 10
        opacity: root.bloom
        visible: opacity > 0
        transform: Translate {
            y: (1 - root.bloom) * 12
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lang.t("Bienvenue sur {0}", Theme.planet.name)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 30
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lang.t("Tout se retrouve dans les réglages, sur Super + ,")
            color: Qt.alpha(Theme.text, 0.65)
            font.family: Theme.font
            font.pixelSize: 13
        }

        Item {
            width: 1
            height: 8
        }

        SettingButton {
            anchors.horizontalCenter: parent.horizontalCenter
            label: Lang.t("Se poser")
            onPicked: root.finished()
        }
    }

    // Ticked, the welcome stays away from the next starts
    Row {
        x: 48
        y: root.height - 64
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 6
            color: Qt.alpha(Theme.windowLit, Config.welcome ? 0.08 : 0.24)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.4)

            Star {
                anchors.centerIn: parent
                size: 5
                lit: true
                animated: false
                opacity: Config.welcome ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Theme.fast }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Lang.t("Ne plus afficher au démarrage")
            color: Qt.alpha(Theme.text, 0.7)
            font.family: Theme.font
            font.pixelSize: 13
        }

        TapHandler {
            onTapped: Config.welcome = !Config.welcome
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    SettingButton {
        x: root.width - width - 48
        y: root.height - 64 - (height - 18) / 2
        visible: !root.ending
        label: Lang.t("Passer")
        quiet: true
        onPicked: root.finished()
    }
}
