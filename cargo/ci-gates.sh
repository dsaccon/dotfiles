#!/usr/bin/env bash
# The dependency gates, for CI. Vendored into a repo by `cargo gated init`
# (dotfiles/cargo) because CI runners have no dotfiles. Run this BEFORE any
# step that compiles: `cargo clippy`/`test`/`build` execute every build
# script in the dependency graph, so a young or advisory-flagged crate must
# be stopped here, not after the runner has already run it.
#
# Order: age gate (lockfile + crates.io only, nothing on disk) -> fetch
# (sources reach disk, nothing executes) -> cargo-deny (advisories, sources,
# bans). Requires: python3, and cargo-deny at the pinned version.
#
# `set -o pipefail` matters: `cargo x | tail` would otherwise report tail's
# status.
set -euo pipefail
cd "$(dirname "$0")/.."

MIN_DEP_AGE_DAYS="${MIN_DEP_AGE_DAYS:-8}"
CARGO_DENY_VERSION="${CARGO_DENY_VERSION:-0.20.2}"
BASELINE="${MIN_DEP_AGE_BASELINE:-min-dep-age-baseline.txt}"

step() { printf '\n==> %s\n' "$*"; }

step "minimum dependency age: ${MIN_DEP_AGE_DAYS} days (scripts/min-dep-age.py)"
baseline_args=()
[ -f "$BASELINE" ] && baseline_args=(--baseline "$BASELINE")
python3 scripts/min-dep-age.py --lockfile Cargo.lock --min-days "$MIN_DEP_AGE_DAYS" "${baseline_args[@]}"

step "cargo fetch --locked"
CARGO_NET_OFFLINE=false cargo fetch --locked

step "cargo deny check advisories sources bans (deny.toml)"
# Exact version, not merely "installed": an unpinned `cargo install cargo-deny`
# fetches whatever is latest at run time — no pin, no age gate, hundreds of
# build scripts executed on a moving target. Bump only by hand, to a release
# >= MIN_DEP_AGE_DAYS old.
installed=$(cargo deny --version 2>/dev/null || true)
if ! printf '%s' "$installed" | grep -q " ${CARGO_DENY_VERSION}\$"; then
  echo "cargo-deny ${CARGO_DENY_VERSION} is required (found: ${installed:-not installed}). Install with: CARGO_NET_OFFLINE=false cargo install cargo-deny --version ${CARGO_DENY_VERSION} --locked" >&2
  exit 1
fi
cargo deny --locked check advisories sources bans
