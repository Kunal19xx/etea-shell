import QtQuick
import qs.config
import qs.modules.bar
import qs.modules.bar.menus
import qs.modules.stage
import qs.services

// A tile's menu, opened right inside the panel: it unfolds through a star from the tile
// you right-clicked, over what's below it, and folds back into it. A click anywhere else
// in the panel puts it away.
Item {
    id: root

    property string menu: "" // "network" or "bluetooth", empty once it's closing
    property Item from: null // the tile it grows from
    property string shown: "" // stays a little longer than menu, so it can fold away
    property real reveal: 0

    function show(name, tile) {
        if (menu === name) {
            close();
            return;
        }
        fold.stop();
        if (shown !== name)
            reveal = 0;
        menu = name;
        from = tile;
        shown = name;
        unfold.restart();
    }

    function close() {
        menu = "";
        unfold.stop();
        fold.restart();
    }

    anchors.fill: parent
    z: 10
    visible: shown !== ""

    NumberAnimation {
        id: unfold

        target: root
        property: "reveal"
        to: 1
        duration: Theme.cardOpen
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fold

        target: root
        property: "reveal"
        to: 0
        duration: Theme.cardOpen * 0.8
        easing.type: Easing.OutQuad
        onFinished: root.shown = ""
    }

    // The rows and switches inside take the menu's colour, like under the bar
    Binding {
        target: Menus
        property: "tint"
        value: content.item?.cardTint ?? Theme.windowLit
        when: root.shown !== ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.menu !== ""
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.close()
    }

    Item {
        id: card

        readonly property point origin: root.from ? root.from.mapToItem(root, root.from.width / 2, root.from.height / 2) : Qt.point(0, 0)

        x: Math.max(0, Math.min(root.width - width, origin.x - width / 2))
        y: root.from ? root.from.mapToItem(root, 0, root.from.height).y + 8 : 0
        width: content.width + 40
        height: content.height + 62
        layer.enabled: root.reveal < 1
        layer.effect: StarMask {
            center: Qt.point(card.origin.x - card.x, card.origin.y - card.y)
            reach: fullReach * root.reveal
            shine: (1 - root.reveal) * 0.9
            tint: Menus.tint
        }

        // Clicks on the card stay on the card
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        HandCard {
            anchors.fill: parent
            seed: `tile-${root.shown}`
            tint: Menus.tint
            rise: content.item?.cardRise ?? 0.08
        }

        Loader {
            id: content

            x: 20
            y: 20
            sourceComponent: ({ network: networkMenu, bluetooth: bluetoothMenu })[root.shown] ?? null
        }
    }

    Component {
        id: networkMenu

        NetworkMenu {}
    }

    Component {
        id: bluetoothMenu

        BluetoothMenu {}
    }
}
