# md — terminal markdown viewer (glow front-end).
#
# Install: handled by ../install.sh, which links this dir to ~/mdview and
# appends the source line below to ~/.bashrc:
#   [ -f ~/mdview/md.sh ] && . ~/mdview/md.sh
#
# Commands:
#   md FILE.md ...   render
#   mdtheme          preview every theme, then say how to pick one
#   mdtheme NAME     switch to that theme, persistently
#
# Env (rarely needed):
#   MD_NF=0        plain markers, if Nerd Font icons show as boxes
#   MD_THEME=name  use a theme for one command without saving it
#   MD_STYLE=path  bypass themes; a style JSON or builtin (dark/light/notty)
#   MD_MAX=N       clamp width to at most N columns
#   MDVIEW_DIR     override install location (default: ~/mdview)

# 256-colour first, then the two that need truecolor.
MD_THEMES="minimal mono bright rose orchid berry mint ocean slate warm night"

_md_dir() { printf '%s' "${MDVIEW_DIR:-$HOME/mdview}"; }

# The saved theme lives outside the dotfiles repo so switching does not dirty it.
# A dot-path is fine here: only *glow* is blocked from those (see README), and
# this file is read by the shell.
_md_state() { printf '%s/mdview/theme' "${XDG_STATE_HOME:-$HOME/.local/state}"; }

# glow 2.1.1 never auto-detects terminal width — it renders 80 columns at every
# terminal size. So the width is always computed here and passed explicitly.
_md_cols() {
  local c=
  # Braces + 2>/dev/null so the *shell's* redirect error is swallowed too when
  # there is no controlling terminal, not just stty's own stderr.
  c=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
  [ -n "$c" ] && [ "$c" -gt 0 ] 2>/dev/null || c=$(tput cols 2>/dev/null)
  [ -n "$c" ] && [ "$c" -gt 0 ] 2>/dev/null || c=${COLUMNS:-80}
  [ -n "$MD_MAX" ] && [ "$c" -gt "$MD_MAX" ] 2>/dev/null && c=$MD_MAX
  printf '%s' "$c"
}

# Precedence: one-off env var, then the saved theme, then the default.
_md_theme() {
  local s
  [ -n "$MD_THEME" ] && { printf '%s' "$MD_THEME"; return; }
  s=$(_md_state)
  [ -r "$s" ] && { read -r t <"$s"; [ -n "$t" ] && { printf '%s' "$t"; return; }; }
  printf 'minimal'
}

_md_style() {
  local d f t v
  d=$(_md_dir)
  [ -n "$MD_STYLE" ] && { printf '%s' "$MD_STYLE"; return; }
  t=$(_md_theme)
  [ "${MD_NF:-1}" = 0 ] && v=plain || v=nf
  for f in "$d/style-$t-$v.json" "$d/style-$t-plain.json" "$d/style-bright-$v.json"; do
    [ -r "$f" ] && { printf '%s' "$f"; return; }
  done
  printf 'dark'
}

# The snap build of glow cannot read any path containing a dot-directory: snap's
# `home` interface excludes them. Non-snap installs are unaffected, so this is a
# no-op there. Snap also has a private /tmp, hence the scratch dir under ~/mdview.
_md_snap() { case "$(command -v glow 2>/dev/null)" in */snap/*) return 0;; esac; return 1; }
_md_hidden_path() { case "/$1/" in *"/."*) return 0;; esac; return 1; }

_md_have_glow() { command -v glow >/dev/null 2>&1; }

_md_fallback() {
  if command -v bat >/dev/null 2>&1; then bat --style=plain -l md "$@"; return; fi
  if command -v less >/dev/null 2>&1; then less -R "$@"; return; fi
  cat "$@"
}

# glow picks its colour depth from whether stdout is a terminal. Piped, it falls
# back to 16 colours and every 256-colour theme collapses into three or four
# shades. So: when we need the output in a pipe, run glow under a pty via
# `script`, which preserves the full palette. Verified: TTY 2422 256-colour
# codes / 0 basic; piped without this, 29 / 2393.
_md_resolve() {
  local f real
  real=$(cd "$(dirname -- "$1")" 2>/dev/null && printf '%s/%s' "$PWD" "$(basename -- "$1")")
  [ -z "$real" ] && real=$1
  if _md_snap && _md_hidden_path "$real"; then
    mkdir -p "$(_md_dir)/tmp" || return 1
    cp -- "$real" "$(_md_dir)/tmp/$(basename -- "$real")" || return 1
    real=$(_md_dir)/tmp/$(basename -- "$real")
  fi
  printf '%s' "$real"
}

# Render to stdout, keeping full colour even though stdout is a pipe.
_md_render() {
  local real rc=0
  real=$(_md_resolve "$1") || return 1
  if command -v script >/dev/null 2>&1; then
    script -qec "glow -s '$(_md_style)' -w $(_md_cols) -- '$real'" /dev/null </dev/null || rc=$?
  else
    CLICOLOR_FORCE=1 glow -s "$(_md_style)" -w "$(_md_cols)" -- "$real" </dev/null || rc=$?
  fi
  case "$real" in "$(_md_dir)/tmp/"*) rm -f -- "$real";; esac
  return $rc
}

md() {
  [ $# -eq 0 ] && { echo "usage: md FILE.md [...]" >&2; return 2; }
  _md_have_glow || { _md_fallback "$@"; return; }
  local f real rc=0
  for f in "$@"; do
    if [ -t 1 ]; then
      # Let glow own the terminal: it detects a TTY and emits the full palette,
      # and its own pager keeps that intact.
      real=$(_md_resolve "$f") || { rc=1; continue; }
      glow -s "$(_md_style)" -w "$(_md_cols)" -p -- "$real" || rc=$?
      case "$real" in "$(_md_dir)/tmp/"*) rm -f -- "$real";; esac
    else
      _md_render "$f" || rc=$?
    fi
  done
  return $rc
}

# `mdtheme` with no argument previews every theme in one pager; with a name, it
# switches. One command, because two whose names differed by one letter was a
# trap.
mdtheme() {
  local d s t f cur
  d=$(_md_dir); s=$(_md_state); cur=$(_md_theme)

  if [ $# -gt 0 ]; then
    for t in $MD_THEMES; do
      if [ "$t" = "$1" ]; then
        mkdir -p "$(dirname "$s")" && printf '%s\n' "$1" >"$s" || return 1
        printf 'theme: %s\n' "$1"
        [ -n "$MD_THEME" ] && printf 'note: MD_THEME=%s is set and overrides it\n' "$MD_THEME"
        return 0
      fi
    done
    printf 'unknown theme: %s\navailable: %s\n' "$1" "$MD_THEMES" >&2
    return 2
  fi

  f=$d/sample.md
  _md_have_glow || { _md_fallback "$f"; return; }
  {
    for t in $MD_THEMES; do
      printf '\n\033[1;7m  theme: %s  \033[0m\n' "$t"
      MD_THEME=$t _md_render "$f"
    done
    printf '\n\033[1m  current theme: %s\033[0m\n' "$cur"
    printf '  switch with:   mdtheme NAME   (%s)\n\n' "$MD_THEMES"
  } | { [ -t 1 ] && less -R || cat; }
}
