# macvm — personal VMs on a Mac

One command for personal virtual machines on an Apple Silicon Mac, built with
[tart](https://tart.run) from each system's own installer, with nothing third-party inside:

- **macOS**, from Apple's restore image: a second Mac, in a window.
- **Ubuntu Server LTS**, from Ubuntu's ARM64 installer: no desktop, used over SSH.

```sh
macvm create                 # a macOS VM named macvm
macvm create --linux [name]  # an Ubuntu Server VM (default name: ubuntu)
macvm up [name]              # start it (macOS: window; Linux: none; --window / --headless)
macvm ssh [name] [command]   # log in by key, or run one command
macvm down [name]            # stop it
macvm status [name]          # running or not, and its address
macvm list                   # every VM on this Mac, and which ones macvm set up (also: ls)
macvm help                   # every command and setting, explained
macvm key [name]             # redo create's last part (account name, key) if it was interrupted
```

With only one VM the name can be left out; with several, macvm asks which.

## Creating one

**macOS:** `macvm create` downloads Apple's newest restore image this Mac can host (15–20 GB,
cached by tart in `~/.tart/cache`), installs it, and opens the VM's window. macOS's first-boot
setup cannot be scripted without a third-party tool, so you click through it once (about ten
minutes): language, a local account and password, then **System Settings → General → Sharing →
Remote Login** on.

**Ubuntu Server:** `macvm create --linux` reads Ubuntu's checksum list over HTTPS, downloads the
newest point release of the LTS's ARM64 server installer (about 3 GB, kept in
`~/.macvm/.images`), refuses it unless its SHA-256 matches, and opens the installer in a window.
Answer its questions (about ten minutes); the one that matters is **Install OpenSSH server**.
After "Reboot Now", press Enter in the terminal: macvm restarts the VM without the installer.

Either way, the script then asks the account's name and its password once, to install a key
made for that VM; after that, `macvm ssh` needs no password.

Settings come from the environment and apply to `create`:

| Variable | Default (macOS / Linux) | |
|---|---|---|
| `MACVM_NAME` | `macvm` / `ubuntu` | the default VM name |
| `MACVM_CPU` | `4` / `2` | |
| `MACVM_MEMORY_MB` | `6144` / `4096` | |
| `MACVM_DISK_GB` | `50` / `20` | a cap: the disk only takes what is written to it |
| `MACVM_IMAGE` | `latest` | macOS: or an `.ipsw` path or URL, for another version |
| `MACVM_UBUNTU` | `26.04` | Linux: the LTS release; its newest point release is used |

Disk: a fresh macOS VM takes about 25–30 GB on the host, an Ubuntu Server VM about 4–6 GB. The
macOS download stays in tart's cache until `tart prune --entries=caches --space-budget=0`; the
Ubuntu installer stays in `~/.macvm/.images` until you remove it.

## What it keeps where

`~/.macvm/<name>/` holds the VM's SSH key (it lets this Mac log in to the VM, never the
reverse), the VM's host key, the guest account's name, its system (macOS or Linux) and the VM's
log. `~/.macvm/.images/` holds downloaded Ubuntu installers. The VMs themselves are tart's, in
`~/.tart/vms/<name>`.

## Things to know

- **Network:** a VM shares the Mac's network (NAT). It reaches the internet, the local
  network, and services on the Mac that listen on all interfaces. tart's `--net-softnet`
  confines it more, at the cost of a helper that needs root.
- **No shared folders:** nothing on the Mac is visible inside a VM. tart's `--dir` shares
  a folder, if wanted.
- **Linux is Arm (aarch64),** as the Mac is. Most software has Arm builds.
- **Updates:** from inside the VM (macOS: Software Update; Ubuntu: `sudo apt update && sudo apt upgrade`).
- **Deleting:** left to you, on purpose: `tart delete <name>`, then remove `~/.macvm/<name>`.
- **Memory:** each running VM takes its memory from the Mac's; macOS allows at most two macOS
  VMs at once.

## Install

Handled by `../install.sh macvm`: links `macvm` to `~/.local/bin/macvm`. Skipped on anything
but macOS. tart itself is not installed: see [tart.run](https://tart.run). The script also uses
`curl`, `shasum`, `ssh` and `nc`, which macOS ships.
