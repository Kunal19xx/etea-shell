import QtQuick
import QtQuick.Shapes
import Quickshell

// Two of them in the grass at night, one pointing up: each letter you type lights the
// next star of the constellation she's showing him. The art, and how it was made, is in
// assets/lock/skyward. Everything is flat, the light included.
Item {
    id: root

    property Item host // the LockScene this is drawn in, see there for what a scene gets

    readonly property var lock: host.lock
    readonly property bool main: host.main
    readonly property real unit: height
    readonly property color night: "#030820"

    // Where each star goes, from her fingertip in screen heights: across, down, and the
    // star its line hangs from. The first seven make a handle and a bowl, the rest branch
    // off it, so the drawing stays a constellation however long the password.
    readonly property var shape: [
        [0.099, -0.069, -1], [0.160, -0.114, 0], [0.226, -0.128, 1], [0.289, -0.169, 2],
        [0.382, -0.154, 3], [0.406, -0.238, 4], [0.313, -0.254, 5], [0.465, -0.203, 5],
        [0.530, -0.264, 7], [0.572, -0.203, 8], [0.634, -0.254, 9], [0.671, -0.188, 10],
        [0.271, -0.317, 6], [0.201, -0.349, 12], [0.130, -0.319, 13], [0.072, -0.358, 14],
        [0.150, -0.226, 14], [0.072, -0.189, 16], [0.021, -0.254, 17], [-0.049, -0.305, 18],
        [0.493, -0.097, 4], [0.572, -0.060, 20], [0.650, -0.097, 21], [0.530, -0.347, 8]
    ]
    // Lines that close a loop, drawn once both ends are lit
    readonly property var loops: [[6, 3]]

    // How much sky the constellation wants right of her finger, in screen heights
    readonly property real span: 0.71
    // Her fingertip, as a share of the drawing
    readonly property point tip: Qt.point(figures.x + figures.width * 0.7831, figures.y + figures.height * 0.4024)
    // On a narrow screen they step a little to the left, and the constellation shrinks
    // as a whole if it still doesn't fit
    readonly property real fit: Math.min(1, (width - tip.x - unit * 0.04) / (unit * span))
    readonly property point unlockAt: lock.stars > 0 ? starAt(lock.stars - 1) : tip

    // Past the last star, the shape starts again a little lower and to the side
    function starAt(n) {
        const s = shape[n % shape.length], round = Math.floor(n / shape.length);
        return Qt.point(tip.x + (s[0] + round * 0.025) * fit * unit, tip.y + (s[1] + round * 0.035) * fit * unit);
    }

    // They rise into view as the page opens, and sink first when it closes
    property real lift: main && lock.revealed ? 1 : 0

    Behavior on lift {
        NumberAnimation { duration: root.lock.revealed ? 900 : 600; easing.type: Easing.InOutCubic }
    }

    // ETEA's four-pointed star, flat, without the halo the bar's stars wear
    component Spark: Shape {
        property real size: 8
        property color tint: "#E8EEFF"

        width: size * 2
        height: size * 2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: tint
            startX: size
            startY: 0

            PathQuad { x: size * 2; y: size; controlX: size * 1.15; controlY: size * 0.85 }
            PathQuad { x: size; y: size * 2; controlX: size * 1.15; controlY: size * 1.15 }
            PathQuad { x: 0; y: size; controlX: size * 0.85; controlY: size * 1.15 }
            PathQuad { x: size; y: 0; controlX: size * 0.85; controlY: size * 0.85 }
        }
    }

    // The sky, kept whole on wide screens and cut from the top on narrow ones, so the
    // Milky Way always rises from behind them
    Image {
        readonly property real across: Math.max(root.width, root.height * 16 / 9)

        width: across
        height: across * 9 / 16
        y: root.height - height
        source: Quickshell.shellPath("assets/lock/skyward/sky.svg")
        sourceSize: Qt.size(width, height)
        asynchronous: true
    }

    // A thread from each star to the one it hangs from, drawing itself out
    Repeater {
        model: root.main ? root.lock.stars : 0

        Rectangle {
            id: thread

            required property int index
            readonly property int from: root.shape[index % root.shape.length][2]
            readonly property point a: root.starAt(from < 0 ? index : from + Math.floor(index / root.shape.length) * root.shape.length)
            readonly property point b: root.starAt(index)
            property real grow: 0

            visible: from >= 0
            x: a.x
            y: a.y - height / 2
            width: Math.hypot(b.x - a.x, b.y - a.y) * grow
            height: 1
            color: "#B7C6F2"
            antialiasing: true
            transformOrigin: Item.Left
            rotation: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI
            opacity: root.lock.vanishing ? 0 : 0.55

            NumberAnimation on grow {
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }

            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }
    }

    Repeater {
        model: root.main ? root.loops.filter(loop => Math.max(loop[0], loop[1]) < root.lock.stars) : []

        Rectangle {
            required property var modelData
            readonly property point a: root.starAt(modelData[0])
            readonly property point b: root.starAt(modelData[1])

            x: a.x
            y: a.y - height / 2
            width: Math.hypot(b.x - a.x, b.y - a.y)
            height: 1
            color: "#B7C6F2"
            antialiasing: true
            transformOrigin: Item.Left
            rotation: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI
            opacity: root.lock.vanishing ? 0 : 0.55

            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }
    }

    // The newest star wears its light as a flat disc and two long thin rays
    Item {
        readonly property point at: root.unlockAt

        visible: root.main && root.lock.stars > 0
        x: at.x
        y: at.y
        opacity: root.lock.vanishing ? 0 : root.lock.checking ? 0.6 + 0.4 * root.host.pulse : 1
        scale: root.lock.capsLock ? 1.3 : 1

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Rectangle {
            readonly property real r: root.unit * 0.016

            x: -r
            y: -r
            width: r * 2
            height: r * 2
            radius: r
            color: "#0E1D50"
        }

        Repeater {
            model: [0, 90]

            Shape {
                required property real modelData
                readonly property real reach: root.unit * 0.043
                readonly property real thick: Math.max(1, root.unit * 0.0012)

                // Turned around the star itself, not around the middle of the shape
                width: 0
                height: 0
                transform: Rotation { angle: modelData }
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: "#AEBEEB"
                    startX: -reach
                    startY: 0

                    PathLine { x: 0; y: -thick }
                    PathLine { x: reach; y: 0 }
                    PathLine { x: 0; y: thick }
                    PathLine { x: -reach; y: 0 }
                }
            }
        }
    }

    Repeater {
        model: root.main ? root.lock.stars : 0

        Spark {
            id: star

            required property int index
            readonly property point spot: root.starAt(index)
            readonly property bool newest: index === root.lock.stars - 1

            x: spot.x - size
            y: spot.y - size
            size: root.unit * (newest ? 0.012 : 0.0075) * (root.lock.capsLock ? 1.4 : 1)
            tint: newest ? "#FFF6DD" : "#E8EEFF"
            opacity: root.lock.checking ? 0.55 + 0.45 * root.host.pulse : 1
            scale: 0

            // Born a little too big, then settles
            SequentialAnimation on scale {
                NumberAnimation { to: 1.5; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutBack }
            }

            Behavior on size {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            // A wrong password: they fall out of the sky one after the other
            states: State {
                when: root.lock.vanishing

                PropertyChanges {
                    star.opacity: 0
                    star.x: star.spot.x - star.size - root.unit * 0.03
                    star.y: star.spot.y - star.size + root.unit * 0.06
                }
            }

            transitions: Transition {
                SequentialAnimation {
                    PauseAnimation { duration: star.index * 25 }
                    NumberAnimation { properties: "x,y,opacity"; duration: 380; easing.type: Easing.InQuad }
                }
            }
        }
    }

    // The two of them, sharp at any size, standing in the bottom left
    Image {
        id: figures

        readonly property real wanted: width * 0.7831 + root.unit * (root.span + 0.04)

        x: Math.max(-root.unit * 0.22, Math.min(0, root.width - wanted))
        height: root.height
        width: height * 4344 / 3258
        source: Quickshell.shellPath("assets/lock/skyward/figures.svg")
        sourceSize.height: height
        asynchronous: true
        visible: root.main
        transform: Translate { y: (1 - root.lift) * root.height * 0.12 }
    }
}
