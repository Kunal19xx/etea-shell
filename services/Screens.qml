pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The screens plugged in, and how they're shown: each one's mode, scale and turn, and
// how they sit together, side by side, mirrored, or only one lit. What you pick is kept
// in Config, laid over the compositor's own config, and comes back after a reload.
// A change that could leave you in the dark asks to be kept, and undoes itself otherwise.
Singleton {
    id: root

    // { key, name, label, internal, enabled, width, height, refresh, mode, x, y, scale,
    //   transform, mirror, modes: [{ id, width, height, refresh }] }
    property var outputs: []
    readonly property var lit: outputs.filter(output => output.enabled)
    readonly property bool several: outputs.length > 1
    // The one the others copy: the laptop's own if there's one, or the first
    readonly property var primary: outputs.find(output => output.internal) ?? outputs[0] ?? null
    // This set of screens, plugged together. Each set keeps its own arrangement.
    readonly property string setup: outputs.map(output => output.key).sort().join(" + ")
    // How they're shown now: "extend", "mirror", or "only:<key>"
    readonly property string projection: {
        if (lit.length === 1 && several)
            return "only:" + lit[0].key;
        return outputs.some(output => output.mirror) ? "mirror" : "extend";
    }
    readonly property bool canMirror: !Compositor.niri
    // Every way of showing them, in the order Super+P or the panel's tile goes round them
    readonly property var kinds: several ? ["extend"].concat(canMirror ? ["mirror"] : []).concat(outputs.map(output => "only:" + output.key)) : []

    function projectionName(kind) {
        if (kind === "extend")
            return Lang.t("Étendre");
        if (kind === "mirror")
            return Lang.t("Dupliquer");
        return Lang.t("Seulement {0}", nameOf(outputs.find(output => "only:" + output.key === kind)));
    }

    function projectNext() {
        if (kinds.length)
            project(kinds[(kinds.indexOf(projection) + 1) % kinds.length]);
    }

    // A change waiting for you to keep it, and the seconds left before it's undone
    property var before: null
    property int countdown: 0
    readonly property bool asking: before !== null

    // The choices offered for a screen's size
    function scalesFor(output) {
        const [width, height] = output.transform % 2 ? [output.height, output.width] : [output.width, output.height];
        return [1, 1.25, 1.5, 1.75, 2, 2.5, 3].filter(scale => {
            const w = width / scale, h = height / scale;
            return scale === 1 || (Math.abs(w - Math.round(w)) < 0.01 && Math.abs(h - Math.round(h)) < 0.01 && h >= 600);
        });
    }

    // Its size on the desktop, once scaled and turned
    function logical(output) {
        const w = output.width / output.scale, h = output.height / output.scale;
        return output.transform % 2 ? { width: h, height: w } : { width: w, height: h };
    }

    function nameOf(output) {
        if (!output)
            return "";
        return output.internal ? Lang.t("Écran du portable") : output.label || output.name;
    }

    function modeText(mode) {
        return `${mode.width} × ${mode.height} · ${Math.round(mode.refresh)} Hz`;
    }

    // --- What you pick ---

    function setMode(key, mode) {
        change(() => remember(key, { mode: mode }), true);
    }

    function setScale(key, scale) {
        change(() => remember(key, { scale: scale }), true);
    }

    function setTransform(key, transform) {
        change(() => remember(key, { transform: transform }), true);
    }

    function setOn(key, on) {
        const set = arrangement();
        const off = (set.off ?? []).filter(other => other !== key).concat(on ? [] : [key]);
        // Never the last one
        if (outputs.every(output => off.includes(output.key)))
            return;
        change(() => arrange({ off: off }), !on);
    }

    function project(kind) {
        if (kind === projection && !asking)
            return;
        const only = kind.startsWith("only:") ? kind.slice(5) : "";
        const off = only ? outputs.map(output => output.key).filter(key => key !== only) : [];
        change(() => arrange({ mirror: kind === "mirror", off: off }), only !== "");
    }

    // Positions in the desktop's own pixels, for every lit screen at once
    function place(positions) {
        change(() => arrange({ at: positions, mirror: false }), false);
    }

    function keep() {
        before = null;
        countdown = 0;
        ticking.stop();
    }

    function undo() {
        if (!before)
            return;
        const live = before.live;
        Config.screens = before.screens;
        Config.screenSetups = before.setups;
        keep();
        apply(true, live);
    }

    function change(edit, risky) {
        if (risky && !before) {
            before = { screens: copy(Config.screens), setups: copy(Config.screenSetups), live: copy(outputs) };
            countdown = 15;
            ticking.restart();
        }
        edit();
        apply(true);
    }

    function remember(key, values) {
        const screens = copy(Config.screens);
        screens[key] = Object.assign({}, screens[key] ?? {}, values);
        Config.screens = screens;
    }

    function arrangement() {
        return Config.screenSetups[setup] ?? {};
    }

    function arrange(values) {
        const setups = copy(Config.screenSetups);
        setups[setup] = Object.assign({}, setups[setup] ?? {}, values);
        Config.screenSetups = setups;
    }

    function copy(value) {
        return JSON.parse(JSON.stringify(value ?? {}));
    }

    Timer {
        id: ticking

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.undo();
        }
    }

    // --- What the compositor is told ---

    // How a screen should be, from what's saved for it and for this set of screens.
    // Nothing saved means nothing to say: the compositor's own config stays in charge.
    function wanted(output) {
        const own = Config.screens[output.key];
        const set = several ? Config.screenSetups[setup] : null;
        if (!own && !set)
            return null;
        const off = set?.off ?? [];
        const enabled = !off.includes(output.key) || outputs.every(other => off.includes(other.key)) && output === primary;
        const mirror = enabled && set?.mirror && primary && output.key !== primary.key ? primary.name : "";
        const mode = own?.mode && output.modes.some(m => m.id === own.mode) ? own.mode : output.enabled ? output.mode : "preferred";
        const at = set?.at?.[output.key];
        return {
            enabled: enabled,
            mirror: mirror,
            mode: mode,
            scale: own?.scale ?? output.scale,
            transform: own?.transform ?? output.transform,
            position: at ? `${Math.round(at[0])}x${Math.round(at[1])}` : output.enabled && !output.mirror ? `${output.x}x${output.y}` : "auto"
        };
    }

    function differs(output, want) {
        if (want.enabled !== output.enabled)
            return true;
        if (!want.enabled)
            return false;
        return want.mirror !== output.mirror || want.mode !== output.mode || Math.abs(want.scale - output.scale) > 0.001 || want.transform !== output.transform || (want.position !== "auto" && want.position !== `${output.x}x${output.y}`);
    }

    // How a screen was, to go back to when nothing was saved for it
    function asItWas(was) {
        return { enabled: was.enabled, mirror: was.mirror, mode: was.mode || "preferred", scale: was.scale, transform: was.transform, position: was.enabled && !was.mirror ? `${was.x}x${was.y}` : "auto" };
    }

    // Only the screens that aren't as they should be, unless asked for all of them. Going
    // back, the screens nothing was saved for return to how they were.
    function apply(all, live) {
        if (!Config.ready || outputs.length === 0)
            return;
        const told = [];
        for (const output of outputs) {
            const was = live?.find(other => other.key === output.key);
            const want = wanted(output) ?? (was ? asItWas(was) : null);
            if (want && (all || differs(output, want)))
                told.push([output, want]);
        }
        if (told.length === 0)
            return;
        if (Compositor.niri) {
            for (const [output, want] of told)
                niriApply(output, want);
        } else {
            // Turned on before the others go dark, so there's always one to land on
            told.sort((a, b) => b[1].enabled - a[1].enabled);
            send.lines = told.map(([output, want]) => hyprSpec(output, want));
        }
        reread.restart();
    }

    function hyprSpec(output, want) {
        if (!want.enabled)
            return `hl.monitor({ output = "${output.name}", disabled = true })`;
        const mirror = want.mirror ? `, mirror = "${want.mirror}"` : "";
        return `hl.monitor({ output = "${output.name}", mode = "${want.mode}", position = "${want.position}", scale = ${want.scale}, transform = ${want.transform}${mirror} })`;
    }

    readonly property var niriTurns: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

    function niriApply(output, want) {
        const run = args => Quickshell.execDetached(["niri", "msg", "output", output.name].concat(args));
        if (!want.enabled) {
            run(["off"]);
            return;
        }
        run(["on"]);
        if (want.mode !== "preferred")
            run(["mode", want.mode]);
        run(["scale", String(want.scale)]);
        run(["transform", niriTurns[want.transform] ?? "normal"]);
        if (want.position !== "auto")
            run(["position", "set"].concat(want.position.split("x")));
    }

    // Asked again while still going, it goes once more as soon as it's done
    Process {
        id: send

        property var lines: []
        property bool again: false

        onLinesChanged: {
            if (running)
                again = true;
            else if (lines.length)
                running = true;
        }
        command: ["hyprctl", "eval", lines.join("\n")]
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok")
                    console.warn("ETEA screens:", text.trim());
            }
        }
    }

    // --- What the compositor says ---

    function read(text) {
        let list = [];
        try {
            list = Compositor.niri ? readNiri(JSON.parse(text)) : readHyprland(JSON.parse(text));
        } catch (error) {
            console.warn("ETEA screens: can't read the outputs,", error);
            return;
        }
        const setupBefore = setup;
        outputs = list.sort((a, b) => b.internal - a.internal || a.name.localeCompare(b.name));
        // A screen plugged in or out: the arrangement kept for this set comes back
        if (setup !== setupBefore || reloaded) {
            reloaded = false;
            apply(false);
        }
    }

    property bool reloaded: false // the compositor's config was read again, ours goes on top

    function isInternal(name) {
        return /^(eDP|LVDS|DSI)/.test(name);
    }

    function readHyprland(monitors) {
        return monitors.map(monitor => {
            const modes = (monitor.availableModes ?? []).map(text => {
                const [size, rate] = text.replace("Hz", "").split("@");
                const [width, height] = size.split("x").map(Number);
                return { id: `${size}@${rate}`, width: width, height: height, refresh: Number(rate) };
            });
            const current = modes.find(m => m.width === monitor.width && m.height === monitor.height && Math.abs(m.refresh - monitor.refreshRate) < 0.05);
            return {
                key: monitor.description || monitor.name,
                name: monitor.name,
                label: [monitor.make, monitor.model].filter(part => part && part !== "Unknown").join(" "),
                internal: isInternal(monitor.name),
                enabled: !monitor.disabled,
                width: monitor.width,
                height: monitor.height,
                refresh: monitor.refreshRate,
                mode: current?.id ?? `${monitor.width}x${monitor.height}@${monitor.refreshRate.toFixed(2)}`,
                x: monitor.x,
                y: monitor.y,
                scale: monitor.scale,
                transform: monitor.transform,
                mirror: monitor.mirrorOf && monitor.mirrorOf !== "none" ? (monitors.find(other => String(other.id) === String(monitor.mirrorOf))?.name ?? monitor.mirrorOf) : "",
                modes: modes
            };
        });
    }

    function readNiri(outputs) {
        const turns = { Normal: 0, _90: 1, _180: 2, _270: 3, Flipped: 4, Flipped90: 5, Flipped180: 6, Flipped270: 7 };
        return Object.values(outputs).map(output => {
            const modes = (output.modes ?? []).map(m => ({ id: `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`, width: m.width, height: m.height, refresh: m.refresh_rate / 1000 }));
            const current = output.current_mode !== null && output.current_mode !== undefined ? modes[output.current_mode] : null;
            const logical = output.logical;
            return {
                key: [output.make, output.model, output.serial].filter(part => part).join(" ") || output.name,
                name: output.name,
                label: [output.make, output.model].filter(part => part && part !== "Unknown").join(" "),
                internal: isInternal(output.name),
                enabled: !!logical,
                width: current?.width ?? 0,
                height: current?.height ?? 0,
                refresh: current?.refresh ?? 0,
                mode: current?.id ?? "",
                x: logical?.x ?? 0,
                y: logical?.y ?? 0,
                scale: logical?.scale ?? 1,
                transform: turns[logical?.transform] ?? 0,
                mirror: "",
                modes: modes
            };
        });
    }

    Process {
        id: reader

        property bool again: false

        command: Compositor.niri ? ["niri", "msg", "--json", "outputs"] : ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }
    }

    function look() {
        if (reader.running)
            reader.again = true;
        else
            reader.running = true;
    }

    // The compositor takes a moment to settle a new mode
    Timer {
        id: reread

        interval: 400
        onTriggered: root.look()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "monitoraddedv2" || event.name === "monitorremovedv2")
                reread.restart();
            // A reload brings back the config's own monitors, ours go on top again
            else if (event.name === "configreloaded") {
                root.reloaded = true;
                root.look();
            }
        }
    }

    // niri doesn't tell, but the screens Quickshell sees change with it
    Connections {
        target: Quickshell

        function onScreensChanged() {
            reread.restart();
        }
    }

    Connections {
        target: Config

        function onReadyChanged() {
            root.apply(false);
        }
    }

    // For a key binding, like Super+P, or to look from a terminal
    IpcHandler {
        target: "screens"

        // "extend", "mirror", "only:<screen>", or "next" to go round them
        function project(kind: string): void {
            if (kind === "next")
                root.projectNext();
            else
                root.project(kind);
        }

        function menu(): void {
            Menus.toggle("screens", (Compositor.focusedScreen?.width ?? 0) / 2);
        }

        function keep(): void {
            root.keep();
        }

        function undo(): void {
            root.undo();
        }

        function state(): string {
            return JSON.stringify({ projection: root.projection, setup: root.setup, asking: root.asking, countdown: root.countdown, outputs: root.outputs.map(output => ({ key: output.key, name: output.name, enabled: output.enabled, mode: output.mode, x: output.x, y: output.y, scale: output.scale, transform: output.transform, mirror: output.mirror, modes: output.modes.length })) });
        }
    }

    Component.onCompleted: look()
}
