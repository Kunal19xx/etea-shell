import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// The screens as they sit together, drawn to scale. Click one to set it up below, drag
// it beside another to move it there: it lands against the nearest edge, so there's
// never a gap or an overlap between them.
Item {
    id: root

    property string selected: ""
    readonly property bool movable: Screens.projection === "extend" && placed.length > 1

    signal chosen(string key)

    // The lit screens that have a place of their own, mirrors stay with the one they copy
    readonly property var placed: Screens.outputs.filter(output => output.enabled && !output.mirror).map(output => {
        const size = Screens.logical(output);
        const at = preview?.[output.key];
        return { key: output.key, output: output, x: at ? at[0] : output.x, y: at ? at[1] : output.y, width: size.width, height: size.height };
    })
    readonly property var dark: Screens.outputs.filter(output => !output.enabled)
    property var preview: null // where they were dropped, until the compositor answers

    readonly property var bounds: {
        if (placed.length === 0)
            return { x: 0, y: 0, width: 1, height: 1 };
        const left = Math.min(...placed.map(p => p.x)), top = Math.min(...placed.map(p => p.y));
        const right = Math.max(...placed.map(p => p.x + p.width)), bottom = Math.max(...placed.map(p => p.y + p.height));
        return { x: left, y: top, width: right - left, height: bottom - top };
    }
    // Room around them to drag into
    readonly property real ratio: Math.min((width - 160) / bounds.width, (field.height - 50) / bounds.height)
    readonly property real originX: (width - bounds.width * ratio) / 2 - bounds.x * ratio
    readonly property real originY: (field.height - bounds.height * ratio) / 2 - bounds.y * ratio

    implicitHeight: field.height + (dark.length ? darkRow.height + 14 : 0)

    Connections {
        target: Screens

        function onOutputsChanged() {
            root.preview = null;
        }
    }

    // Against the nearest edge of another screen, sliding along it, and caught at its corners
    function snap(key, x, y) {
        const moving = placed.find(p => p.key === key);
        const others = placed.filter(p => p.key !== key);
        const catchAt = 80;
        const overlaps = (ax, ay) => others.some(o => ax < o.x + o.width && ax + moving.width > o.x && ay < o.y + o.height && ay + moving.height > o.y);
        const along = (value, start, length, size) => {
            let v = Math.max(start - size + 40, Math.min(start + length - 40, value));
            if (Math.abs(v - start) < catchAt)
                v = start;
            else if (Math.abs(v + size - (start + length)) < catchAt)
                v = start + length - size;
            return v;
        };
        let best = null, distance = Infinity;
        for (const o of others) {
            const spots = [
                [o.x + o.width, along(y, o.y, o.height, moving.height)],
                [o.x - moving.width, along(y, o.y, o.height, moving.height)],
                [along(x, o.x, o.width, moving.width), o.y + o.height],
                [along(x, o.x, o.width, moving.width), o.y - moving.height]
            ];
            for (const [sx, sy] of spots) {
                const d = Math.hypot(sx - x, sy - y);
                if (d < distance && !overlaps(sx, sy)) {
                    best = [Math.round(sx), Math.round(sy)];
                    distance = d;
                }
            }
        }
        return best ?? [moving.x, moving.y];
    }

    // Everyone's place once one has moved, starting again from the top left corner
    function drop(key, at) {
        const spots = placed.map(p => [p.key, p.key === key ? at : [p.x, p.y]]);
        const left = Math.min(...spots.map(s => s[1][0])), top = Math.min(...spots.map(s => s[1][1]));
        const positions = {};
        for (const [k, [x, y]] of spots)
            positions[k] = [x - left, y - top];
        preview = positions;
        Screens.place(positions);
    }

    Item {
        id: field

        width: parent.width
        height: 230

        // Where a screen being dragged will land
        Rectangle {
            id: ghost

            property var spot: null

            visible: spot !== null
            x: spot ? root.originX + spot[0] * root.ratio : 0
            y: spot ? root.originY + spot[1] * root.ratio : 0
            width: spot ? spot[2] * root.ratio : 0
            height: spot ? spot[3] * root.ratio : 0
            radius: 9
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.link, 0.6)

            Behavior on x {
                NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
            }
        }

        Repeater {
            model: root.placed

            Item {
                id: card

                required property var modelData

                readonly property bool chosen: modelData.key === root.selected
                property bool dragging: false
                property point grab: Qt.point(0, 0)
                property real dragX: 0
                property real dragY: 0
                readonly property var mirrors: Screens.outputs.filter(output => output.mirror === modelData.output.name)

                x: dragging ? dragX : root.originX + modelData.x * root.ratio
                y: dragging ? dragY : root.originY + modelData.y * root.ratio
                z: dragging ? 2 : 1
                width: modelData.width * root.ratio
                height: modelData.height * root.ratio

                Behavior on x {
                    enabled: !card.dragging
                    NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
                }
                Behavior on y {
                    enabled: !card.dragging
                    NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
                }

                // Copies sit behind, a little offset, like a stack of the same picture
                Repeater {
                    model: card.mirrors.length

                    Rectangle {
                        required property int index

                        x: (index + 1) * 7
                        y: -(index + 1) * 7
                        z: -1 - index
                        width: card.width
                        height: card.height
                        radius: 9
                        color: Theme.cardDeep
                        border.width: 1
                        border.color: Qt.alpha(Theme.link, 0.3)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Theme.cardDeep
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Theme.windowLit
                    opacity: card.chosen ? 0.24 : pointer.containsMouse ? 0.14 : 0.08
                    border.width: 1
                    border.color: Theme.link

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.fast }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Theme.link, card.chosen ? 0.85 : 0.35)
                }

                Star {
                    x: 12 - size
                    y: 13 - size
                    size: card.chosen ? 5 : 3
                    lit: card.chosen
                    animated: false

                    Behavior on size {
                        NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 2

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Screens.nameOf(card.modelData.output)
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: card.mirrors.length ? Lang.t("et sa copie sur {0}", card.mirrors.map(output => Screens.nameOf(output)).join(", ")) : `${card.modelData.output.width} × ${card.modelData.output.height}`
                        elide: Text.ElideRight
                        color: Qt.alpha(Theme.text, 0.55)
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.movable ? (card.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                    onPressed: mouse => {
                        root.chosen(card.modelData.key);
                        card.grab = Qt.point(mouse.x, mouse.y);
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !root.movable)
                            return;
                        if (!card.dragging && Math.hypot(mouse.x - card.grab.x, mouse.y - card.grab.y) < 4)
                            return;
                        const inField = mapToItem(field, mouse.x, mouse.y);
                        card.dragX = inField.x - card.grab.x;
                        card.dragY = inField.y - card.grab.y;
                        card.dragging = true;
                        const at = root.snap(card.modelData.key, (card.dragX - root.originX) / root.ratio, (card.dragY - root.originY) / root.ratio);
                        ghost.spot = [at[0], at[1], card.modelData.width, card.modelData.height];
                    }
                    onReleased: {
                        if (!card.dragging)
                            return;
                        const at = root.snap(card.modelData.key, (card.dragX - root.originX) / root.ratio, (card.dragY - root.originY) / root.ratio);
                        ghost.spot = null;
                        card.dragging = false;
                        if (at[0] !== card.modelData.x || at[1] !== card.modelData.y)
                            root.drop(card.modelData.key, at);
                    }
                }
            }
        }
    }

    // The screens plugged in but switched off, waiting below
    Row {
        id: darkRow

        visible: root.dark.length > 0
        y: field.height + 14
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Repeater {
            model: root.dark

            Item {
                id: sleeper

                required property var modelData
                readonly property bool chosen: modelData.key === root.selected

                width: label.implicitWidth + 40
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Theme.link, sleeper.chosen ? 0.8 : 0.3)
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: Lang.t("{0}, éteint", Screens.nameOf(sleeper.modelData))
                    color: Qt.alpha(Theme.text, sleeper.chosen ? 0.9 : 0.55)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: root.chosen(sleeper.modelData.key)
                }
            }
        }
    }
}
