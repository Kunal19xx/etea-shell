import QtQuick
import qs.config
import qs.modules.bar

// The time drawn as a constellation. Each digit is a handful of stars on a loose grid,
// joined by thin threads; when a digit changes, its stars are born again and the
// threads draw themselves one after the other.
Item {
    id: root

    property string text: "00:00"
    property real digitHeight: 200
    property color ink: Theme.skyInk

    readonly property real digitWidth: digitHeight * 0.5
    readonly property real colonWidth: digitHeight * 0.16

    // Six places per digit, top to bottom, left then right: 0 1 / 2 3 / 4 5.
    // Each segment of the usual seven joins two of them.
    readonly property var segments: ({ a: [0, 1], b: [1, 3], c: [3, 5], d: [5, 4], e: [4, 2], f: [2, 0], g: [2, 3] })
    // In the order a hand would trace them
    readonly property var shapes: ({
        "0": "abcdef",
        "1": "bc",
        "2": "abged",
        "3": "abgcd",
        "4": "fgbc",
        "5": "afgcd",
        "6": "afedcg",
        "7": "abc",
        "8": "gbafedcg",
        "9": "gfabcd"
    })

    // The same small wobble for a given star every time, so the sky doesn't shift
    function jitter(n, salt) {
        const x = Math.sin(n * 12.9898 + salt * 78.233) * 43758.5453;
        return x - Math.floor(x) - 0.5;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: digitHeight

    Row {
        id: row

        spacing: root.digitHeight * 0.16

        Repeater {
            // By position, so a slot only redraws when its own character changes
            model: root.text.length

            Item {
                id: glyph

                required property int index
                readonly property string character: root.text.charAt(index)
                readonly property bool colon: character === ":"
                readonly property var places: {
                    const result = [], inset = root.digitHeight * 0.04;
                    for (let i = 0; i < 6; i++) {
                        const across = i % 2, down = Math.floor(i / 2) / 2;
                        const n = index * 6 + i;
                        // A slight lean to the right, like handwriting
                        const lean = (1 - down) * root.digitHeight * 0.05;
                        result.push(Qt.point(inset + across * (root.digitWidth - inset * 2) + lean + root.jitter(n, 1) * root.digitHeight * 0.05, inset + down * (root.digitHeight - inset * 2) + root.jitter(n, 2) * root.digitHeight * 0.04));
                    }
                    return result;
                }
                readonly property var joins: colon ? [] : (root.shapes[character] ?? "").split("").map(name => root.segments[name])
                // The same threads, each one turned to carry on from where the hand stopped
                readonly property var strokes: {
                    const result = joins.map(join => join.slice());
                    if (result.length > 1 && result[1].includes(result[0][0]) && !result[1].includes(result[0][1]))
                        result[0].reverse();
                    for (let k = 1; k < result.length; k++)
                        if (result[k][1] === result[k - 1][1])
                            result[k].reverse();
                    return result;
                }
                readonly property var used: {
                    const seen = [];
                    for (const [from, to] of joins)
                        for (const place of [from, to])
                            if (!seen.includes(place))
                                seen.push(place);
                    return seen;
                }
                property real trace: 1

                width: colon ? root.colonWidth : root.digitWidth
                height: root.digitHeight

                onCharacterChanged: draw.restart()

                NumberAnimation {
                    id: draw

                    target: glyph
                    property: "trace"
                    from: 0
                    to: 1
                    duration: 260 * Math.max(1, glyph.joins.length)
                    easing.type: Easing.InOutSine
                }

                // A margin all round, the leaning stars stand a little outside the digit
                Canvas {
                    readonly property real margin: root.digitHeight * 0.1

                    x: -margin
                    y: -margin
                    width: parent.width + margin * 2
                    height: parent.height + margin * 2
                    visible: !glyph.colon

                    property real trace: glyph.trace
                    property var strokes: glyph.strokes
                    property var places: glyph.places

                    onTraceChanged: requestPaint()
                    onStrokesChanged: requestPaint()
                    onPlacesChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        g.translate(margin, margin);
                        g.strokeStyle = String(root.ink);
                        g.globalAlpha = 0.5;
                        g.lineWidth = Math.max(1, root.digitHeight * 0.007);
                        g.lineCap = "round";
                        const total = trace * strokes.length;
                        strokes.forEach(([from, to], k) => {
                            const part = Math.max(0, Math.min(1, total - k));
                            if (part <= 0)
                                return;
                            const a = places[from], b = places[to];
                            g.beginPath();
                            g.moveTo(a.x, a.y);
                            g.lineTo(a.x + (b.x - a.x) * part, a.y + (b.y - a.y) * part);
                            g.stroke();
                        });
                    }
                }

                Repeater {
                    model: glyph.used

                    Star {
                        required property int modelData
                        readonly property point at: glyph.places[modelData]
                        // The corners shine a little brighter than the middle
                        readonly property bool corner: modelData !== 2 && modelData !== 3

                        x: at.x - size
                        y: at.y - size
                        size: root.digitHeight * (corner ? 0.05 : 0.038)
                        lit: true
                    }
                }

                // The colon breathes, slow, like something asleep
                Repeater {
                    model: glyph.colon ? [0.34, 0.66] : []

                    Star {
                        required property real modelData

                        x: glyph.width / 2 - size
                        y: root.digitHeight * modelData - size
                        size: root.digitHeight * 0.03
                        lit: true
                        animated: false

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }
}
