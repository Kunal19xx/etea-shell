pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Skies from elsewhere: the trending ones, or a search, on Wallhaven, or on Pixabay with
// your own key, shown on the belt's « Ailleurs » side. Only what you search for is sent.
// Keeping a sky downloads it into your wallpapers folder, one after the other, without
// wearing it. Answers are kept for a day, as Pixabay asks.
Singleton {
    id: root

    property string query: ""
    property bool dirty: false // typed since the last search
    property var results: [] // { remote, source, id, thumb, full, width, height, colors, palette, page, author }
    property bool busy: false
    property string error: ""

    // The filters: how they're sorted, over which stretch of time for the trending ones,
    // and Wallhaven's categories, general, anime and people
    property string sorting: "toplist" // "relevance", "toplist", "date_added", "random"
    property string topRange: "1M" // "1w", "1M", "1y"
    property var categories: ({ general: true, anime: false, people: false })
    property int page: 1
    property int lastPage: 1
    property string seed: ""

    // Keeping: what's waiting to come down, what's on its way, and what's been kept, by key
    property var queue: []
    property string downloading: ""
    property var kept: ({})

    readonly property string source: Config.onlineSource === "pixabay" && Config.pixabayKey ? "pixabay" : "wallhaven"
    readonly property string sourceName: source === "pixabay" ? "Pixabay" : "Wallhaven"
    readonly property var screen: Compositor.focusedScreen
    readonly property int wantWidth: Math.round((screen?.width ?? 1920) * (screen?.devicePixelRatio ?? 1))
    readonly property int wantHeight: Math.round((screen?.height ?? 1080) * (screen?.devicePixelRatio ?? 1))

    property var answers: ({}) // address without the key → { at, data }, a day at most

    // A new list, or more of the same added at the end
    signal refreshed(bool fresh)

    function keyOf(item) {
        return `${item.source}:${item.id}`;
    }

    function isKept(item) {
        return !!item?.remote && kept[keyOf(item)] !== undefined;
    }

    function isWaiting(item) {
        return !!item?.remote && (downloading === keyOf(item) || queue.some(entry => keyOf(entry.item) === keyOf(item)));
    }

    function address(text, page) {
        const q = encodeURIComponent(text.trim());
        if (source === "pixabay") {
            // Pixabay has no categories here, and no random: its popular ones stand in
            const order = sorting === "date_added" ? "latest" : "popular";
            return `https://pixabay.com/api/?key=${encodeURIComponent(Config.pixabayKey)}&q=${q}&image_type=photo&orientation=horizontal&min_width=${wantWidth}&min_height=${wantHeight}&safesearch=true&order=${order}&per_page=30&page=${page}`;
        }
        const kinds = ["general", "anime", "people"].map(kind => categories[kind] ? "1" : "0").join("");
        const sort = sorting === "relevance" && !q ? "toplist" : sorting;
        return `https://wallhaven.cc/api/v1/search?q=${q}&purity=100&categories=${kinds === "000" ? "100" : kinds}&atleast=${wantWidth}x${wantHeight}&sorting=${sort}${sort === "toplist" ? "&topRange=" + topRange : ""}${sort === "random" ? "&seed=" + seed : ""}&page=${page}`;
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

    function lastPageOf(data) {
        return source === "pixabay" ? Math.max(1, Math.ceil((data.totalHits ?? 0) / 30)) : data.meta?.last_page ?? 1;
    }

    // The first page of what the filters and the search ask for
    function search(text) {
        query = text ?? query;
        dirty = false;
        if (sorting === "relevance" && !query.trim())
            sorting = "toplist";
        else if (query.trim() && sorting === "toplist" && text !== undefined)
            sorting = "relevance";
        seed = Math.random().toString(36).slice(2, 8).padEnd(6, "0");
        fetch(1, true);
    }

    // The next page, at the end of the belt
    function more() {
        if (!busy && page < lastPage && results.length)
            fetch(page + 1, false);
    }

    function fetch(next, fresh) {
        error = "";
        const url = address(query, next);
        const id = url.replace(/key=[^&]*&?/, ""); // the key isn't kept
        const known = answers[id];
        if (known && Date.now() - known.at < 24 * 3600 * 1000) {
            take(known.data, next, fresh);
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
                const kept = Object.assign({}, answers);
                kept[id] = { at: Date.now(), data: data };
                answers = kept;
                save.restart();
                take(data, next, fresh);
            } catch (failure) {
                error = Lang.t("Réponse illisible.");
            }
        };
        request.open("GET", url);
        request.setRequestHeader("User-Agent", "ETEA-Shell");
        request.send();
    }

    function take(data, next, fresh) {
        page = next;
        lastPage = lastPageOf(data);
        const found = itemsOf(data);
        // A page can repeat what the last one had; each sky only once
        const seen = new Set(fresh ? [] : results.map(keyOf));
        results = (fresh ? [] : results).concat(found.filter(item => !seen.has(keyOf(item))));
        if (fresh && !results.length)
            error = query.trim() ? Lang.t("Rien trouvé pour « {0} ».", query) : Lang.t("Rien ici pour ces filtres.");
        refreshed(fresh);
    }

    // Keeps a sky: in line to come down into the folder, worn or not. answer(path, mtime),
    // when there is one, is told once it's down; one asked for now goes first.
    function keep(item, answer, now) {
        if (!item?.remote || isWaiting(item) || isKept(item) && !answer)
            return;
        if (isKept(item)) {
            answer(kept[keyOf(item)].path, kept[keyOf(item)].mtime);
            return;
        }
        const entry = { item: item, answer: answer ?? null };
        queue = now ? [entry].concat(queue) : queue.concat([entry]);
        next();
    }

    function next() {
        if (downloading || !queue.length)
            return;
        const entry = queue[0];
        queue = queue.slice(1);
        const item = entry.item;
        const folder = Pictures.folder || `${Quickshell.env("HOME")}/Pictures/Wallpapers`;
        const extension = (item.full.match(/\.(jpe?g|png|webp)(\?|$)/i)?.[1] ?? "jpg").toLowerCase();
        fetcher.entry = entry;
        fetcher.target = `${folder}/${item.source}-${item.id}.${extension}`;
        fetcher.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && curl -fsSL -A ETEA-Shell -o "$2.part" "$1" && mv "$2.part" "$2" && find "$2" -printf "%T@"', "sh", item.full, fetcher.target];
        downloading = keyOf(item);
        fetcher.running = true;
    }

    Process {
        id: fetcher

        property var entry: null
        property string target: ""

        stdout: StdioCollector {
            id: fetched
        }
        onExited: code => {
            const entry = fetcher.entry;
            root.downloading = "";
            fetcher.entry = null;
            if (code !== 0) {
                root.error = Lang.t("Le téléchargement a échoué.");
            } else {
                const mtime = fetched.text.trim();
                const kept = Object.assign({}, root.kept);
                kept[root.keyOf(entry.item)] = { path: fetcher.target, mtime: mtime };
                root.kept = kept;
                Pictures.refresh();
                entry.answer?.(fetcher.target, mtime);
            }
            root.next();
        }
    }

    // The day's answers, kept between sessions
    Timer {
        id: save

        interval: 1000
        onTriggered: {
            const now = Date.now(), fresh = {};
            for (const url in root.answers)
                if (now - root.answers[url].at < 24 * 3600 * 1000)
                    fresh[url] = root.answers[url];
            memory.setText(JSON.stringify(fresh));
        }
    }

    FileView {
        id: memory

        path: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/etea/online.json`
        printErrors: false
        onLoaded: {
            try {
                root.answers = JSON.parse(text());
            } catch (failure) {}
        }
    }
}
