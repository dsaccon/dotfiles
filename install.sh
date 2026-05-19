#!/usr/bin/env bash
# install.sh — symlink dotfiles into $HOME.
#
# Idempotent: safe to re-run. Overwrites existing symlinks; backs up
# existing real files (or directories) before replacing them. Works
# whether you cd into the repo or call it by absolute path.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "Installing dotfiles from $DOTFILES_DIR"

link "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
link "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"
link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

echo "done"
