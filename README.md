# Linux Neovim LazyVim Config

This branch adapts the config for Linux while keeping the VSCode Neovim workflow
available. The config lives in the normal Linux path:

```text
~/.config/nvim
```

## Status

- Branch: `linux`
- Main target: Arch Linux standalone Neovim, VSCode Neovim, and daily development
- Base: [LazyVim](https://www.lazyvim.org/)
- Local Neovim path: `/usr/bin/nvim`
- Default theme: Gruvbox
- Default icon theme in VS Code: Material Icon Theme

## What This Config Does

- Boots LazyVim from `~/.config/nvim/init.lua`.
- Uses the Linux login shell from `$SHELL` instead of forcing PowerShell.
- Keeps wrapping and linebreak enabled.
- Maps `;` to `:` in normal mode.
- Keeps `vim-visual-multi` for regular Neovim only.
- Enables Treesitter for standalone Neovim.
- Disables VS Code-conflicting UI and Treesitter plugins only when running inside
  the VSCode Neovim extension.
- Uses a lightweight `init-vscode.lua` backend in VS Code so the full standalone
  plugin stack cannot slow down or interfere with VS Code's UI.
- Adds Linux VS Code settings for the Neovim executable and init file.
- Adds LazyVim extras for Python, Julia, C/C++, CMake, Docker, Git, SQL, YAML,
  TypeScript, DAP, projects, Aerial, Overseer, refactoring, tests, and Prettier.
- Adds run shortcuts for Julia, Python, Make, C, and C++ files.
- Adds R and LaTeX support and a conservative VS Code muscle-memory layer.
- Uses a Neovim-local npm cache for Mason so Node-based language tools do not
  depend on a damaged or root-owned `~/.npm` cache.

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
- GCC, G++, and make
- Julia 1.12.6 through juliaup
- Julia LanguageServer, SymbolServer, StaticLint, and JuliaFormatter in
  `~/.julia/environments/nvim-lspconfig`
- Mason language tools for Python, C/C++, CMake, shell, Lua, JSON, YAML,
  TypeScript, Docker, Markdown, TOML, SQL, formatting, and debugging
- JetBrainsMono Nerd Font installed under `~/.local/share/fonts`
- VSCode Neovim extension installed in the SSH VS Code server
- VS Code Material Icon Theme installed and selected
- VS Code Gruvbox theme extension installed
- Gruvbox selected as the default Neovim and VS Code theme
- tmux 3.6b and `/home/ahm_e/bin/vscode-tmux` for persistent VS Code terminals

Still recommended for full comfort:

- A Linux clipboard provider:
  - Wayland: `wl-clipboard`
  - X11: `xclip` or `xsel`

On Arch Linux, install missing system packages with:

```bash
sudo pacman -S --needed wl-clipboard xclip
```

This command requires your sudo password.

## Development Shortcuts

- `<leader>rj`: open a Julia REPL with `--project=@.`
- `<leader>rJ`: run the current Julia file with `--project=@.`
- `<leader>rp`: open a Python REPL, preferring the active virtualenv
- `<leader>rP`: run the current Python file
- `<leader>rm`: run `make`
- `<leader>rM`: prompt for a `make` target
- `<leader>rc`: build and run the current C file with GCC
- `<leader>rC`: build and run the current C++ file with G++

## VS Code Muscle-Memory Bridge

These shortcuts are added only when Neovim runs as a standalone editor. They do
not replace an existing important Neovim/LazyVim control.

| VS Code habit | Standalone Neovim action |
| --- | --- |
| `Ctrl+Alt+D`, `Ctrl+Shift+E`, `Alt+F` | Toggle the project Explorer and reveal the current file |
| `F2` | Reveal the current file in the Explorer |
| `Ctrl+P` | Quick Open files |
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+Alt+Q` | Search in files |
| `Ctrl+Q` | Close the active buffer |
| `Ctrl+Tab`, `Ctrl+Shift+Tab` | Next/previous buffer |
| `Ctrl+Shift+N` | Move the current editor to a new tab |
| `Shift+Alt+2` | Split editor right |
| `Ctrl+Alt+W`, `Ctrl+Alt+E` | Move the split to the far left/right |
| `Alt+T`, `Ctrl+Alt+B` | Toggle the terminal |
| `Alt+B` | New terminal; in Markdown, toggle preview instead |
| `Shift+Alt+F` | Format document or selection |
| `F12`, `Shift+F12` | Definition/references |
| `Ctrl+.` | Code actions |
| `Alt+Left`, `Alt+Right` | Navigate backward/forward |
| `Alt+D` | Reveal the current file in the system file manager |
| `Ctrl+Alt+S` | Copy the current file path |
| `Ctrl+Alt+G` | Open source control in Lazygit |
| `Ctrl+Alt+V` | Pick a changed Git file |
| `Alt+,`, `Alt+.`, `Alt+R` | Previous/next/preview Git change |
| `Alt+A`, `Ctrl+Alt+A`, `Ctrl+Alt+C` | Toggle Copilot Chat |
| `Ctrl+Shift+I`, `Shift+Alt+A` | AI quick chat/prompt actions |
| `Alt+G`, `Ctrl+Alt+O`, `Ctrl+Alt+X` | Gemini/OpenCode/Claude terminal |
| `Alt+'` | Accept the next Copilot word |
| `Ctrl+Shift+Alt+R` | Toggle right-to-left display |
| `Shift+Alt+Q` | Confirm and close Neovim |

Inside Neo-tree, the shared VS Code-like operations are `y` copy, `p` paste,
`r` rename, `n` new file, and `N` new folder. Native Neo-tree safety is kept:
`x` cuts and `d` deletes. Press `?` in the tree to see every native action.

### Intentionally Kept Native

The following VS Code shortcuts are not copied over because doing so would
remove an important Neovim operation:

| Key | Native behavior kept | Familiar alternative |
| --- | --- | --- |
| `Ctrl+W` | Window/split command prefix | `Ctrl+Q` closes a buffer |
| `Ctrl+R` | Redo | `<leader>fr` opens recent files |
| `Ctrl+I` | Jump forward | `Alt+Right` also jumps forward |
| `Ctrl+H/J/K/L` | Move across Neovim/tmux splits | `Alt+T` toggles the panel/terminal |
| `Ctrl+F`, `Ctrl+B` | Page forward/backward | `/` searches; `<leader>r…` runs code |
| `Ctrl+J` | Move to the lower split | `Alt+T` toggles the terminal |
| `Ctrl+K` | Move to the upper split | `<leader>W` saves without formatting |
| `Ctrl+\\` | Previous tmux pane | `Ctrl+W =` equalizes split widths |
| `Ctrl+/` | LazyVim terminal | `gcc` comments a line; `gc` comments a selection |
| `Ctrl+L` | Move to the right split | `<leader>aa` opens AI chat |
| `Ctrl+A/C/X/V/Z` | Native number, mode, and job controls | Use `y`, `d`, `p`, `u`, and the `+` clipboard register |

`Ctrl+D` remains the existing multi-cursor mapping from this repository. This
was already an intentional override of Neovim's half-page scroll.

VS Code-only surfaces stay in VS Code instead of gaining misleading Neovim
bindings: the Activity/Auxiliary bars, fullscreen/window management, Remote
Explorer, Google Tasks, Foam graph/daily notes, Data Wrangler, Office/CSV
viewers, MATLAB UI, HTML Live Server, and extension-specific model pickers.
Their original VS Code keybindings are unchanged. R and LaTeX received native
Neovim support because this configuration has direct equivalents for them.

## tmux

VS Code terminals use the `tmux` profile by default. The profile launches
`/home/ahm_e/bin/vscode-tmux`, which attaches to a workspace-named session or
creates one when needed.

Inside standalone Neovim running under tmux:

- `<C-h>`: move left across Neovim splits or tmux panes
- `<C-j>`: move down across Neovim splits or tmux panes
- `<C-k>`: move up across Neovim splits or tmux panes
- `<C-l>`: move right across Neovim splits or tmux panes
- `<C-\>`: jump to the previous tmux pane

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

The workspace and user settings point VS Code at the lightweight backend:

```text
/usr/bin/nvim
/home/ahm_e/.config/nvim/init-vscode.lua
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
