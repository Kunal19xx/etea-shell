import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.settings

ColumnLayout {
    spacing: 14

    SettingSlider {
        label: Lang.t("Grain")
        value: Config.grain
        maximum: 2
        shownAs: 100
        unit: " %"
        onMoved: value => Config.grain = Math.round(value * 20) / 20
    }

    SettingSlider {
        label: Lang.t("Relief")
        value: Config.terrainRelief
        maximum: 2.5
        decimals: 1
        onMoved: value => Config.terrainRelief = value
    }

    SettingChoice {
        label: Lang.t("Musique sur le terrain")
        options: [{ id: "lines", label: Lang.t("Lignes") }, { id: "bars", label: Lang.t("Barres") }, { id: "off", label: Lang.t("Rien") }]
        current: Config.groundMusic
        onPicked: id => Config.groundMusic = id
    }
}
