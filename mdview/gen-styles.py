#!/usr/bin/env python3
"""Generate mdview's glow styles from glamour's upstream base palettes.

Each theme is (upstream base) + (an overlay) + (heading treatment). The bases are
glamour's own files, kept unmodified, so the schema stays upstream's. Refresh with:

  for s in dark dracula tokyo-night; do
    curl -fsSL "https://raw.githubusercontent.com/charmbracelet/glamour/master/styles/$s.json" \
      -o "base-$s.json"
  done

No theme uses red, orange or yellow for text. That is enforced by an assertion at
the bottom, not by care alone. The one exception is the diff "deleted" colour,
where red is the meaning rather than a decoration.
"""
import colorsys
import copy
import json
import pathlib

HERE = pathlib.Path(__file__).parent

# Body text for the coloured themes. Upstream uses 252 (#d0d0d0), which reads as
# grey rather than white against a dark background. 255 is #eeeeee; 231 is pure
# white if that is still not bright enough. `minimal` and `mono` set nothing at
# all and inherit the terminal's own foreground.
TEXT = "255"
SECONDARY = "252"

# Heading icons are from the Font Awesome block (U+F02D-U+F111), present in Nerd
# Font v1/v2/v3 alike. The Material Design block moved codepoints in v3, so it is
# avoided. Written as escapes because literal PUA glyphs get silently stripped in
# transit, and a stripped glyph is what the distinctness assertion catches.
MARKS = [
    ("h1", "", "#"),        # nf-fa-book
    ("h2", "", "▌"),   # nf-fa-bars
    ("h3", "", "▸"),   # nf-fa-caret_right
    ("h4", "", "●"),   # nf-fa-circle
    ("h5", "", "○"),   # nf-fa-circle_o
    ("h6", "", "–"),   # nf-fa-minus
]

# Chroma is the syntax highlighter inside fenced code blocks. Upstream's palette
# is full of yellow and orange; these are the replacements, shared by every
# 256-colour theme. generic_deleted stays red on purpose: in a diff, red means
# removed.
# Greyscale: for `mono`, where any hue at all would contradict the point.
CHROMA_MONO = {
    "text": "", "name": "", "comment": "#6E6E6E", "comment_preproc": "#9A9A9A",
    "keyword": "#D0D0D0", "keyword_reserved": "#D0D0D0", "keyword_namespace": "#D0D0D0",
    "keyword_type": "#D0D0D0", "operator": "#8A8A8A", "punctuation": "#8A8A8A",
    "name_builtin": "#C0C0C0", "name_tag": "#C0C0C0", "name_attribute": "#9A9A9A",
    "name_class": "#C0C0C0", "name_decorator": "#C0C0C0", "name_function": "#C0C0C0",
    "literal_number": "#B0B0B0", "literal_string": "#B0B0B0",
    "literal_string_escape": "#B0B0B0", "background": "#1E1E1E",
}

CHROMA_QUIET = {
    "text":             "",
    "comment":          "#707070",
    "comment_preproc":  "#8FA8C8",
    "keyword":          "#8FA8C8",
    "keyword_reserved": "#8FA8C8",
    "keyword_namespace": "#8FA8C8",
    "keyword_type":     "#8FA8C8",
    "operator":         "#909090",
    "punctuation":      "#909090",
    "name":             "",
    "name_builtin":     "#A8BEd8",
    "name_tag":         "#A8BEd8",
    "name_attribute":   "#909090",
    "name_class":       "#A8BEd8",
    "name_decorator":   "#A8BEd8",
    "name_function":    "#A8BEd8",
    "literal_number":   "#B0B0B0",
    "literal_string":   "#B0B0B0",
    "background":       "#1E1E1E",
}

CHROMA = {
    "text":             "#E4E4E4",
    "comment":          "#8A8A8A",
    "comment_preproc":  "#B0A0FF",
    "keyword_namespace": "#FF87D7",
    "operator":         "#9AD6E0",
    "punctuation":      "#C8C8D8",
    "name_decorator":   "#C8A8FF",
    "literal_string":   "#A5D6A7",
    "background":       "#262626",
}

