pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// What the music looks like right now, thanks to cava. It only listens while something
// on screen actually wants to dance: the ground on an empty page, or a media card.
Singleton {
    id: root

    property int listeners: 0
    property var levels: [] // exactly what cava hears
    property var shown: [] // what we actually draw: quick to rise, slow to settle
    property var replayed: [] // a recording of cava played back instead of what it hears, to test with

    // A note struck: where in the range it hit, 0 the lowest of the 26 bands, and how hard, 0 to 1
    signal struck(int band, real strength)

    readonly property bool replaying: replayed.length > 0
    readonly property bool dancing: replaying || Config.groundMusic !== "off" && Planet.pageEmpty && Mpris.players.values.some(player => player.isPlaying)
    readonly property bool wanted: listeners > 0 || dancing

    onWantedChanged: {
        cava.running = wanted;
        if (!wanted)
            levels = [];
    }

    function join() {
        listeners += 1;
    }

    function leave() {
        listeners = Math.max(0, listeners - 1);
    }

    // The lows, the middle and the highs each strike on their own: a sudden rise in what they
    // hear, well above their recent average, at most once per gap in seconds
    readonly property var voices: [{ from: 0, to: 6, gap: 0.25, above: 2 }, { from: 6, to: 15, gap: 0.18, above: 1.7 }, { from: 15, to: 26, gap: 0.14, above: 2 }]
    property var previous: []
    property var usual: [0, 0, 0]
    property var lastStrike: [0, 0, 0]
    property var armed: [true, true, true]

    function hear(next) {
        const now = Date.now() / 1000;
        voices.forEach((voice, v) => {
            let rise = 0, top = voice.from, steepest = -1;
            for (let i = voice.from; i < voice.to; i++) {
                const step = (next[i] ?? 0) - (previous[i] ?? 0);
                rise += Math.max(0, step);
                if (step > steepest) {
                    steepest = step;
                    top = i;
                }
            }
            rise /= voice.to - voice.from;
            const bar = usual[v] * voice.above + 0.01;
            if (armed[v] && rise > bar && now - lastStrike[v] > voice.gap) {
                armed[v] = false;
                lastStrike[v] = now;
                struck(top, Math.min(1, (rise - usual[v]) / (usual[v] * 4 + 0.02)));
            } else if (!armed[v] && rise < bar * 0.6) {
                armed[v] = true;
            }
            usual[v] += (rise - usual[v]) * 0.03;
        });
        previous = next;
        levels = next;
    }

    // Sound jumps around, but nothing on screen should. When the music stops,
    // everything sinks back down slowly, like a breath being let out.
    // Stepped on every frame the screen draws, so bars glide instead of jumping. The speeds
    // are per 25 ms and get scaled to however long the frame actually took.
    FrameAnimation {
        running: root.wanted || root.shown.length > 0
        onTriggered: {
            const count = Math.max(root.levels.length, root.shown.length);
            const steps = Math.min(frameTime, 0.1) / 0.025;
            const next = [];
            let highest = 0;
            for (let i = 0; i < count; i++) {
                const target = Math.min(1, (root.levels[i] ?? 0) * Config.musicGain), now = root.shown[i] ?? 0;
                const speed = target > now ? Config.musicRise : root.wanted ? Config.musicFall : Theme.groundSettle;
                const value = now + (target - now) * (1 - Math.pow(1 - speed, steps));
                next.push(value);
                highest = Math.max(highest, value);
            }
            root.shown = !root.wanted && highest < 0.004 ? [] : next;
        }
    }

    // qs ipc call beat state, to check the music is really flowing
    IpcHandler {
        target: "beat"

        function state(): string {
            return `wanted ${root.wanted}, dancing ${root.dancing}, heard ${root.levels.length}, shown ${root.shown.length}, peak ${Math.max(0, ...root.shown).toFixed(3)}`;
        }

        function hold(on: bool): void {
            on ? root.join() : root.leave();
        }

        // Plays back a file of cava's lines, looping, as if the music were on; "" stops
        function replay(path: string): void {
            recording.path = path;
            if (path === "")
                root.replayed = [];
        }
    }

    // cava can quit on its own, when the audio device changes for instance. Bring it back.
    Timer {
        id: revive

        interval: 1000
        onTriggered: cava.running = root.wanted
    }

    Process {
        id: cava

        running: root.wanted
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
        onRunningChanged: {
            if (!running && root.wanted)
                revive.restart();
        }
        stdout: SplitParser {
            onRead: line => {
                if (!root.replaying)
                    root.hear(line.split(";").filter(value => value !== "").map(value => Number(value) / 100));
            }
        }
    }

    FileView {
        id: recording

        onLoaded: root.replayed = text().split("\n").filter(line => line.includes(";")).map(line => line.split(";").filter(value => value !== "").map(value => Number(value) / 100))
    }

    // At cava's own pace, sixty lines a second
    Timer {
        property int line: 0

        interval: 16
        repeat: true
        running: root.replaying
        onTriggered: {
            line = (line + 1) % root.replayed.length;
            root.hear(root.replayed[line]);
        }
    }
}
