# dotfiles

## Install

```sh
git clone https://github.com/dsaccon/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` installs everything in one pass. It symlinks each component into place and is
idempotent — safe to re-run. Existing symlinks are replaced; existing real files are backed
up to `<name>.bak.<timestamp>` first, so nothing is silently lost.

| Component | Installed to |
| --- | --- |
| `.tmux.conf` | `~/.tmux.conf` |
| `vim/vimrc` | `~/.vimrc` |
| `nvim/` | `~/.config/nvim` |
| [`mdview/`](mdview/) | `~/mdview`, plus a source line appended to `~/.bashrc` |

## mdview

[`mdview/`](mdview/) is a terminal markdown viewer — an `md` command wrapping
[glow](https://github.com/charmbracelet/glow), tuned for reading `.md` files over SSH
inside tmux, in a narrow split or a full-width window. Eleven themes, switched with
`mdtheme`. See [mdview/README.md](mdview/README.md).
