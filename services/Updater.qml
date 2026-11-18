pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keeps ETEA up to date from the git clone it runs from, through scripts/update.sh. It only
// asks GitHub when Settings › About is open or you press the button. Once the new files land,
// it reloads the shell on the new version.
Singleton {
    id: root

    property string commit: ""
    property string date: ""
    property string branch: ""

    // "idle", "checking", "current", "available", "behindMain", "updating", "updated",
    // "offline", "unmanaged", "edited" or "diverged"
    property string state: "idle"
    property int behind: 0
    property var changes: [] // titles of the commits waiting
    property string mainLine: "" // on a branch of its own, the main line it's behind, like "main"

    readonly property bool busy: state === "checking" || state === "updating"

    function refresh() {
        info.running = true;
    }

    function check() {
        if (busy)
            return;
        state = "checking";
        checker.running = true;
    }

    // Up to date with its own branch, or moved up to the main line it's behind
    function update() {
        if (busy)
            return;
        applier.command = ["bash", Quickshell.shellPath("scripts/update.sh"), state === "behindMain" ? "catchup" : "apply"];
        state = "updating";
        applier.running = true;
    }

    // What an exit code from the script means, when it isn't good news
    function trouble(code) {
        return { 2: "offline", 3: "unmanaged", 4: "edited", 5: "diverged" }[code] ?? "offline";
    }

    Process {
        id: info

        command: ["bash", Quickshell.shellPath("scripts/update.sh"), "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const [commit, date, branch] = text.trim().split("|");
                root.commit = commit ?? "";
                root.date = date ?? "";
                root.branch = branch ?? "";
            }
        }
        onExited: code => {
            if (code === 3)
                root.state = "unmanaged";
        }
    }

    Process {
        id: checker

        command: ["bash", Quickshell.shellPath("scripts/update.sh"), "check"]
        stdout: StdioCollector {
            id: news
        }
        onExited: code => {
            if (code !== 0) {
                root.state = root.trouble(code);
                return;
            }
            // Its own branch first; then, after "@ main", what the main line has beyond it
            const [own, main] = news.text.trim().split(/^@ /m);
            const lines = own.trim().split("\n");
            root.behind = Number(lines[0]) || 0;
            root.changes = lines.slice(1).filter(line => line !== "");
            root.mainLine = "";
            if (root.behind === 0 && main) {
                const rest = main.trim().split("\n");
                if (Number(rest[1]) > 0) {
                    root.mainLine = rest[0].trim();
                    root.behind = Number(rest[1]);
                    root.changes = rest.slice(2).filter(line => line !== "");
                }
            }
            root.state = root.behind === 0 ? "current" : root.mainLine ? "behindMain" : "available";
        }
    }

    Process {
        id: applier

        command: ["bash", Quickshell.shellPath("scripts/update.sh"), "apply"]
        onExited: code => {
            if (code !== 0) {
                root.state = root.trouble(code);
                return;
            }
            root.behind = 0;
            root.changes = [];
            root.state = "updated";
            // Quickshell reloads on its own as files change, but that can land halfway through
            // the merge, before a new folder is there, and leave the old version running.
            // Everything is in place now, so reload once more.
            Quickshell.reload(false);
        }
    }

    // qs ipc call update check | apply | state, for a script of your own
    IpcHandler {
        target: "update"

        function check(): void {
            root.check();
        }

        function apply(): void {
            root.update();
        }

        function state(): string {
            return `${root.state}, ${root.behind} behind, at ${root.commit} on ${root.branch}`;
        }
    }
}
