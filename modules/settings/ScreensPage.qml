import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// The screens: how they're shown together, where each one sits, and for the one you
// pick on the map, its size, sharpness, speed and turn.
ColumnLayout {
    id: root

    property string selected: ""
    readonly property var display: Screens.outputs.find(output => output.key === selected) ?? Screens.primary
    // Its sizes, largest first, and the speeds of the one in use
    readonly property var sizes: {
        if (!display)
            return [];
        const seen = new Map();
        for (const mode of display.modes) {
            const id = `${mode.width}x${mode.height}`;
            if (!seen.has(id))
                seen.set(id, { id: id, label: `${mode.width} × ${mode.height}`, area: mode.width * mode.height });
        }
        return [...seen.values()].sort((a, b) => b.area - a.area);
    }
    readonly property var speeds: {
        if (!display)
            return [];
        const seen = new Map();
        for (const mode of display.modes.filter(m => m.width === display.width && m.height === display.height)) {
            const label = Lang.t("{0} Hz", Math.round(mode.refresh));
            if (!seen.has(label) || mode.id === display.mode)
                seen.set(label, { id: mode.id, label: label, refresh: mode.refresh });
        }
        return [...seen.values()].sort((a, b) => b.refresh - a.refresh);
    }
    readonly property string currentSpeed: speeds.find(speed => speed.id === display?.mode)?.id ?? speeds.find(speed => Math.abs(speed.refresh - (display?.refresh ?? 0)) < 0.5)?.id ?? ""

    // Another size, at the speed closest to the one it has now
    function pickSize(id) {
        const [width, height] = id.split("x").map(Number);
        const modes = display.modes.filter(m => m.width === width && m.height === height);
        if (!modes.length)
            return;
        const best = modes.reduce((a, b) => Math.abs(b.refresh - display.refresh) < Math.abs(a.refresh - display.refresh) ? b : a);
        Screens.setMode(display.key, best.id);
    }

    spacing: 18

    Text {
        text: Lang.t("Écrans")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 20
    }

    SettingSection {
        visible: Screens.several
        text: Lang.t("Affichage")
        words: ["projection", "projeter", "dupliquer", "étendre", "mirror", "extend", "duplicate"]
    }

    SettingChoice {
        visible: Screens.several
        label: Lang.t("Ensemble")
        hint: Lang.t("Étendre le bureau, le dupliquer, ou n'en allumer qu'un.")
        words: ["projection", "dupliquer", "étendre", "miroir", "mirror", "extend", "duplicate", "only"]
        current: Screens.projection
        options: [{ id: "extend", label: Lang.t("Étendre") }].concat(Screens.canMirror ? [{ id: "mirror", label: Lang.t("Dupliquer") }] : []).concat(Screens.outputs.map(output => ({ id: "only:" + output.key, label: Lang.t("Seulement {0}", Screens.nameOf(output)) })))
        onPicked: id => Screens.project(id)
    }

    SettingSection {
        text: Lang.t("Disposition")
        words: ["position", "arrangement", "layout", "placer"]
    }

    Text {
        Layout.fillWidth: true
        text: Screens.outputs.length === 0 ? Lang.t("Aucun écran trouvé.") : Screens.several ? (Screens.projection === "extend" ? Lang.t("Clique un écran pour le régler, fais-le glisser pour le placer à côté d'un autre.") : Lang.t("Clique un écran pour le régler. Pour les placer, étends d'abord le bureau.")) : Lang.t("Un seul écran pour l'instant. Branches-en un autre et il apparaîtra ici.")
        wrapMode: Text.Wrap
        color: Qt.alpha(Theme.text, 0.6)
        font.family: Theme.font
        font.pixelSize: 12
    }

    ScreenMap {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        selected: root.display?.key ?? ""
        onChosen: key => root.selected = key
    }

    SettingSection {
        visible: !!root.display
        text: root.display ? Screens.nameOf(root.display) + (root.display.internal || !root.display.label ? "" : " · " + root.display.name) : ""
    }

    SettingSwitch {
        visible: Screens.several && !!root.display
        label: Lang.t("Allumé")
        hint: Screens.lit.length === 1 && root.display?.enabled ? Lang.t("Le seul allumé reste allumé.") : ""
        words: ["éteindre", "allumer", "désactiver", "disable", "off", "on"]
        on: root.display?.enabled ?? false
        onToggled: Screens.setOn(root.display.key, !root.display.enabled)
    }

    SettingChips {
        visible: (root.display?.enabled ?? false) && root.sizes.length > 0
        label: Lang.t("Définition")
        hint: Lang.t("Le nombre de points à l'écran.")
        words: ["résolution", "resolution", "taille", "pixels", "mode"]
        options: root.sizes
        current: root.display ? `${root.display.width}x${root.display.height}` : ""
        onPicked: id => root.pickSize(id)
    }

    SettingChips {
        visible: (root.display?.enabled ?? false) && root.speeds.length > 0
        label: Lang.t("Fréquence")
        hint: Lang.t("Combien d'images par seconde. Moins, c'est moins de batterie.")
        words: ["hz", "hertz", "rafraîchissement", "refresh", "rate", "fps"]
        options: root.speeds
        current: root.currentSpeed
        onPicked: id => Screens.setMode(root.display.key, id)
    }

    SettingChips {
        visible: root.display?.enabled ?? false
        label: Lang.t("Échelle")
        hint: Lang.t("Plus c'est grand, plus tout est gros et lisible.")
        words: ["scale", "zoom", "taille du texte", "hidpi", "agrandir"]
        options: root.display ? Screens.scalesFor(root.display).map(scale => ({ id: String(scale), label: `${Math.round(scale * 100)} %` })) : []
        current: root.display ? String(Screens.scalesFor(root.display).find(scale => Math.abs(scale - root.display.scale) < 0.01) ?? "") : ""
        onPicked: id => Screens.setScale(root.display.key, Number(id))
    }

    SettingChoice {
        visible: root.display?.enabled ?? false
        label: Lang.t("Rotation")
        hint: Lang.t("Pour un écran posé de côté ou à l'envers.")
        words: ["rotation", "pivoter", "tourner", "portrait", "paysage", "transform", "rotate"]
        options: [{ id: "0", label: Lang.t("Normale") }, { id: "1", label: "90°" }, { id: "2", label: "180°" }, { id: "3", label: "270°" }]
        current: String((root.display?.transform ?? 0) % 4)
        onPicked: id => Screens.setTransform(root.display.key, Number(id))
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: Lang.t("Un changement qui peut laisser l'écran noir demande confirmation : sans réponse, l'ancien affichage revient au bout de 15 secondes. Chaque ensemble d'écrans branchés garde sa propre disposition.")
        wrapMode: Text.Wrap
        color: Qt.alpha(Theme.text, 0.5)
        font.family: Theme.font
        font.pixelSize: 12
    }
}
