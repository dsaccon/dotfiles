# claude — guardrails for Claude Code sessions on this machine

`hooks/dependency-gate.sh` is a PreToolUse hook on the Bash tool. Any command that would install,
fetch or run new third-party code — the cargo add/install/update/fetch family and `cargo gated`, the
`CARGO_NET_OFFLINE=false` escape hatch, rustup, pip/uv/pipx/poetry/conda, npm/npx/pnpm/yarn/bun,
apt/brew/snap/flatpak/nix, docker pull/build, gem, `go install`, cabal, composer, and any
pipe-to-shell installer — is refused, and the agent is told to ask the human.

**Approving one command:** in your own shell, `touch ~/.claude/dependency-gate.allow`. That permits
exactly one matching command within 15 minutes and is consumed on use. Every decision lands in
`~/.claude/dependency-gate.log`.

**Why:** 2026-09-09, a coding-agent session built a one-day-old crate in a scratchpad through the
offline escape hatch and ran its build script on this machine — the exposure the 8-day cooldown
(`cargo/`) exists to prevent. The cooldown lives in cargo config and scripts; this hook stands in
front of the agent itself, for every package manager.

**Honest limit:** textual matching is not a security boundary. The hook covers the agent's ordinary
paths; the cargo offline config and the age gate stand underneath; the log is what you review.
Prose that merely mentions an install command (a README written through a heredoc) trips it too;
that errs on the safe side.

`install.sh claude` links the hook into `~/.claude/hooks/` and adds the `hooks.PreToolUse` entry to
`~/.claude/settings.json` if it is missing (merged, never replaced). Needs `jq`.
