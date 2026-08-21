# mdview — readable markdown in a terminal

An `md` shell function wrapping [glow](https://github.com/charmbracelet/glow), tuned for
reading `.md` files over SSH inside tmux — equally usable in a thin vertical split and a
full-width window.

```sh
md README.md          # render
MD_NF=0 md README.md  # plain markers instead of Nerd Font icons
MD_MAX=120 md doc.md  # clamp width on very wide screens
```

## Install

Handled by `../install.sh`: links this directory to `~/mdview` and appends the source
line to `~/.bashrc`. Both steps are idempotent.

`~/mdview` is **deliberately not a hidden directory** — see the snap note below.

## What it fixes

Two complaints with stock `glow`, each traced to a root cause before being fixed.

### 1. Text wrapped far short of the window width

**Cause: `glow` 2.1.1 does not auto-detect terminal width at all.** Measured in a pty at
80 / 100 / 140 / 160 / 200 / 240 columns — it rendered 78 columns every time. Deleting
`width: 80` from its config did not change this, so it is a hard default, not a config
artifact.

A widely repeated claim is that glow's width is *capped at 120 columns*. **That is false
for an explicit `-w`,** and it was the wrong hypothesis that sent an earlier attempt at
this down a dead end. Measured, ANSI escapes stripped:

| `-w` | longest real rendered line |
| --- | --- |
| 60 | 58 |
| 80 | 78 |
| 140 | 137 |
| 200 | 196 |
| 300 | 298 |
| 0 | 1363 (wrapping disabled; the terminal then breaks mid-word) |

Linear, uncapped, and it behaves identically under `-p`. So `md` computes the width
itself — `stty size </dev/tty`, falling back to `tput cols`, then `$COLUMNS`, then 80 —
and always passes `-w` explicitly. Verified end-to-end from 40 to 240 columns with no
overflow.

Note that `-w 120` can still produce a line shorter than 118 depending on where words
happen to break. Only the 200 and 300 rows above distinguish a cap from word-boundary
luck.

### 2. All heading levels looked identical

**Cause: they genuinely are.** From glamour's own `dark.json` (kept here as
`base-dark.json`, unmodified):

```json
"h1": { "prefix": " ", "color": "228", "background_color": "63", "bold": true },
"h2": { "prefix": "## " },
"h3": { "prefix": "### " },
"h4": { "prefix": "#### " },
"h5": { "prefix": "##### " },
"h6": { "prefix": "###### ", "color": "35" }
```

`h2`–`h5` carry a prefix and nothing else — no colour, no weight. They are plain body
text with hashes in front.

`style-nf.json` and `style-plain.json` give all six levels a distinct glyph *and* a
distinct colour, with progressive indent. They are generated from `base-dark.json` so the
schema is upstream's rather than hand-recalled.

Every icon is from the **Font Awesome block (U+F02D–U+F111)**, which is present in Nerd
Font v1, v2 and v3 alike. The Material Design block was avoided on purpose — its
codepoints moved in Nerd Font v3, so those glyphs break against older fonts.

## The snap trap

If `glow` is installed as a **snap**, snap's `home` interface denies access to any path
containing a **dot-directory**. Consequences, all confirmed:

- `glow ~/.config/foo.md` → `permission denied`. This is *not* a file-ownership problem;
  `~/.config` is user-owned and writable. glow simply cannot see it.
- A custom style at `~/.config/glow/mystyle.json` can therefore never be loaded — which
  is why `~/mdview` is not `~/.mdview`.
- The snap's real config lives at `~/snap/glow/current/.config/glow/glow.yml`, not
  `~/.config/glow/`.
- Snap also gets a **private `/tmp`**, so a host `/tmp` scratch file is invisible to it.

`md` detects a snap install (`command -v glow` resolving under `/snap/`) and copies
dot-path files to a non-hidden scratch dir before rendering, deleting the copy afterwards.
On apt or binary installs the check is a no-op.

## Known limitation: no reflow on resize

Every CLI renderer — glow, mdcat, rich-cli, bat — hard-wraps at render time; the width is
baked into the output. Resizing the tmux pane or zooming with `prefix+z` breaks the layout
until `md` is re-run. Only in-application viewers reflow live:

- **`render-markdown.nvim`** — per-level heading icons and native `wrap`, so it reflows on
  pane resize. Costs a plugin install and treesitter parsers on every machine.
- **frogmouth** — Textual TUI with a TOC sidebar, reflows on resize. Python install.

Rejected here in favour of glow's single portable binary and zero per-machine setup. If
pane resizing becomes frequent, that trade is the thing to revisit.

Also unfixable in any renderer: wide tables and code blocks cannot be word-wrapped without
destroying them. They will overflow a narrow pane.

## Fallbacks

With no `glow` on `PATH`, `md` falls through to `bat`, then `less -R`, then `cat`.

## Regenerating the styles

Edit the `LEVELS` table in `gen-styles.py` and re-run it. It reads `base-dark.json` and
writes both style files, so upstream's schema stays the source of truth.
