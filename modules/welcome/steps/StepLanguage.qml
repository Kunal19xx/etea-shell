import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.settings

ColumnLayout {
    spacing: 14

    SettingChoice {
        label: Lang.t("Langue du shell")
        hint: Lang.t("Automatique suit la langue de ton système.")
        options: [{ id: "auto", label: Lang.t("Automatique") }].concat(Lang.languages)
        current: Config.language
        onPicked: id => Config.language = id
    }
}
