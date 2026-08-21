#!/usr/bin/env python3
"""Generate style-nf.json and style-plain.json from glamour's upstream dark.json.

base-dark.json is glamour's own styles/dark.json, unmodified. Only the h1-h6
entries are overridden here, so the rest of the schema stays upstream's rather
than hand-written.

Refresh the base with:
  curl -fsSL https://raw.githubusercontent.com/charmbracelet/glamour/master/styles/dark.json \
    -o base-dark.json
"""
import copy
import json
import pathlib

HERE = pathlib.Path(__file__).parent

# (key, fg, bg, nerd icon, plain marker)
#
# Icons are all from the Font Awesome block (U+F02D-U+F111), present in Nerd
# Font v1/v2/v3 alike. Do not reach for the Material Design block: its
# codepoints moved in Nerd Font v3 and break against older fonts.
LEVELS = [
    ("h1", "231", "63",  "", "#"),  # book
    ("h2", "212", None,  "", "▌"),  # bars
    ("h3", "117", None,  "", "▸"),  # caret-right
    ("h4", "114", None,  "", "●"),  # circle
    ("h5", "180", None,  "", "○"),  # circle-o
    ("h6", "245", None,  "", "–"),  # minus
]


def build(base, nerd):
    style = copy.deepcopy(base)
    for depth, (key, fg, bg, icon, plain) in enumerate(LEVELS, start=1):
        mark = icon if nerd else plain
        entry = {"color": fg, "bold": True, "block_prefix": "\n"}
        if key == "h1":
            entry.update({
                "background_color": bg,
                "prefix": f"  {mark}  ",
                "suffix": "  ",
                "block_suffix": "\n",
            })
        else:
            entry["prefix"] = f"{' ' * (depth - 2)}{mark} "
            if key in ("h5", "h6"):
                entry["bold"] = False
        style[key] = entry
    return style


def main():
    base = json.loads((HERE / "base-dark.json").read_text())
    for name, nerd in (("style-nf.json", True), ("style-plain.json", False)):
        out = build(base, nerd)
        (HERE / name).write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n")
        prefixes = [out[k]["prefix"].strip() for k, *_ in LEVELS]
        colors = [out[k]["color"] for k, *_ in LEVELS]
        assert len(set(prefixes)) == len(LEVELS), f"{name}: duplicate heading markers"
        assert len(set(colors)) == len(LEVELS), f"{name}: duplicate heading colors"
        print(f"wrote {name}  ({len(set(prefixes))}/{len(LEVELS)} distinct markers and colors)")


if __name__ == "__main__":
    main()
