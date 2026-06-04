# Linux Neovim LazyVim Config

This branch adapts the config for Linux while keeping the VSCode Neovim workflow
available. The config lives in the normal Linux path:

```text
~/.config/nvim
```

## Status

- Branch: `linux`
- Main target: Arch Linux standalone Neovim and VSCode Neovim
- Base: [LazyVim](https://www.lazyvim.org/)
- Local Neovim path: `/usr/bin/nvim`

## What This Config Does

- Boots LazyVim from `~/.config/nvim/init.lua`.
- Uses the Linux login shell from `$SHELL` instead of forcing PowerShell.
- Keeps wrapping and linebreak enabled.
- Maps `;` to `:` in normal mode.
- Keeps `vim-visual-multi` for regular Neovim only.
- Enables Treesitter for standalone Neovim.
- Disables VS Code-conflicting UI and Treesitter plugins only when running inside
  the VSCode Neovim extension.
- Adds Linux VS Code settings for the Neovim executable and init file.

## Installed Location

This machine is already set up with this repo cloned to:

```text
/home/ahm_e/.config/nvim
```

It is checked out on the `linux` branch.

## Requirements

Installed on this machine:

- Neovim 0.12.2
- Git
- ripgrep
- fd
- fzf
- lazygit
- Node.js and npm
- unzip
- GCC and make
- JetBrainsMono Nerd Font installed under `~/.local/share/fonts`
- VSCode Neovim extension installed in the SSH VS Code server

Still recommended for full comfort:

- A Linux clipboard provider:
  - Wayland: `wl-clipboard`
  - X11: `xclip` or `xsel`

On Arch Linux, install missing system packages with:

```bash
sudo pacman -S --needed wl-clipboard xclip
```

This command requires your sudo password.

## First Run

Start Neovim and let Lazy install plugins:

```bash
nvim
```

If needed, sync plugins manually:

```vim
:Lazy sync
```

Then restart Neovim.

## VS Code

Install the extension:

```bash
code --install-extension asvetliakov.vscode-neovim
```

The workspace settings point VS Code at:

```text
/usr/bin/nvim
/home/ahm_e/.config/nvim/init.lua
```

If `code` is not available, install the extension from the VS Code Extensions
view and reload the window.

## Updating

```bash
cd ~/.config/nvim
git pull
nvim --headless "+Lazy! sync" +qa
```

## Troubleshooting

If clipboard integration does not work, install `wl-clipboard` on Wayland or
`xclip` on X11, then restart Neovim.

If icons render as boxes, install a Nerd Font and configure your terminal or VS
Code to use it.

If VS Code cannot find Neovim, confirm the path:

```bash
command -v nvim
```

Then update `vscode-neovim.neovimExecutablePaths.linux` in VS Code settings.

If `:Lazy sync` or Mason registry refresh hangs while proxy variables are set,
run it once without the stale proxy environment:

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy -u proxy_url nvim --headless "+Lazy! sync" +qa
```

## License

This project is released under the Apache License 2.0. See [LICENSE](LICENSE).
