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
#   cargo   cargo/       -> ~/.cargo/bin/cargo-gated, [net] offline=true in
#                          ~/.cargo/config.toml, cargo-deny pinned (needs cargo)
#
# Idempotent: safe to re-run. Overwrites existing symlinks; backs up
# existing real files (or directories) before replacing them. Works
# whether you cd into the repo or call it by absolute path.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS=(tmux vim nvim mdview cargo)
CARGO_DENY_VERSION=0.20.2

usage() {
  cat <<USAGE
Usage: $(basename "$0") [COMPONENT...]

Install every component (default), or only the ones named.

Components:
  tmux    .tmux.conf   -> ~/.tmux.conf
  vim     vim/vimrc    -> ~/.vimrc
  nvim    nvim/        -> ~/.config/nvim
  mdview  mdview/      -> ~/mdview, plus a source line in ~/.bashrc
  cargo   cargo/       -> ~/.cargo/bin/cargo-gated, global [net] offline=true,
                          cargo-deny pinned; skipped if cargo is absent

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

install_cargo() {
  # Dependency cooldown for every Rust project on this machine (cargo/README.md).
  # Rust is not on every machine: skip, loudly, rather than fail `all`.
  if ! command -v cargo >/dev/null 2>&1; then
    echo "  skip:   cargo not on PATH (not a Rust machine)"
    return 0
  fi

  link "$DOTFILES_DIR/cargo/cargo-gated" "$HOME/.cargo/bin/cargo-gated"

  # Global offline-by-default. Merged, not linked: ~/.cargo/config.toml may
  # hold other settings (registries, aliases) that must survive.
  local cfg="$HOME/.cargo/config.toml"
  if [[ -f "$cfg" ]] && grep -qE '^\s*offline\s*=' "$cfg"; then
    echo "  config: $cfg already sets net.offline"
  elif [[ -f "$cfg" ]] && grep -qxF '[net]' "$cfg"; then
    sed -i '/^\[net\]$/a offline = true' "$cfg"
    echo "  config: added offline = true under existing [net] in $cfg"
  else
    mkdir -p "$(dirname "$cfg")"
    [[ -f "$cfg" ]] && printf '\n' >> "$cfg"
    cat "$DOTFILES_DIR/cargo/config.toml" >> "$cfg"
    echo "  config: appended [net] offline = true to $cfg"
  fi

  # cargo-deny at an exact, aged version — never "latest" (that is an
  # unpinned, ungated install of hundreds of build scripts).
  if cargo deny --version 2>/dev/null | grep -q " ${CARGO_DENY_VERSION}\$"; then
    echo "  deny:   cargo-deny ${CARGO_DENY_VERSION} already installed"
  else
    echo "  deny:   installing cargo-deny ${CARGO_DENY_VERSION} (network)"
    CARGO_NET_OFFLINE=false cargo install cargo-deny --version "${CARGO_DENY_VERSION}" --locked
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
