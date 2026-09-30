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
#   mdview  mdview/      -> ~/mdview, plus a source line in ~/.bashrc and
#                          ~/.zshrc
#   cargo   cargo/       -> ~/.cargo/bin/cargo-gated, [net] offline=true in
#                          ~/.cargo/config.toml, cargo-deny pinned (needs cargo)
#   claude  claude/hooks -> ~/.claude/hooks/dependency-gate.sh, plus its
#                          PreToolUse entry merged into ~/.claude/settings.json
#
# Idempotent: safe to re-run. Overwrites existing symlinks; backs up
# existing real files (or directories) before replacing them. Works
# whether you cd into the repo or call it by absolute path.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS=(tmux vim nvim mdview cargo claude)
CARGO_DENY_VERSION=0.20.2

usage() {
  cat <<USAGE
Usage: $(basename "$0") [COMPONENT...]

Install every component (default), or only the ones named.

Components:
  tmux    .tmux.conf   -> ~/.tmux.conf
  vim     vim/vimrc    -> ~/.vimrc
  nvim    nvim/        -> ~/.config/nvim
  mdview  mdview/      -> ~/mdview, plus a source line in ~/.bashrc and
                          ~/.zshrc
  cargo   cargo/       -> ~/.cargo/bin/cargo-gated, global [net] offline=true,
                          cargo-deny pinned; skipped if cargo is absent
  claude  claude/hooks -> ~/.claude/hooks/dependency-gate.sh, plus its
                          PreToolUse entry merged into ~/.claude/settings.json

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

  # Source the `md` markdown-viewer function from both shells' rc files, once
  # each: macOS defaults to zsh, most Linux to bash, and md.sh works in either.
  local rc_line='[ -f ~/mdview/md.sh ] && . ~/mdview/md.sh'
  local rc
  for rc in .bashrc .zshrc; do
    if [[ -f "$HOME/$rc" ]] && grep -qxF "$rc_line" "$HOME/$rc"; then
      echo "  rc:     ~/$rc already sources mdview"
    else
      printf '\n%s\n' "$rc_line" >> "$HOME/$rc"
      echo "  rc:     appended mdview source line to ~/$rc"
    fi
  done

  # glow is not installed here: package managers differ per machine, and new
  # third-party code is the maintainer's call. Say what's missing and how.
  if ! command -v glow >/dev/null 2>&1; then
    echo "  note:   glow not on PATH; md falls back to bat, less or cat (no themes)"
    if command -v brew >/dev/null 2>&1; then
      echo "          install it with: brew install glow"
    else
      echo "          install it from: https://github.com/charmbracelet/glow#installation"
    fi
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

install_claude() {
  # Guardrails for Claude Code sessions (claude/README.md): a PreToolUse hook
  # that refuses dependency installs until the human creates its one-shot
  # token. Needs jq (the hook parses its stdin with it).
  if ! command -v jq >/dev/null 2>&1; then
    echo "  skip:   jq not on PATH (the claude hook needs it)"
    return 0
  fi

  link "$DOTFILES_DIR/claude/hooks/dependency-gate.sh" "$HOME/.claude/hooks/dependency-gate.sh"

  # The settings entry is MERGED into ~/.claude/settings.json, never replacing
  # what is there; idempotent.
  local cfg="$HOME/.claude/settings.json"
  mkdir -p "$(dirname "$cfg")"
  [[ -f "$cfg" ]] || echo '{}' > "$cfg"
  if jq -e '.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]? | select(.command | test("dependency-gate"))' "$cfg" >/dev/null 2>&1; then
    echo "  hook:   $cfg already wires dependency-gate"
  else
    local tmp
    tmp=$(mktemp)
    jq '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"Bash","hooks":[{"type":"command","command":"$HOME/.claude/hooks/dependency-gate.sh","timeout":10,"statusMessage":"dependency-gate"}]}])' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    echo "  hook:   added the dependency-gate PreToolUse entry to $cfg"
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
