# dotfiles

## Install

```sh
git clone https://github.com/dsaccon/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

With no arguments, `install.sh` installs every component in one pass. Pass one or more
component names to install only those:

```sh
~/dotfiles/install.sh mdview        # just mdview
~/dotfiles/install.sh tmux nvim     # tmux and nvim
~/dotfiles/install.sh --help        # list components
```

Each component is symlinked into place and the script is idempotent — safe to re-run.
Existing symlinks are replaced; existing real files are backed up to
`<name>.bak.<timestamp>` first, so nothing is silently lost.

| Component | Source | Installed to |
| --- | --- | --- |
| `tmux` | `.tmux.conf` | `~/.tmux.conf` |
| `vim` | `vim/vimrc` | `~/.vimrc` |
| `nvim` | `nvim/` | `~/.config/nvim` |
| `mdview` | [`mdview/`](mdview/) | `~/mdview`, plus a source line appended to `~/.bashrc` |

## mdview

[`mdview/`](mdview/) is a terminal markdown viewer — an `md` command wrapping
[glow](https://github.com/charmbracelet/glow), tuned for reading `.md` files over SSH
inside tmux, in a narrow split or a full-width window. Eleven themes, switched with
`mdtheme`. See [mdview/README.md](mdview/README.md).
