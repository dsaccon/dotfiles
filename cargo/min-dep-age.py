#!/usr/bin/env python3
"""Fail if any crates.io dependency locked in Cargo.lock was published fewer
than --min-days days ago (docs/specs/slice-d.md §1: an 8-day cooldown against
the compromise -> publish -> harvest pattern). Reads Cargo.lock with tomllib,
asks https://crates.io/api/v1/crates/<name> once per crate name (User-Agent set,
one request per second), compares each locked version's created_at to now.
--baseline names a file of (name, version) pairs already locked when the
cooldown was adopted, exempted from the check at that exact version only; it
should be empty, or deleted, once every entry has aged past --min-days.
Exit codes: 0 ok, 1 a young or unresolvable crate version was found, 2 the
check itself could not run (crates.io unreachable, timed out, or errored)."""
import argparse
import json
import sys
import time
import tomllib
import urllib.error
import urllib.request
from datetime import datetime, timezone

import socket

# Some hosts advertise IPv6 but black-hole it. urllib tries the first address
# getaddrinfo returns and waits out the whole timeout before trying the next,
# which turned a 3-minute check into an hour on one such machine. Prefer IPv4
# so a dead v6 route costs nothing; v6-only hosts still work (the sort keeps
# every address, it only reorders).
_getaddrinfo = socket.getaddrinfo


def _ipv4_first(*args, **kwargs):
    return sorted(_getaddrinfo(*args, **kwargs), key=lambda r: r[0] != socket.AF_INET)


socket.getaddrinfo = _ipv4_first

API = "https://crates.io/api/v1/crates/{name}"
UA = "cargo-gated min-dep-age (https://github.com/dsaccon/dotfiles)"
REGISTRY = "registry+https://github.com/rust-lang/crates.io-index"


def locked_versions(lockfile):
    with open(lockfile, "rb") as f:
        lock = tomllib.load(f)
    by_name = {}
    for p in lock.get("package", []):
        if p.get("source", "") == REGISTRY:
            by_name.setdefault(p["name"], set()).add(p["version"])
    return by_name


class NetworkFailure(Exception):
    """crates.io could not be reached, or answered with an error other than
    404 — distinct from a real finding (young or unresolvable crate) so a
    caller reading the exit code can tell a transient network fault from an
    actual verdict about dependency age."""


def created_at(name):
    req = urllib.request.Request(API.format(name=name), headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            # The crate name itself doesn't exist on crates.io. Every locked
            # version of it reports through the existing "not found" path
            # (created_at() returning {} makes every stamps.get(ver) a miss).
            return {}
        raise NetworkFailure(f"{name}: {e}") from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise NetworkFailure(f"{name}: {e}") from e
    return {v["num"]: v["created_at"] for v in data["versions"]}


def load_baseline(path):
    """Parse a baseline file: '#' comment lines and blank lines ignored, each
    other line is 'name version'. Returns the set of (name, version) pairs
    exempted from the age check at that exact version."""
    entries = set()
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            name, ver = line.split()
            entries.add((name, ver))
    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lockfile", default="Cargo.lock")
    ap.add_argument("--min-days", type=int, default=8)
    ap.add_argument("--sleep", type=float, default=1.0)
    ap.add_argument(
        "--baseline",
        default=None,
        help="file of already-locked name/version pairs grandfathered in at adoption time",
    )
    a = ap.parse_args()
    by_name = locked_versions(a.lockfile)
    baseline = load_baseline(a.baseline) if a.baseline else set()
    now = datetime.now(timezone.utc)
    young, verified, exempt = [], 0, 0
    stamps_by_name = {}
    for i, name in enumerate(sorted(by_name)):
        try:
            stamps = created_at(name)
        except NetworkFailure as e:
            print(
                f"ERROR: could not query crates.io — {e}; this is a network "
                "failure, not a verdict about dependency age",
                file=sys.stderr,
            )
            return 2
        stamps_by_name[name] = stamps
        for ver in sorted(by_name[name]):
            ts = stamps.get(ver)
            if (name, ver) in baseline:
                exempt += 1
                continue
            verified += 1
            if ts is None:
                young.append((name, ver, None))
                continue
            age = (now - datetime.fromisoformat(ts.replace("Z", "+00:00"))).days
            if age < a.min_days:
                young.append((name, ver, age))
        if i + 1 < len(by_name):
            time.sleep(a.sleep)

    # A baseline entry is grandfathered only while it stays locked at the
    # exact version named. Once it ages past the cooldown, or the lockfile
    # moves on from it, say so — never silently, and never affecting the
    # exit code (this is a prompt to shrink the baseline, not a failure).
    notes = []
    for name, ver in sorted(baseline):
        if name in by_name and ver in by_name[name]:
            ts = stamps_by_name.get(name, {}).get(ver)
            if ts is not None:
                age = (now - datetime.fromisoformat(ts.replace("Z", "+00:00"))).days
                if age >= a.min_days:
                    notes.append(
                        f"NOTE: baseline entry {name} {ver} is now {age} day(s) old "
                        f"— remove it from {a.baseline}"
                    )
        else:
            notes.append(
                f"NOTE: baseline entry {name} {ver} is no longer locked — "
                f"remove it from {a.baseline}"
            )

    if young:
        print(f"FAIL: {len(young)} locked crates.io version(s) younger than {a.min_days} days:")
        for name, ver, age in young:
            print(f"  {name} {ver}: {'not found on crates.io' if age is None else f'{age} day(s) old'}")
        for note in notes:
            print(note)
        return 1
    msg = f"ok: {verified} locked crates.io versions verified at least {a.min_days} days old"
    if a.baseline:
        msg += f" ({exempt} exempted by the baseline)"
    print(msg)
    for note in notes:
        print(note)
    return 0


if __name__ == "__main__":
    sys.exit(main())
