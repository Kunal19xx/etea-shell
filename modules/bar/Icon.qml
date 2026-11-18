import QtQuick
import qs.config

// One of our icons, tinted to whatever colour it's sitting in.
Item {
    id: root

    required property string name
    property int size: 20
    property color tint: Theme.text
    readonly property string wanted: name ? Theme.icon(name) : ""
    property string missing: "" // the file the chosen pack doesn't have

    implicitWidth: size
    implicitHeight: size

    Image {
        id: picture

        anchors.fill: parent
        visible: false
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        source: !root.name ? "" : root.wanted === root.missing ? Theme.icon(root.name, "material") : root.wanted
        // A pack that doesn't have this one yet lends it from the filled Material icons. Not
        // straight away: the error can come while the source is still being set.
        onStatusChanged: {
            if (status === Image.Error && source.toString() === root.wanted)
                Qt.callLater(() => root.missing = root.wanted);
        }
    }

    ShaderEffect {
        anchors.fill: parent

        property var source: picture
        property color tint: root.tint

        fragmentShader: Qt.resolvedUrl("../../shaders/tint.frag.qsb")
    }
}
