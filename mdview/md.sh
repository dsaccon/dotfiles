# md — terminal markdown viewer (glow front-end).
#
# Install: handled by ../install.sh, which links this dir to ~/mdview and
# appends the source line below to ~/.bashrc:
#   [ -f ~/mdview/md.sh ] && . ~/mdview/md.sh
#
# Env:
#   MD_NF=0        plain markers instead of Nerd Font icons
#   MD_STYLE=path  override style JSON (or a builtin name: dark, light, notty)
#   MD_MAX=N       clamp width to at most N columns (default: unclamped)
#   MDVIEW_DIR     override install location (default: ~/mdview)

_md_dir() { printf '%s' "${MDVIEW_DIR:-$HOME/mdview}"; }

# glow 2.1.1 never auto-detects terminal width — it renders 80 columns at every
# terminal size. So the width is always computed here and passed explicitly.
_md_cols() {
  local c=
  c=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
  [ -n "$c" ] && [ "$c" -gt 0 ] 2>/dev/null || c=$(tput cols 2>/dev/null)
  [ -n "$c" ] && [ "$c" -gt 0 ] 2>/dev/null || c=${COLUMNS:-80}
  [ -n "$MD_MAX" ] && [ "$c" -gt "$MD_MAX" ] 2>/dev/null && c=$MD_MAX
  printf '%s' "$c"
}

_md_style() {
  local d; d=$(_md_dir)
  if [ -n "$MD_STYLE" ]; then printf '%s' "$MD_STYLE"; return; fi
  if [ "${MD_NF:-1}" != 0 ] && [ -r "$d/style-nf.json" ]; then printf '%s' "$d/style-nf.json"; return; fi
  if [ -r "$d/style-plain.json" ]; then printf '%s' "$d/style-plain.json"; return; fi
  printf 'dark'
}

# The snap build of glow cannot read any path containing a dot-directory: snap's
# `home` interface excludes them. Non-snap installs are unaffected, so this is a
# no-op there. Snap also has a private /tmp, hence the scratch dir under ~/mdview.
_md_snap() { case "$(command -v glow 2>/dev/null)" in */snap/*) return 0;; esac; return 1; }
_md_hidden_path() { case "/$1/" in *"/."*) return 0;; esac; return 1; }

md() {
  [ $# -eq 0 ] && { echo "usage: md FILE.md [...]" >&2; return 2; }
  local cols style f real scratch rc=0
  cols=$(_md_cols); style=$(_md_style)

  if ! command -v glow >/dev/null 2>&1; then
    if command -v bat >/dev/null 2>&1; then bat --style=plain -l md "$@"; return; fi
    if command -v less >/dev/null 2>&1; then less -R "$@"; return; fi
    cat "$@"; return
  fi

  for f in "$@"; do
    real=$(cd "$(dirname -- "$f")" 2>/dev/null && printf '%s/%s' "$PWD" "$(basename -- "$f")")
    [ -z "$real" ] && real=$f
    scratch=
    if _md_snap && _md_hidden_path "$real"; then
      scratch=$(_md_dir)/tmp
      mkdir -p "$scratch" || return 1
      cp -- "$real" "$scratch/$(basename -- "$real")" || return 1
      real=$scratch/$(basename -- "$real")
    fi
    if [ -t 1 ]; then
      glow -s "$style" -w "$cols" -p -- "$real" || rc=$?
    else
      CLICOLOR_FORCE=1 glow -s "$style" -w "$cols" -- "$real" || rc=$?
    fi
    [ -n "$scratch" ] && rm -f -- "$real"
  done
  return $rc
}
