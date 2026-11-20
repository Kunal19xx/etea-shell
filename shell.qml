import Quickshell
import qs.modules.alerts
import qs.modules.background
import qs.modules.capture
import qs.modules.cheatsheet
import qs.modules.clipboard
import qs.modules.bar
import qs.modules.bar.menus
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.lock
import qs.modules.niri
import qs.modules.osd
import qs.modules.panels
import qs.modules.polkit
import qs.modules.screens
import qs.modules.session
import qs.modules.settings
import qs.modules.stage
import qs.modules.welcome
import qs.services

// Where it all starts: the world in the back, the stage over the windows, the bar on top.
// On niri ETEA is only the decoration: Hyprland's window looks stay out.
ShellRoot {
    // Made at start, so it can look for a new version once a day
    readonly property var updates: Updater

    Background {}

    // On niri the stage stays only for the belt of skies: nothing there turns the planet
    Stage {}
    PageShortcuts {}

    LazyLoader {
        active: !Compositor.niri

        Illumination {}
    }

    // And on niri, the shortcuts it hands to the shell
    LazyLoader {
        active: Compositor.niri

        NiriConfig {}
    }
    TerminalColors {}
    Bar {}
    TrayRecall {}
    BarMenus {}
    DeskMenu {}
    Launcher {}
    Notifications {}
    Panels {}
    Lock {}
    Settings {}
    Session {}
    Polkit {}
    Alerts {}
    Cheatsheet {}
    Osd {}
    KeepScreens {}
    Clipboard {}
    Capture {}
    Welcome {}
}
