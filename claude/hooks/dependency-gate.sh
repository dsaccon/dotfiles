#!/usr/bin/env bash
# dependency-gate — a Claude Code PreToolUse hook on the Bash tool.
#
# Any command that would install, fetch, or run new third-party code is REFUSED
# unless the human has created the one-shot token, and the model is told to ask.
# Installed by dotfiles/install.sh (claude component) as ~/.claude/hooks/dependency-gate.sh
# and wired in ~/.claude/settings.json under hooks.PreToolUse (matcher "Bash").
#
# Why: on 2026-09-09 a coding-agent session built a one-day-old crate in a
# scratchpad with the cargo offline escape hatch, executing its build script on
# this machine — the exact exposure the 8-day dependency cooldown exists to
# prevent. The cooldown lives in cargo config and scripts; this hook is the
# guardrail in front of the agent itself, for every package manager, not only cargo.
#
# How the human approves: run, in their OWN shell (not through the agent):
#     touch ~/.claude/dependency-gate.allow
# That permits exactly ONE matching command within 15 minutes; the token is
# consumed on use. Every decision is appended to ~/.claude/dependency-gate.log.
#
# Honest limit: textual matching is not a security boundary — a command can be
# spelled past any regex. This is the guardrail on the agent's ordinary paths;
# the cargo offline config and the age gate stand underneath it, and the human's
# review of the log is what closes the rest.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || cmd=""
[ -z "$cmd" ] && exit 0

# One alternation, one line per family. `\b`-anchored on the program name so
# `sudo apt install` matches and `apt-cache` does not.
patterns=(
  # Rust: every path that adds, fetches, or publishes a crate, and the offline escape hatch.
  '\bcargo[[:space:]]+(add|install|update|fetch|vendor|publish|gated)\b'
  '\bcargo-gated[[:space:]]+(add|update|fetch)\b|deps-update\.sh[[:space:]]+(add|update|fetch)\b|CARGO_NET_OFFLINE=(false|0)\b|--config[[:space:]]+[^ ]*net\.offline'
  '\brustup[[:space:]]+(toolchain|component|target)[[:space:]]+(add|install|link)\b|\brustup[[:space:]]+(update|install|default|self|set|override)\b'
  # Python
  '\bpip3?[[:space:]]+(install|download)\b|python3?[[:space:]]+-m[[:space:]]+pip[[:space:]]+(install|download)\b'
  '\buv[[:space:]]+(add|pip|sync|tool|lock|venv)\b|\buvx\b|\bpipx[[:space:]]+(install|run|upgrade)\b'
  '\bpoetry[[:space:]]+(add|install|update)\b|\bconda[[:space:]]+(install|create|update)\b|\bmamba[[:space:]]+(install|create)\b'
  # JavaScript
  '\bnpm[[:space:]]+(install|i|ci|add|update|exec|link)\b|\bnpx\b'
  '\bpnpm[[:space:]]+(add|install|i|dlx|update)\b|\byarn[[:space:]]+(add|install|dlx|up|upgrade)\b'
  '\bbun[[:space:]]+(add|install|x|update)\b|\bbunx\b|\bdeno[[:space:]]+(add|install)\b'
  # System packages and images
  '\bapt(-get)?[[:space:]]+(install|upgrade|dist-upgrade|full-upgrade)\b|\bdpkg[[:space:]]+-i\b|\bsnap[[:space:]]+install\b'
  '\bbrew[[:space:]]+(install|upgrade|reinstall)\b|\bflatpak[[:space:]]+install\b|\bnix(-env)?[[:space:]]+(install|-i|profile[[:space:]]+install)\b'
  '\bdocker[[:space:]]+(pull|build)\b|\bpodman[[:space:]]+(pull|build)\b'
  # Other language ecosystems
  '\bgem[[:space:]]+install\b|\bgo[[:space:]]+(get|install)\b|\bcabal[[:space:]]+install\b|\bstack[[:space:]]+install\b'
  '\bcomposer[[:space:]]+(install|require|update)\b|\bcpan[[:space:]]+install\b|\bmix[[:space:]]+deps\.get\b'
  # Pipe-to-shell installers
  '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh\b|(ba)?sh[[:space:]]+<\((curl|wget)\b'
)
re=$(IFS='|'; printf '%s' "${patterns[*]}")

if ! printf '%s' "$cmd" | grep -Eq -- "$re"; then
  exit 0
fi

token="$HOME/.claude/dependency-gate.allow"
log="$HOME/.claude/dependency-gate.log"
head=$(printf '%s' "$cmd" | tr '\n' ' ' | cut -c1-200)
stamp=$(date -u +%FT%TZ)

if [ -f "$token" ] && [ -n "$(find "$token" -mmin -15 2>/dev/null)" ]; then
  rm -f "$token"
  printf '%s ALLOWED (token consumed) %s\n' "$stamp" "$head" >> "$log"
  exit 0
fi
if [ -f "$token" ]; then
  rm -f "$token"
  printf '%s STALE TOKEN removed (older than 15 minutes) %s\n' "$stamp" "$head" >> "$log"
fi

printf '%s DENIED %s\n' "$stamp" "$head" >> "$log"
reason="dependency-gate: this command would install, fetch or run new third-party code, and the maintainer must approve it first. Stop and ask them, showing the exact command. If they agree, THEY run \`touch ~/.claude/dependency-gate.allow\` in their own shell; that permits exactly one such command within 15 minutes. Do not rephrase the command to slip past this gate, and never run it any other way."
jq -n --arg reason "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
exit 0
