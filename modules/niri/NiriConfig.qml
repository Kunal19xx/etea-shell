import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// On niri, the shortcuts reach ETEA through niri's own binds, and the windows wear ETEA's
// gaps, border and corners, all written to ~/.config/niri/etea.kdl, which the niri config
// includes. niri merges binds key by key and the layout field by field, so this only
// replaces what it names, and it live-reloads the file when it changes.
Scope {
    id: root

    readonly property string path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/niri/etea.kdl`

    // Key, what niri shows for it, and the IPC call it makes
    readonly property var binds: [
        ["Mod+Space", "Launcher", "launcher toggle"],
        ["Mod+L", "Lock", "lock lock"],
        ["Mod+A", "Logbook", "panels left"],
        ["Mod+N", "Control centre", "panels right"],
        ["Mod+V", "Clipboard history", "clipboard toggle"],
        ["Mod+Shift+S", "Capture (Tab for video)", "capture toggle"],
        ["Mod+I", "Settings", "settings toggle"],
        ["Ctrl+Mod+T", "Wallpaper", "skies open"],
        ["Mod+Escape", "Session menu", "session toggle"],
        ["Ctrl+Alt+Delete", "Session menu", "session toggle"]
    ]

    // niri wants #rrggbbaa
    function hex(color, alpha) {
        const byte = value => Math.round(value * 255).toString(16).padStart(2, "0");
        return `#${byte(color.r)}${byte(color.g)}${byte(color.b)}${byte(alpha)}`;
    }

    // Every window gets the same thin line, from the world's light to the middle of its
    // sky, laid across the whole workspace so it reads as one light over all the windows:
    // no focus look on niri. niri's gaps are the inner ones, the struts add the rest.
    readonly property string looks: {
        const line = `from="${hex(Theme.windowLit, Theme.traceLine)}" to="${hex(Theme.skyMid, Theme.traceLine)}" angle=135 relative-to="workspace-view"`;
        const edge = Math.max(0, Theme.windowGapOuter - Theme.windowGapInner);
        return `layout {
    gaps ${Theme.windowGapInner}
    struts {
        left ${edge}
        right ${edge}
        top ${edge}
        bottom ${edge}
    }
    focus-ring {
        off
    }
    border {
        on
        width ${Theme.traceWidth}
        active-gradient ${line}
        inactive-gradient ${line}
        urgent-gradient ${line}
    }
}

window-rule {
    geometry-corner-radius ${Theme.windowRadius}
    clip-to-geometry true
}

animations {
    window-open {
        duration-ms ${Theme.openSpark + Theme.openReveal}
        curve "linear"
        custom-shader r"
${opening}
"
    }
}
`;
    }

    // A window opens the way it does on Hyprland: ETEA's star is born in the world's light
    // where the window will be, then grows rounder into the window's shape, the window
    // showing inside it behind a thin rim of light. Flat, each edge over one pixel.
    readonly property string opening: {
        const light = Theme.windowLit;
        const rgb = `vec3(${light.r.toFixed(3)}, ${light.g.toFixed(3)}, ${light.b.toFixed(3)})`;
        return `vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    vec3 light = ${rgb};
    float p = niri_clamped_progress;
    vec2 half_size = size_geo.xy * 0.5;
    vec2 px = (coords_geo.xy - vec2(0.5)) * size_geo.xy;
    float shortest = min(half_size.x, half_size.y);

    // The star, born a little too big, then settling, for the first third
    float born = clamp(p / 0.32, 0.0, 1.0);
    float star_size = 26.0 * born * (1.0 + 0.35 * sin(born * 3.14159));

    // Then it opens: rounder (the exponent climbs from the star's 0.62), wider, and
    // stretched from square to the window's own proportions
    float t = clamp((p - 0.32) / 0.68, 0.0, 1.0);
    t = t * t * (3.0 - 2.0 * t);
    float bend = mix(0.62, 8.0, t * t);
    vec2 scale = mix(vec2(shortest), half_size, t);
    vec2 q = abs(px) / scale;
    float shape = pow(pow(q.x, bend) + pow(q.y, bend), 1.0 / bend);
    float reach = mix(star_size / shortest, 1.12, t);
    float edge = 1.0 / min(scale.x, scale.y);
    float inside = clamp((reach - shape) / edge + 0.5, 0.0, 1.0);

    vec3 coords_tex = niri_geo_to_tex * coords_geo;
    vec4 window = texture2D(niri_tex, coords_tex.st) * inside;
    // The star's light drains away as the window shows through, leaving a rim that thins out
    float fill = 1.0 - smoothstep(0.0, 0.4, t);
    float rim = clamp((shape - (reach - 2.0 * edge)) / edge + 0.5, 0.0, 1.0) * (1.0 - t);
    return mix(window, vec4(light, 1.0) * inside, max(fill, rim));
}`;
    }

    readonly property string text: {
        const shell = Quickshell.shellPath("").replace(/\/$/, "");
        const lines = binds.map(([key, title, call]) => {
            const args = ["qs", "-p", shell, "ipc", "call"].concat(call.split(" "));
            return `    ${key} hotkey-overlay-title="ETEA: ${title}" { spawn ${args.map(arg => JSON.stringify(arg)).join(" ")}; }`;
        });
        return `// Written by ETEA Shell each time it starts on niri; changes here don't last.\n// Include it last in config.kdl: include optional=true "etea.kdl"\n\nbinds {\n${lines.join("\n")}\n}\n\n${looks}`;
    }

    // Written only when it differs, so niri isn't asked to reload for nothing, and a moment
    // after a slider stops
    onTextChanged: write.restart()

    Timer {
        id: write

        interval: 300
        onTriggered: {
            if (file.text() !== root.text)
                file.setText(root.text);
        }
    }

    // Super on its own opens the launcher, through a small listener niri can't replace
    Process {
        id: superTap

        running: true
        command: ["python3", Quickshell.shellPath("scripts/super-tap.py"), Quickshell.shellPath("").replace(/\/$/, "")]
        stderr: SplitParser {
            onRead: line => console.warn("ETEA", line)
        }
        // Back after a crash, but not when it can't read the keyboard at all
        onExited: code => {
            if (code !== 1)
                retap.restart();
        }
    }

    Timer {
        id: retap

        interval: 3000
        onTriggered: superTap.running = true
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        onLoaded: write.restart()
        onLoadFailed: write.restart()
    }
}
