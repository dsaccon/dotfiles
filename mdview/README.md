# mdview — readable markdown in a terminal

An `md` shell function wrapping [glow](https://github.com/charmbracelet/glow), tuned for
reading `.md` files over SSH inside tmux — equally usable in a thin vertical split and a
full-width window.

There are two commands.

```sh
md README.md    # render a file
mdtheme         # preview all three themes, then tells you how to pick one
mdtheme warm    # switch to that theme, persistently
```

That is the whole interface. The environment variables below exist for edge cases and
can be ignored:

```sh
MD_NF=0 md doc.md         # plain markers, if Nerd Font icons render as boxes
MD_THEME=warm md doc.md   # use a theme once without saving it
MD_MAX=120 md doc.md      # clamp width on very wide screens
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

Every theme here gives all six levels a distinct glyph *and* a distinct colour, with
progressive indent, generated from the upstream base so the schema is theirs rather than
hand-recalled.

Every icon is from the **Font Awesome block (U+F02D–U+F111)**, which is present in Nerd
Font v1, v2 and v3 alike. The Material Design block was avoided on purpose — its
codepoints moved in Nerd Font v3, so those glyphs break against older fonts.

## Themes

`mdtheme` with no argument renders the sample under every theme into one pager, so they
can be compared by scrolling; it ends with the active theme and how to change it.
`mdtheme NAME` switches, and the choice persists.

| Theme | Character | Colour |
| --- | --- | --- |
| `minimal` (default) | body text stays your terminal's own; one soft blue accent | 256 |
| `mono` | no hue anywhere — weight, dim and indent do all the work | 256 |
| `bright` | balanced, cool-leaning | 256 |
| `rose` | warm, pink-forward — the warmest available without red | 256 |
| `orchid` | violet and lavender | 256 |
| `berry` | deep pink into purple, highest contrast of the warm set | 256 |
| `mint` | green and teal | 256 |
| `ocean` | blues and cyans | 256 |
| `slate` | near-monochrome, one blue accent | 256 |
| `warm` | dracula, de-yellowed | truecolor |
| `night` | tokyo-night, de-yellowed | truecolor |

`minimal` and `mono` deliberately **drop** the `color` key on `document`, `text`, `list`
and `code_block` rather than setting it to a grey. An absent colour leaves the terminal's
own foreground in place, so the render sits inside your colour scheme instead of fighting
it. That is what makes them look native. Measured on the sample: `minimal` paints 68
coloured spans, `mono` 67 and fully greyscale, against 2422 for the others.

The saved theme lives in `$XDG_STATE_HOME/mdview/theme` (default
`~/.local/state/mdview/theme`) — deliberately outside the dotfiles repo, so switching never
shows up as a repo change. `MD_THEME` overrides it for one command without saving.

A dot-path is fine for that state file: the snap restriction below applies only to what
*glow* can open, and this one is read by the shell.

### No red, orange or yellow text

None of the themes use those hues for text, and `gen-styles.py` asserts it rather than
trusting care — every checked element is converted to HLS and rejected if its hue falls in
the red/orange/yellow band. The one deliberate exception is chroma's `generic_deleted`,
where red is the meaning rather than decoration.

This also required replacing upstream's syntax-highlighting palette inside fenced code
blocks, which is where most of the yellow was: strings, punctuation, decorators and
preprocessor comments are all remapped in the `CHROMA` table.

The `bright` overlay exists because upstream `dark.json` is flatter than it looks. Beyond
the headings, it leaves `emph`, `strong` and `block_quote` with **no colour at all** —
italic and bold only — and puts links (`30`), rules (`240`), code blocks (`244`) and
chroma comments (`#676767`) in one dim grey-teal band.

### Truecolor is required for `warm` and `night`

Both use hex. Without RGB passthrough, tmux down-converts them to approximate 256-colour
and they look muddier than intended. Check with:

```sh
printf '\033[38;2;255;100;0mtruecolor\033[0m\n'   # orange = yes, muddy/plain = no
```

To enable it (tmux >= 3.2), in `../.tmux.conf`:

```tmux
set  -g default-terminal "tmux-256color"
set -as terminal-features ",*:RGB"
```

The terminal emulator you SSH *from* must support it too — colour is resolved client-side.

## Colour depth: glow needs a terminal

glow chooses its colour depth from whether stdout is a terminal. Piped, it degrades to
16 colours and every 256-colour theme collapses into three or four shades — which looks
like "grey text plus two colours" and makes all the themes indistinguishable.

Measured on the same file and style:

| stdout | 256-colour codes | basic 16-colour |
| --- | --- | --- |
| a terminal | 2422 | 0 |
| a pipe | 29 | 2393 |

So `md` hands the terminal straight to glow and lets glow page. Where output genuinely
has to go through a pipe — the multi-theme preview — glow runs under a pty via `script`,
which preserves the full palette; without `script` on `PATH` it falls back to
`CLICOLOR_FORCE=1` and the degraded 16 colours.

The lesson worth keeping: checking a style file's **exit code** proves nothing about
whether its colours survived. Compare rendered output instead.

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

Edit the `THEMES` or `MARKS` tables in `gen-styles.py` and re-run it. It reads the
`base-*.json` files and writes all six style files, asserting that every theme keeps six
distinct heading markers and six distinct colours.

Heading glyphs are written as `\uXXXX` escapes rather than literal characters, on purpose:
private-use-area glyphs get silently stripped by some editors and transports, and a
stripped glyph is exactly what the distinctness assertion is there to catch.

## Upstream material

`base-dark.json`, `base-dracula.json` and `base-tokyo-night.json` are copied verbatim from
[charmbracelet/glamour](https://github.com/charmbracelet/glamour) (`styles/`) and are not
edited here — every theme is built on top of them by `gen-styles.py`, which is what keeps
the schema upstream's rather than hand-written.

glamour is MIT licensed; its licence is included as `LICENSE-glamour`.
