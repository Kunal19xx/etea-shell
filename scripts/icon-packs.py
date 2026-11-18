#!/usr/bin/env python3
"""Builds the icon packs in assets/icons/ from assets/icons/packs.tsv.

    scripts/icon-packs.py            fetches every pack again
    scripts/icon-packs.py phosphor   only the packs named

Each line of packs.tsv is one of ETEA's icons, with its name in Material Symbols and in
Phosphor. assets/icons/ itself is the filled Material pack and stays as it is: the others
go in a folder of their own, same file names, white like the rest so the shell can tint
them. A new icon is one more line in the table and one more run of this script.
"""

import re
import sys
import urllib.request
from pathlib import Path

ICONS = Path(__file__).resolve().parent.parent / "assets" / "icons"
PHOSPHOR = "https://unpkg.com/@phosphor-icons/core@2.1.1"
MATERIAL = "https://fonts.gstatic.com/s/i/short-term/release/materialsymbolsrounded"

# Phosphor's fill puts these plain marks in a filled square, too heavy for the bar: bold
# keeps them solid without the box
BOLD = {"plus", "x", "check", "list-checks"}


def phosphor_fill(name):
    weight = "bold" if name in BOLD else "fill"
    return f"{PHOSPHOR}/assets/{weight}/{name}-{weight}.svg"


# folder: (column of packs.tsv, where an icon of that name lives)
PACKS = {
    "phosphor-fill": ("phosphor", phosphor_fill),
    "phosphor": ("phosphor", lambda name: f"{PHOSPHOR}/assets/regular/{name}.svg"),
    "material-light": ("material", lambda name: f"{MATERIAL}/{name}/wght300/48px.svg"),
}
LICENSES = {
    "phosphor-fill": f"{PHOSPHOR}/LICENSE",
    "phosphor": f"{PHOSPHOR}/LICENSE",
}


def fetch(url):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=20) as answer:
                return answer.read().decode()
        except OSError as error:
            if attempt == 3 or getattr(error, "code", None) == 404:
                raise SystemExit(f"Can't fetch {url}: {error}")
    return ""


# Only the shapes are kept, in white, at the same size as the filled icons
def tidy(svg):
    view = re.search(r'viewBox="([^"]+)"', svg)
    inner = re.search(r"<svg[^>]*>(.*)</svg>", svg, re.S)
    if not view or not inner or re.search(r"<script|\son\w+=", svg, re.I):
        raise SystemExit("Not an icon: " + svg[:80])
    shapes = re.sub(r'\s(fill|stroke)="currentColor"', "", inner.group(1)).strip()
    return f'<svg fill="#ffffff" xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="{view.group(1)}">{shapes}</svg>'


def main():
    rows = [line.split("\t") for line in (ICONS / "packs.tsv").read_text().splitlines() if line and not line.startswith("#")]
    columns = {"material": 1, "phosphor": 2}
    wanted = sys.argv[1:] or list(PACKS)
    for pack in wanted:
        if pack not in PACKS:
            raise SystemExit(f"No pack called {pack}. Packs: {', '.join(PACKS)}")
        column, where = PACKS[pack]
        folder = ICONS / pack
        folder.mkdir(exist_ok=True)
        for row in rows:
            (folder / f"{row[0]}.svg").write_text(tidy(fetch(where(row[columns[column]]))))
        if pack in LICENSES:
            (folder / "LICENSE.txt").write_text(fetch(LICENSES[pack]))
        print(f"{pack}: {len(rows)} icons")


main()
