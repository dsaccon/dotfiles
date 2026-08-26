#!/usr/bin/env bash
# install.sh — symlink dotfiles into $HOME.
#
# Usage: install.sh [COMPONENT...]
#
# With no arguments, installs every component. Pass one or more component
# names to install only those:
#
#   tmux    .tmux.conf   -> ~/.tmux.conf
#   vim     vim/vimrc    -> ~/.vimrc
#   nvim    nvim/        -> ~/.config/nvim
#   mdview  mdview/      -> ~/mdview, plus a source line in ~/.bashrc
#
# Idempotent: safe to re-run. Overwrites existing symlinks; backs up
# existing real files (or directories) before replacing them. Works
# whether you cd into the repo or call it by absolute path.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS=(tmux vim nvim mdview)

usage() {
  cat <<USAGE
Usage: $(basename "$0") [COMPONENT...]

Install every component (default), or only the ones named.

Components:
  tmux    .tmux.conf   -> ~/.tmux.conf
  vim     vim/vimrc    -> ~/.vimrc
  nvim    nvim/        -> ~/.config/nvim
  mdview  mdview/      -> ~/mdview, plus a source line in ~/.bashrc

Examples:
  $(basename "$0")               # install everything
  $(basename "$0") mdview        # just mdview
  $(basename "$0") tmux nvim     # tmux and nvim
USAGE
}

# Replace dst with a symlink to src. If dst already exists and isn't a
# symlink, move it aside first so nothing is silently lost.
link() {
  local src="$1"
  local dst="$2"

  if [[ -L "$dst" ]]; then
    # Stale symlink (or pointing somewhere stale) — just replace it.
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local backup
    backup="${dst}.bak.$(date +%s)"
    echo "  backup: $dst -> $backup"
    mv "$dst" "$backup"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "  link:   $dst -> $src"
}

install_tmux() {
  link "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
}

install_vim() {
  link "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"
}

install_nvim() {
  link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
}

install_mdview() {
  # Not hidden on purpose: the snap build of glow cannot read dot-directories.
  link "$DOTFILES_DIR/mdview" "$HOME/mdview"

  # Source the `md` markdown-viewer function from ~/.bashrc, once.
  local rc_line='[ -f ~/mdview/md.sh ] && . ~/mdview/md.sh'
  if [[ -f "$HOME/.bashrc" ]] && grep -qxF "$rc_line" "$HOME/.bashrc"; then
    echo "  rc:     ~/.bashrc already sources mdview"
  else
    printf '\n%s\n' "$rc_line" >> "$HOME/.bashrc"
    echo "  rc:     appended mdview source line to ~/.bashrc"
  fi
}

is_component() {
  local c
  for c in "${COMPONENTS[@]}"; do
    [[ "$c" == "$1" ]] && return 0
  done
  return 1
}

# --- argument parsing --------------------------------------------------

selected=()
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    all)
      selected=("${COMPONENTS[@]}")
      ;;
    *)
      if is_component "$arg"; then
        selected+=("$arg")
      else
        echo "error: unknown component '$arg'" >&2
        echo >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ ${#selected[@]} -eq 0 ]]; then
  selected=("${COMPONENTS[@]}")
fi

# --- run ----------------------------------------------------------------

echo "Installing dotfiles from $DOTFILES_DIR"

for c in "${selected[@]}"; do
  echo "[$c]"
  "install_$c"
done

echo "done"
