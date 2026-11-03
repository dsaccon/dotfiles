# macvm — a general-purpose macOS VM

One command for a personal macOS virtual machine on an Apple Silicon Mac, built with
[tart](https://tart.run) from Apple's own restore image: a clean macOS as Apple ships it,
with nothing third-party inside.

```sh
macvm create           # install macOS, walk the first-boot setup, enable key login
macvm up               # start it, with a window (--headless: without)
macvm ssh              # log in by key; `macvm ssh <command>` runs one command
macvm down             # stop it
macvm status           # running or not, and its address
macvm list             # every VM on this Mac, and which ones macvm set up (also: ls)
macvm help             # every command and setting, explained
macvm key              # redo create's last part (account name, key) if it was interrupted
```

## Creating one

`macvm create` downloads Apple's newest restore image this Mac can host (15–20 GB, cached by
tart in `~/.tart/cache`), installs it, and opens the VM's window. macOS's first-boot setup cannot
be scripted without a third-party tool, so you click through it once (about ten minutes):
language, a local account and password, then **System Settings → General → Sharing → Remote
Login** on. The script then asks the account's name and its password once, to install a key
made for this VM; after that, `macvm ssh` needs no password.

Settings come from the environment:

| Variable | Default | |
|---|---|---|
| `MACVM_NAME` | `macvm` | the VM's name; several VMs, several names |
| `MACVM_IMAGE` | `latest` | or an `.ipsw` path or URL, for another macOS version |
| `MACVM_CPU` | `4` | |
| `MACVM_MEMORY_MB` | `6144` | |
| `MACVM_DISK_GB` | `50` | a cap: the disk only takes what is written to it |

Disk: a fresh macOS takes about 25–30 GB on the host; the download adds 15–20 GB until
`tart prune --entries=caches` removes it.

## What it keeps where

`~/.macvm/<name>/` holds the VM's SSH key (it lets this Mac log in to the VM, never the
reverse), the VM's host key, the guest account's name and the VM's log. The VM itself is
tart's, in `~/.tart/vms/<name>`.

## Things to know

- **Network:** the VM shares the Mac's network (NAT). It reaches the internet, the local
  network, and services on the Mac that listen on all interfaces. tart's `--net-softnet`
  confines it more, at the cost of a helper that needs root.
- **No shared folders:** nothing on the Mac is visible inside the VM. tart's `--dir` shares
  a folder, if wanted.
- **Updates:** inside the VM, as on any Mac (System Settings → General → Software Update).
- **Deleting:** left to you, on purpose: `tart delete <name>`, then remove `~/.macvm/<name>`.
- **Memory:** macOS lets at most two macOS VMs run at once, and each takes its memory from
  the Mac's.

## Install

Handled by `../install.sh macvm`: links `macvm` to `~/.local/bin/macvm`. Skipped on anything
but macOS. tart itself is not installed: see [tart.run](https://tart.run).