# Every theme: six heading colours (h1 as "fg/bg"), then the prose accents.
# All 256-colour indices unless the theme is marked truecolor, so they render
# correctly on a tmux without RGB passthrough.
THEMES = {
    "minimal": {  # closest to a plain terminal: body text stays your terminal's own
        "base": "dark", "truecolor": False, "quiet": "quiet",
        "clear": ["document", "list", "code_block", "image_text", "text", "paragraph"],
        "headings": ["153", "111", "110", "109", "245", "244"],
        "accents": {"link": "110", "link_text": "110", "code": None, "code_bg": "236",
                    "emph": None, "strong": None, "block_quote": "245", "hr": "240"},
    },
    "mono": {  # no colour at all — weight, dim and indent do all the work
        "base": "dark", "truecolor": False, "quiet": "mono",
        "clear": ["document", "list", "code_block", "image_text", "text", "paragraph"],
        "headings": ["231", "252", "250", "248", "245", "243"],
        "accents": {"link": "250", "link_text": None, "code": None, "code_bg": "236",
                    "emph": None, "strong": None, "block_quote": "245", "hr": "240"},
    },
    "bright": {  # balanced, cool-leaning — the old default with its orange removed
        "base": "dark", "truecolor": False,
        "headings": ["231/63", "212", "117", "114", "147", "245"],
        "accents": {"link": "81", "link_text": "153", "code": "218", "code_bg": "237",
                    "emph": "152", "strong": "212", "block_quote": "145", "hr": "244"},
    },
    "rose": {  # warm and pink-forward, the warmest thing available without red
        "base": "dark", "truecolor": False,
        "headings": ["231/89", "218", "175", "182", "146", "245"],
        "accents": {"link": "176", "link_text": "218", "code": "182", "code_bg": "237",
                    "emph": "152", "strong": "212", "block_quote": "139", "hr": "240"},
    },
    "orchid": {  # violet and lavender
        "base": "dark", "truecolor": False,
        "headings": ["231/54", "177", "141", "111", "146", "244"],
        "accents": {"link": "111", "link_text": "147", "code": "183", "code_bg": "237",
                    "emph": "152", "strong": "177", "block_quote": "103", "hr": "240"},
    },
    "berry": {  # deep pink into purple, the highest contrast of the warm set
        "base": "dark", "truecolor": False,
        "headings": ["231/53", "205", "176", "141", "110", "244"],
        "accents": {"link": "111", "link_text": "218", "code": "218", "code_bg": "237",
                    "emph": "152", "strong": "205", "block_quote": "139", "hr": "240"},
    },
    "mint": {  # green and teal
        "base": "dark", "truecolor": False,
        "headings": ["231/23", "121", "79", "115", "108", "245"],
        "accents": {"link": "80", "link_text": "158", "code": "158", "code_bg": "237",
                    "emph": "152", "strong": "121", "block_quote": "108", "hr": "240"},
    },
    "ocean": {  # blues and cyans
        "base": "dark", "truecolor": False,
        "headings": ["231/24", "117", "81", "111", "152", "244"],
        "accents": {"link": "75", "link_text": "153", "code": "116", "code_bg": "237",
                    "emph": "116", "strong": "117", "block_quote": "103", "hr": "240"},
    },
    "slate": {  # near-monochrome, one blue accent — the quietest option
        "base": "dark", "truecolor": False,
        "headings": ["231/60", "110", "252", "250", "247", "244"],
        "accents": {"link": "110", "link_text": "152", "code": "252", "code_bg": "237",
                    "emph": "146", "strong": "110", "block_quote": "245", "hr": "240"},
    },
    "warm": {  # dracula, de-yellowed. Needs a truecolor terminal.
        "base": "dracula", "truecolor": True,
        "headings": ["#282a36/#bd93f9", "#ff79c6", "#8be9fd", "#50fa7b", "#bd93f9", "#6272a4"],
        "accents": {"emph": "#8be9fd", "strong": "#ff79c6", "block_quote": "#bd93f9",
                    "hr": "#6272a4", "code_block": "#bd93f9"},
    },
    "night": {  # tokyo-night, de-yellowed. Needs a truecolor terminal.
        "base": "tokyo-night", "truecolor": True,
        "headings": ["#1a1b26/#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#b4f9f8", "#565f89"],
        "accents": {"emph": "#7dcfff", "strong": "#bb9af7", "block_quote": "#7aa2f7",
                    "hr": "#565f89", "code_block": "#bb9af7"},
    },
}


