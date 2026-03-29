#!/bin/bash

# Detect OS and install neovim
case "$(uname -s)" in
    Linux*)
        sudo apt update && sudo apt install -y neovim
        ;;
    Darwin*)
        brew install neovim
        ;;
    *)
        echo "Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

# Symlink config
ln -sf "$(pwd)/nvim" ~/.config/nvim

# First launch will auto-install lazy.nvim + all plugins
echo "Run 'nvim' to complete setup (plugins install automatically)"
