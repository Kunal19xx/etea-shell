import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.services

// The screens, a click away: how they're shown together, and each lit one's size and
// speed. The rest, scale, turn and where they sit, is in Settings.
ColumnLayout {
    id: root

    readonly property color cardTint: "#9fd3c7"
    readonly property real cardRise: 0.07
    readonly property var shown: Screens.lit.filter(output => !output.mirror)

    spacing: 4
    width: 300

    // A few sizes: the one in use and the largest others
    function sizesOf(output) {
        const seen = new Map();
        for (const mode of output.modes) {
            const id = `${mode.width}x${mode.height}`;
            if (!seen.has(id))
                seen.set(id, { id: id, width: mode.width, height: mode.height });
        }
        const all = [...seen.values()].sort((a, b) => b.width * b.height - a.width * a.height);
        const mine = all.find(size => size.width === output.width && size.height === output.height);
        const others = all.filter(size => size !== mine).slice(0, mine ? 3 : 4);
        return (mine ? others.concat([mine]) : others).sort((a, b) => b.width * b.height - a.width * a.height);
    }

    function speedsOf(output) {
        const seen = new Map();
        for (const mode of output.modes.filter(m => m.width === output.width && m.height === output.height)) {
            const hz = Math.round(mode.refresh);
            if (!seen.has(hz) || mode.id === output.mode)
                seen.set(hz, mode);
        }
        return [...seen.values()].sort((a, b) => b.refresh - a.refresh).slice(0, 5);
    }

    function pickSize(output, size) {
        const modes = output.modes.filter(m => m.width === size.width && m.height === size.height);
        if (modes.length)
            Screens.setMode(output.key, modes.reduce((a, b) => Math.abs(b.refresh - output.refresh) < Math.abs(a.refresh - output.refresh) ? b : a).id);
    }

    MenuTitle {
        Layout.bottomMargin: 4
        text: Lang.t("Écrans")
    }

    // How they're shown together, once there are two
    Repeater {
        model: Screens.several ? [{ id: "extend", label: Lang.t("Étendre"), detail: Lang.t("côte à côte") }].concat(Screens.canMirror ? [{ id: "mirror", label: Lang.t("Dupliquer"), detail: Lang.t("la même image") }] : []).concat(Screens.outputs.map(output => ({ id: "only:" + output.key, label: Lang.t("Seulement {0}", Screens.nameOf(output)), detail: "" }))) : []

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.label
            detail: modelData.detail
            active: Screens.projection === modelData.id
            onPicked: Screens.project(modelData.id)
        }
    }

    Repeater {
        model: root.shown

        ColumnLayout {
            id: block

            required property var modelData

            Layout.fillWidth: true
            Layout.topMargin: Screens.several ? 10 : 0
            spacing: 4

            MenuTitle {
                visible: Screens.several
                text: Screens.nameOf(block.modelData)
            }

            Repeater {
                model: root.sizesOf(block.modelData)

                MenuRow {
                    required property var modelData

                    Layout.fillWidth: true
                    label: `${modelData.width} × ${modelData.height}`
                    active: modelData.width === block.modelData.width && modelData.height === block.modelData.height
                    onPicked: root.pickSize(block.modelData, modelData)
                }
            }

            // Its speeds at that size, side by side
            Row {
                visible: speeds.count > 1
                Layout.leftMargin: 6
                Layout.topMargin: 2
                spacing: 6

                Repeater {
                    id: speeds

                    model: root.speedsOf(block.modelData)

                    Item {
                        id: speed

                        required property var modelData
                        readonly property bool active: modelData.id === block.modelData.mode || Math.abs(modelData.refresh - block.modelData.refresh) < 0.05

                        width: hz.implicitWidth + 22
                        height: 28

                        Entrance {
                            item: speed
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: Menus.tint
                            opacity: speed.active ? 0.22 : pointer.containsMouse ? 0.1 : 0.04

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.fast }
                            }
                        }

                        Text {
                            id: hz

                            anchors.centerIn: parent
                            text: Lang.t("{0} Hz", Math.round(speed.modelData.refresh))
                            color: speed.active ? Theme.text : Qt.alpha(Theme.text, 0.7)
                            font.family: Theme.font
                            font.pixelSize: 12
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
                                Screens.setMode(block.modelData.key, speed.modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }

    MenuRow {
        Layout.fillWidth: true
        Layout.topMargin: 8
        label: Lang.t("Tous les réglages d'écran…")
        onPicked: {
            Menus.close();
            Menus.openSettings("@ecrans");
        }
    }
}
