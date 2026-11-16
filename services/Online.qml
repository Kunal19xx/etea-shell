pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Skies from elsewhere: a search on Wallhaven, or on Pixabay with your own key, shown on
// the belt as moons passing through. Only what you search for is sent, and a sky is only
// downloaded, into your wallpapers folder, once you land on it. Answers are kept for a day,
// as Pixabay asks.
Singleton {
    id: root

    property string query: ""
    property var results: [] // { remote, source, id, thumb, full, width, height, colors, palette, page }
    property bool busy: false
    property string error: ""
    property string downloading: "" // the id on its way down

    readonly property string source: Config.onlineSource === "pixabay" && Config.pixabayKey ? "pixabay" : "wallhaven"
    readonly property string sourceName: source === "pixabay" ? "Pixabay" : "Wallhaven"
    readonly property var screen: Compositor.focusedScreen
    readonly property int wantWidth: Math.round((screen?.width ?? 1920) * (screen?.devicePixelRatio ?? 1))
    readonly property int wantHeight: Math.round((screen?.height ?? 1080) * (screen?.devicePixelRatio ?? 1))

    property var kept: ({}) // address without the key → { at, data }, a day at most

    function address(text) {
        const q = encodeURIComponent(text.trim());
        if (source === "pixabay")
            return `https://pixabay.com/api/?key=${encodeURIComponent(Config.pixabayKey)}&q=${q}&image_type=photo&orientation=horizontal&min_width=${wantWidth}&min_height=${wantHeight}&safesearch=true&per_page=30`;
        // Nothing typed: the month's best
        return `https://wallhaven.cc/api/v1/search?q=${q}&purity=100&categories=111&atleast=${wantWidth}x${wantHeight}&sorting=${q ? "relevance" : "toplist"}`;
    }

    // Each answer in the belt's own terms, its colours turned into a palette when it has some
    function itemsOf(data) {
        const list = source === "pixabay" ? (data.hits ?? []).map(hit => ({
                    remote: true,
                    source: "pixabay",
                    id: String(hit.id),
                    thumb: hit.webformatURL,
                    // The original only comes with Pixabay's full access; the rest stops at 1280
                    full: hit.imageURL || hit.fullHDURL || hit.largeImageURL,
                    width: hit.imageURL ? hit.imageWidth : hit.fullHDURL ? 1920 : 1280,
                    height: hit.imageURL ? hit.imageHeight : Math.round((hit.fullHDURL ? 1920 : 1280) * hit.imageHeight / Math.max(1, hit.imageWidth)),
                    colors: [],
                    page: hit.pageURL,
                    author: hit.user ?? ""
                })) : (data.data ?? []).map(hit => ({
                    remote: true,
                    source: "wallhaven",
                    id: hit.id,
                    thumb: hit.thumbs?.large ?? hit.thumbs?.small,
                    full: hit.path,
                    width: hit.dimension_x,
                    height: hit.dimension_y,
                    colors: hit.colors ?? [],
                    page: hit.url,
                    author: ""
                }));
        for (const item of list)
            item.palette = item.colors.length >= 2 ? Forge.paletteOf(item.colors.map(color => Qt.color(color))) : null;
        return list;
    }

    function search(text) {
        query = text;
        error = "";
        const url = address(text);
        const id = url.replace(/key=[^&]*&?/, ""); // the key isn't kept
        const known = kept[id];
        if (known && Date.now() - known.at < 24 * 3600 * 1000) {
            results = itemsOf(known.data);
            return;
        }
        busy = true;
        const request = new XMLHttpRequest();
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE)
                return;
            busy = false;
            if (request.status === 429) {
                error = Lang.t("Trop de recherches d'un coup, réessaie dans une minute.");
                return;
            }
            if (request.status === 401 || request.status === 400 && source === "pixabay") {
                error = Lang.t("La clé Pixabay est refusée. Vérifie-la dans les Réglages.");
                return;
            }
            if (request.status !== 200) {
                error = Lang.t("Le ciel ne répond pas ({0}).", request.status || Lang.t("pas de réseau"));
                return;
            }
            try {
                const data = JSON.parse(request.responseText);
                const next = Object.assign({}, kept);
                next[id] = { at: Date.now(), data: data };
                kept = next;
                save.restart();
                results = itemsOf(data);
                if (!results.length)
                    error = Lang.t("Rien trouvé pour « {0} ».", text);
            } catch (failure) {
                error = Lang.t("Réponse illisible.");
            }
        };
        request.open("GET", url);
        request.setRequestHeader("User-Agent", "ETEA-Shell");
        request.send();
    }

    function clear() {
        results = [];
        error = "";
    }

    // Down into the wallpapers folder, named after where it came from; answer(path, mtime)
    function download(item, answer) {
        if (downloading)
            return;
        const folder = Pictures.folder || `${Quickshell.env("HOME")}/Pictures/Wallpapers`;
        const extension = (item.full.match(/\.(jpe?g|png|webp)(\?|$)/i)?.[1] ?? "jpg").toLowerCase();
        fetcher.answer = answer;
        fetcher.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && curl -fsSL -A ETEA-Shell -o "$2.part" "$1" && mv "$2.part" "$2" && find "$2" -printf "%T@"', "sh", item.full, `${folder}/${item.source}-${item.id}.${extension}`];
        downloading = item.id;
        fetcher.running = true;
    }

    Process {
        id: fetcher

        property var answer: null

        stdout: StdioCollector {
            id: fetched
        }
        onExited: code => {
            const answer = fetcher.answer;
            const path = fetcher.command[fetcher.command.length - 1];
            root.downloading = "";
            fetcher.answer = null;
            if (code !== 0) {
                root.error = Lang.t("Le téléchargement a échoué.");
                return;
            }
            answer?.(path, fetched.text.trim());
        }
    }

    // The day's answers, kept between sessions
    Timer {
        id: save

        interval: 1000
        onTriggered: {
            const now = Date.now(), fresh = {};
            for (const url in root.kept)
                if (now - root.kept[url].at < 24 * 3600 * 1000)
                    fresh[url] = root.kept[url];
            memory.setText(JSON.stringify(fresh));
        }
    }

    FileView {
        id: memory

        path: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/etea/online.json`
        printErrors: false
        onLoaded: {
            try {
                root.kept = JSON.parse(text());
            } catch (failure) {}
        }
    }
}
