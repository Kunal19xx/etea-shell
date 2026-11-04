import QtQuick
import qs.config
import qs.modules.bar

// The plain night: the world's sky and a row of stars across the middle, one per letter.
// It's what the lock falls back on when a scene can't load.
Item {
    id: root

    property Item host // the LockScene this is drawn in

    readonly property var lock: host.lock
    readonly property color night: Theme.skyTop
    readonly property point unlockAt: starAt(Math.max(0, lock.stars - 1))
    readonly property real gap: height * 0.03

    // Centred on the row, which grows from the middle
    function starAt(n) {
        return Qt.point(width / 2 + (n - (lock.stars - 1) / 2) * gap, height * 0.5 + host.jitter(n, 2) * gap * 0.4);
    }

    ShaderEffect {
        anchors.fill: parent

        property color colorTop: Theme.skyTop
        property color colorMid: Theme.skyMid
        property color colorLow: Theme.skyLow
        property vector2d resolution: Qt.vector2d(width, height)
        property real grain: Theme.grain
        property real space: 0.86

        fragmentShader: Qt.resolvedUrl("../../../shaders/sky.frag.qsb")
    }

    Repeater {
        model: root.host.main ? root.lock.stars : 0

        Star {
            required property int index
            readonly property point spot: root.starAt(index)

            x: spot.x - size
            y: spot.y - size
            size: index === root.lock.stars - 1 ? 10 : 7
            lit: true
            opacity: root.lock.vanishing ? 0 : root.lock.checking ? 0.55 + 0.45 * root.host.pulse : 1

            Behavior on x {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 220 }
            }
        }
    }
}