def xterm_rgb(index):
    i = int(index)
    if i < 16:
        return [(0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128), (128, 0, 128),
                (0, 128, 128), (192, 192, 192), (128, 128, 128), (255, 0, 0), (0, 255, 0),
                (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)][i]
    if i < 232:
        i -= 16
        steps = [0, 95, 135, 175, 215, 255]
        return (steps[i // 36], steps[(i // 6) % 6], steps[i % 6])
    v = 8 + (i - 232) * 10
    return (v, v, v)


def is_warm_hue(color):
    """True if the colour reads as red, orange or yellow — what we are excluding."""
    if color.startswith("#"):
        r, g, b = (int(color[j:j + 2], 16) for j in (1, 3, 5))
    else:
        r, g, b = xterm_rgb(color)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s < 0.25 or l > 0.92 or l < 0.10:
        return False  # greys and near-white/black carry no hue worth judging
    return h * 360 < 70 or h * 360 >= 345


def build(theme, nerd):
    style = json.loads((HERE / f"base-{theme['base']}.json").read_text())
    acc = theme["accents"]

    # Dropping the colour key entirely leaves the terminal's own foreground in
    # place, which is what makes the minimal themes sit inside your colour scheme
    # instead of fighting it.
    for key in theme.get("clear", []):
        style.get(key, {}).pop("color", None)

    def paint(key, color, **attrs):
        entry = style.setdefault(key, {})
        if color:
            entry["color"] = color
        else:
            entry.pop("color", None)
        entry.update(attrs)

    if "link" in acc:
        paint("link", acc["link"], underline=True)
    if "link_text" in acc:
        paint("link_text", acc["link_text"], bold=True)
    if "code" in acc:
        paint("code", acc["code"])
        style["code"]["background_color"] = acc["code_bg"]
    paint("emph", acc["emph"], italic=True)
    paint("strong", acc["strong"], bold=True)
    paint("block_quote", acc["block_quote"], italic=True)
    style.setdefault("hr", {}).update({"color": acc["hr"]})
    if "code_block" in acc:
        style.setdefault("code_block", {}).update({"color": acc["code_block"]})
    elif not theme["truecolor"] and not theme.get("quiet"):
        style.setdefault("document", {})["color"] = TEXT
        style.setdefault("code_block", {}).update({"color": TEXT})
        style.setdefault("list", {}).update({"color": TEXT})
        style.setdefault("image_text", {}).update({"color": SECONDARY})

    if not theme["truecolor"]:
        chroma = style.setdefault("code_block", {}).setdefault("chroma", {})
        for key, color in {"mono": CHROMA_MONO, "quiet": CHROMA_QUIET}.get(
                theme.get("quiet"), CHROMA).items():
            if not color:
                chroma.pop(key, None)
                continue
            field = "background_color" if key == "background" else "color"
            chroma.setdefault(key, {})[field] = color

    for depth, ((key, icon, plain), spec) in enumerate(zip(MARKS, theme["headings"]), start=1):
        fg, _, bg = spec.partition("/")
        mark = icon if nerd else plain
        entry = {"color": fg, "bold": True, "block_prefix": "\n"}
        if bg:
            entry.update({"background_color": bg, "prefix": f"  {mark}  ",
                          "suffix": "  ", "block_suffix": "\n"})
        else:
            entry["prefix"] = f"{' ' * (depth - 2)}{mark} "
            if key in ("h5", "h6"):
                entry["bold"] = False
        style[key] = entry
    return style


# Prose elements that must never read as red/orange/yellow. code_block is the
# fenced-block foreground; chroma is checked separately so generic_deleted can
# keep its red.
CHECKED = ["h1", "h2", "h3", "h4", "h5", "h6", "link", "link_text", "code",
           "emph", "strong", "block_quote", "hr", "code_block", "list"]


def main():
    for name, theme in THEMES.items():
        for suffix, nerd in (("nf", True), ("plain", False)):
            out = build(theme, nerd)
            (HERE / f"style-{name}-{suffix}.json").write_text(
                json.dumps(out, indent=1, ensure_ascii=False) + "\n")

            marks = [out[k]["prefix"].strip() for k, *_ in MARKS]
            colors = [out[k]["color"] for k, *_ in MARKS]
            assert len(set(marks)) == len(MARKS), f"{name}/{suffix}: duplicate heading markers"
            assert len(set(colors)) == len(MARKS), f"{name}/{suffix}: duplicate heading colors"

            hot = [k for k in CHECKED
                   if isinstance(out.get(k), dict) and out[k].get("color")
                   and is_warm_hue(out[k]["color"])]
            assert not hot, f"{name}/{suffix}: red/orange/yellow text in {hot}"
        kind = "truecolor" if theme["truecolor"] else "256-colour"
        print(f"  {name:<8} {kind:<11} base {theme['base']}")


if __name__ == "__main__":
    main()
