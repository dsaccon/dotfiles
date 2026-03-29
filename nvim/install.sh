#!/bin/bash

# Install neovim (Ubuntu/Debian)
sudo apt update && sudo apt install -y neovim

# Symlink config
ln -sf "$(pwd)/nvim" ~/.config/nvim

# First launch will auto-install lazy.nvim + all plugins
echo "Run 'nvim' to complete setup (plugins install automatically)"
