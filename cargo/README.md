# cargo — dependency cooldown for every Rust project on this machine

Defence against the compromise → publish → harvest pattern (arrayref, 2026-08:
a malicious `build.rs` ran within seconds of `cargo add`, before any check).
Age-gates every new crates.io version (default 8 days), and makes every network
fetch deliberate.

`install.sh cargo` (skips itself if `cargo` is not on PATH):

1. `~/.cargo/config.toml` gets `[net] offline = true` in **every** project.
   Precisely what that does (measured 2026-08-26): bare `cargo add`/`update` can
   still *edit* Cargo.toml/Cargo.lock from the locally cached index, and a
   version whose source is already in `~/.cargo/registry/cache` (fetched
   earlier by any project) still builds. What cannot happen is a **download**:
   a version never fetched on this machine — which is what a freshly published
   malicious release is — cannot reach disk or run its build.rs except through
   `cargo gated`, which age-checks first.
2. `cargo-gated` is linked into `~/.cargo/bin` → `cargo gated <mode>` anywhere.
3. `cargo-deny` installed at the exact pinned version (`CARGO_DENY_VERSION`
   in install.sh).

Daily use, inside any cargo workspace:

    cargo gated add <crate>          # cargo add, age-check, fetch — or restore + abort
    cargo gated update [-p crate]    # same for cargo update
    cargo gated fetch                # after a pull changed Cargo.lock
    cargo gated init                 # adopt in a repo: offline config, deny.toml,
                                     # baseline, and vendor scripts/ci-gates.sh for CI

One-off escape hatch: `CARGO_NET_OFFLINE=false cargo <...>` — ungated, on purpose
visible in the command line, not a flag on the gate. If a bare `cargo add` has
already edited the manifest, `git checkout -- Cargo.lock '**/Cargo.toml'` and redo
it through `cargo gated add`.

CI (runners have no dotfiles): `cargo gated init` vendors `scripts/ci-gates.sh`
and `scripts/min-dep-age.py` into the repo. Run `scripts/ci-gates.sh` before
any compiling step, after installing cargo-deny pinned:

    cargo deny --version | grep -q ' 0.20.2$' || CARGO_NET_OFFLINE=false cargo install cargo-deny --version 0.20.2 --locked

Not covered (yet): `cargo install <tool>` is ungated — pin `--version` by hand
to a release ≥ 8 days old. Build scripts of *aged* crates still run as you:
age gating raises attacker cost, it is not isolation.

Origin: mega-harness `scripts/deps-update.sh`, `scripts/min-dep-age.py`,
`docs/notes/dependency-cooldown-local-gap.md`. Native replacement when cargo
stabilises RFC 3923 `min-publish-age` (nightly-only as of 2026-08): put
`min-publish-age = "8 days"` in the global config; the Python gate becomes a
CI cross-check.
