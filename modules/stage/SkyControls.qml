import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// Over the belt of skies: which side it's on, « Mon dossier » or « Ailleurs », top right,
// and elsewhere, top left, the search as you type it and the filters. Only these words
// take the pointer; everywhere else the hands still turn the belt.
Item {
    id: root

    property real unit: width / 1600
    readonly property bool online: Skies.mode === "online"
    readonly property real showing: {
        const t = Math.max(0, Math.min(1, (Planet.altitude - 0.47) / 0.13));
        return t * t * (3 - 2 * t);
    }
    readonly property real headline: Theme.barReserve + 18 * unit

    visible: Skies.open && Planet.inSkies && showing > 0 && !Skies.landing
    opacity: showing

    // A word that can be picked: brighter when it's the one in use
    component Choice: Text {
        id: choice

        property bool on: false
        signal picked()

        color: Qt.alpha(Theme.skyInk, on ? 0.94 : hover.containsMouse ? 0.7 : 0.45)
        font.family: Theme.font
        font.pixelSize: Math.round(13 * root.unit)

        Behavior on color {
            ColorAnimation { duration: Theme.fast }
        }

        // The one in use has a small lit star under it
        Star {
            x: (choice.width - width) / 2
            y: choice.height + 2 * root.unit
            size: 3 * root.unit
            lit: true
            animated: false
            visible: choice.on
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            anchors.margins: -6 * root.unit
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }

    // The two sides, top right
    Row {
        x: root.width - width - 28 * root.unit
        y: root.headline
        spacing: 22 * root.unit

        Choice {
            text: Lang.t("Mon dossier")
            on: !root.online
            onPicked: if (root.online) Skies.toggleMode()
        }

        Choice {
            text: Lang.t("Ailleurs")
            on: root.online
            onPicked: if (!root.online) Skies.toggleMode()
        }
    }

    // Elsewhere, top left: the search, then the filters
    Column {
        x: 28 * root.unit
        y: root.headline
        spacing: 14 * root.unit
        visible: root.online

        Row {
            spacing: 10 * root.unit

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: Math.round(16 * root.unit)
                tint: Qt.alpha(Theme.skyInk, 0.7)
            }

            Text {
                id: typedText

                anchors.verticalCenter: parent.verticalCenter
                text: Online.query || Lang.t("Tape pour chercher sur {0}", Online.sourceName)
                color: Qt.alpha(Theme.skyInk, Online.query ? 0.94 : 0.45)
                font.family: Theme.font
                font.pixelSize: Math.round(18 * root.unit)
                font.weight: Font.Light
            }

            // The caret breathes rather than blinks
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Math.round(1.5 * root.unit))
                height: typedText.font.pixelSize * 1.1
                color: Theme.skyInk
                visible: !!Online.query || root.online

                SequentialAnimation on opacity {
                    running: root.visible && root.online
                    loops: Animation.Infinite

                    NumberAnimation { from: 0.9; to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.15; to: 0.9; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Online.busy ? Lang.t("On cherche…") : Online.dirty ? Lang.t("Entrée pour chercher") : Online.error
                color: Qt.alpha(Theme.skyInk, 0.5)
                font.family: Theme.font
                font.pixelSize: Math.round(12 * root.unit)
            }
        }

        // How they're sorted
        Row {
            spacing: 18 * root.unit

            Repeater {
                model: [
                    { id: "relevance", label: Lang.t("Pertinence"), shown: !!Online.query.trim() },
                    { id: "toplist", label: Lang.t("Tendances"), shown: true },
                    { id: "date_added", label: Lang.t("Récents"), shown: true },
                    { id: "random", label: Lang.t("Au hasard"), shown: Online.source === "wallhaven" }
                ].filter(choice => choice.shown)

                Choice {
                    required property var modelData

                    text: modelData.label
                    on: Online.sorting === modelData.id
                    onPicked: {
                        Online.sorting = modelData.id;
                        Online.search();
                    }
                }
            }
        }

        // Over which stretch of time the trending ones are, on Wallhaven
        Row {
            spacing: 18 * root.unit
            visible: Online.source === "wallhaven" && Online.sorting === "toplist"

            Repeater {
                model: [{ id: "1w", label: Lang.t("Cette semaine") }, { id: "1M", label: Lang.t("Ce mois") }, { id: "1y", label: Lang.t("Cette année") }]

                Choice {
                    required property var modelData

                    text: modelData.label
                    on: Online.topRange === modelData.id
                    onPicked: {
                        Online.topRange = modelData.id;
                        Online.search();
                    }
                }
            }
        }

        // What kind of picture, on Wallhaven; at least one stays on
        Row {
            spacing: 18 * root.unit
            visible: Online.source === "wallhaven"

            Repeater {
                model: [{ id: "general", label: Lang.t("Général") }, { id: "anime", label: Lang.t("Anime") }, { id: "people", label: Lang.t("Personnes") }]

                Choice {
                    required property var modelData

                    text: modelData.label
                    on: Online.categories[modelData.id]
                    onPicked: {
                        const next = Object.assign({}, Online.categories);
                        next[modelData.id] = !next[modelData.id];
                        if (!next.general && !next.anime && !next.people)
                            return;
                        Online.categories = next;
                        Online.search();
                    }
                }
            }
        }
    }
}
