pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// What the shell asks of the compositor it runs on, Hyprland or niri, in one place. On
// niri ETEA is only the decoration: the world, the bar, the widgets and the panels, while
// niri keeps its own workspaces and animations.
Singleton {
    id: root

    readonly property string name: Quickshell.env("NIRI_SOCKET") ? "niri" : "hyprland"
    readonly property bool niri: name === "niri"

    // niri's state as its event stream tells it: workspaces { id, idx, name, output,
    // is_active, is_focused }, windows { id, title, app_id, workspace_id, is_focused, layout }
    property var niriWorkspaces: []
    property var niriWindows: []
    property var niriOutputs: ({}) // name → { logical: { width, height, … } }
    property var niriLayouts: ({ names: [], current_idx: 0 })

    // The output you're working on, by name, and as a screen to put a window on
    readonly property string focusedOutput: niri ? niriWorkspaces.find(workspace => workspace.is_focused)?.output ?? "" : Hyprland.focusedMonitor?.name ?? ""
    readonly property var focusedScreen: Quickshell.screens.find(screen => screen.name === focusedOutput) ?? Quickshell.screens[0] ?? null

    // niri's workspaces on one output, top to bottom
    function workspacesOn(output) {
        return niriWorkspaces.filter(workspace => workspace.output === output).sort((a, b) => a.idx - b.idx);
    }

    function windowsOn(workspaceId) {
        return niriWindows.filter(window => window.workspace_id === workspaceId);
    }

    // A window as big as its output, which is how niri shows fullscreen
    function fullscreenOn(output) {
        const size = niriOutputs[output]?.logical;
        const workspace = niriWorkspaces.find(w => w.output === output && w.is_active);
        if (!size || !workspace)
            return false;
        return windowsOn(workspace.id).some(window => window.layout?.window_size?.[0] >= size.width && window.layout?.window_size?.[1] >= size.height);
    }

    function niriAction(args) {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }

    // One event from niri, applied to what we know
    function apply(event) {
        const [kind, data] = Object.entries(event)[0] ?? [];
        switch (kind) {
        case "WorkspacesChanged":
            niriWorkspaces = data.workspaces;
            break;
        case "WorkspaceActivated": {
            const output = niriWorkspaces.find(w => w.id === data.id)?.output;
            niriWorkspaces = niriWorkspaces.map(w => Object.assign({}, w, {
                is_active: w.id === data.id || (w.output !== output && w.is_active),
                is_focused: data.focused ? w.id === data.id : w.is_focused
            }));
            break;
        }
        case "WorkspaceActiveWindowChanged":
            niriWorkspaces = niriWorkspaces.map(w => w.id === data.workspace_id ? Object.assign({}, w, { active_window_id: data.active_window_id }) : w);
            break;
        case "WindowsChanged":
            niriWindows = data.windows;
            break;
        case "WindowOpenedOrChanged": {
            const others = niriWindows.filter(w => w.id !== data.window.id);
            niriWindows = (data.window.is_focused ? others.map(w => Object.assign({}, w, { is_focused: false })) : others).concat([data.window]);
            break;
        }
        case "WindowClosed":
            niriWindows = niriWindows.filter(w => w.id !== data.id);
            break;
        case "WindowFocusChanged":
            niriWindows = niriWindows.map(w => w.is_focused === (w.id === data.id) ? w : Object.assign({}, w, { is_focused: w.id === data.id }));
            break;
        case "WindowLayoutsChanged": {
            const layouts = new Map(data.changes);
            niriWindows = niriWindows.map(w => layouts.has(w.id) ? Object.assign({}, w, { layout: layouts.get(w.id) }) : w);
            break;
        }
        case "KeyboardLayoutsChanged":
            niriLayouts = data.keyboard_layouts;
            break;
        case "KeyboardLayoutSwitched":
            niriLayouts = Object.assign({}, niriLayouts, { current_idx: data.idx });
            break;
        }
    }

    // The stream opens with the whole state, then tells each change
    Process {
        id: events

        running: root.niri
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.apply(JSON.parse(line));
                } catch (error) {
                    console.warn("ETEA niri: can't read an event,", error);
                }
            }
        }
        onExited: reopen.restart()
    }

    Timer {
        id: reopen

        interval: 1000
        onTriggered: events.running = root.niri
    }

    // The outputs' sizes, which the stream doesn't carry, read again when niri reloads
    Process {
        id: outputs

        running: root.niri
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriOutputs = JSON.parse(text);
                } catch (error) {
                    console.warn("ETEA niri: can't read the outputs,", error);
                }
            }
        }
    }
}
