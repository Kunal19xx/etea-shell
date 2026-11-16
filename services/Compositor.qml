pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the shell asks of the compositor it runs on, Hyprland or niri, in one place. On
// niri ETEA is only the decoration: the world, the bar, the widgets and the panels, while
// niri keeps its own workspaces and animations.
Singleton {
    id: root

    readonly property string name: Quickshell.env("NIRI_SOCKET") ? "niri" : "hyprland"
    readonly property bool niri: name === "niri"

    // The output you're working on, by name, and as a screen to put a window on
    readonly property string focusedOutput: niri ? "" : Hyprland.focusedMonitor?.name ?? ""
    readonly property var focusedScreen: Quickshell.screens.find(screen => screen.name === focusedOutput) ?? Quickshell.screens[0] ?? null
}
