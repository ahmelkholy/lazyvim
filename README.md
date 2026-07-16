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

- Neovim 0.12.4
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
- tmux 3.7b and `/home/ahm_e/bin/vscode-tmux` for persistent VS Code terminals
- `wl-clipboard` and `xclip` for local Linux clipboard integration; SSH/tmux
  sessions use OSC 52

Optional language/tool support:

- R and `Rscript` for R execution, R.nvim, and the R language server
- MATLAB for the MATLAB run and command-window shortcuts
- Biber for LaTeX projects that use a Biber bibliography backend

On another Arch Linux machine, install the clipboard packages with:

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

These shortcuts are added in standalone Neovim. The VS Code settings also keep
the same shortcuts owned by VS Code while VSCode-Neovim is active. VS Code
muscle memory intentionally wins over conflicting native keys.

| VS Code habit | Standalone Neovim action |
| --- | --- |
| `Ctrl+Alt+D`, `Ctrl+Shift+E`, `Alt+F` | Toggle the project Explorer and reveal the current file |
| `F2` | Reveal the current file in the Explorer |
| `Ctrl+P` | Quick Open files |
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+Alt+Q` | Search in files |
| `Ctrl+Q` | Close the active buffer |
| `Ctrl+W`, `Shift+Alt+2` | Split the current editor to the right |
| `Ctrl+Shift+B`, `Alt+B` | Open a new terminal; `Alt+B` previews Markdown in Markdown buffers |
| `Ctrl+J`, `Alt+T`, `Ctrl+Alt+B` | Toggle the terminal panel |
| `Ctrl+Tab`, `Ctrl+Shift+Tab` | Next/previous buffer |
| `Ctrl+Shift+N` | Move the current editor to a new tab |
| `Ctrl+Alt+W`, `Ctrl+Alt+E` | Move the split to the far left/right |
| `Ctrl+R` | Open recent files |
| `Ctrl+K` | Save without formatting |
| `Ctrl+/` | Toggle line/selection comments |
| `Ctrl+L` | Start a new Copilot Chat |
| `Ctrl+\\`, `Ctrl+Alt+T` | Toggle the current editor/panel zoom |
| `F11` | Toggle fullscreen-style Zen mode |
| `Ctrl+Alt+F` | Toggle the right-side symbol outline |
| `Shift+Alt+F` | Format document or selection |
| `F12`, `Shift+F12` | Definition/references |
| `Ctrl+.` | Code actions |
| `Alt+Left`, `Alt+Right` | Navigate backward/forward |
| `Alt+D` | Reveal the current file in the system file manager |
| `Ctrl+Alt+S` | Copy the current file path |
| `Ctrl+Alt+P` | Open the plugin/package manager |
| `Ctrl+Alt+G` | Open source control in Lazygit |
| `Ctrl+Alt+V` | Pick a changed Git file |
| `Alt+,`, `Alt+.`, `Alt+R` | Previous/next/preview Git change |
| `Alt+A`, `Ctrl+Alt+A`, `Ctrl+Alt+C` | Toggle Copilot Chat |
| `Ctrl+Shift+I`, `Shift+Alt+A` | AI quick chat/prompt actions |
| `Alt+G`, `Ctrl+Alt+O`, `Ctrl+Alt+X` | Gemini/OpenCode/Claude terminal |
| `Alt+'`, `Alt+I` | Accept a Copilot word/request the next suggestion |
| `Ctrl+Shift+G` | Search Markdown wiki links as a graph-like index |
| `Ctrl+Shift+Left`, then `Delete` | Open today's project note under `notes/daily/` |
| `Ctrl+Shift+Alt+R` | Toggle right-to-left display |
| `Shift+Alt+Q` | Confirm and close Neovim |

`Ctrl+B` is context-sensitive like VS Code: it previews Markdown, runs
Python/Julia/R/MATLAB files, builds LaTeX, and opens HTML/CSV externally.
Missing language executables produce a warning instead of a broken terminal.

Inside Neo-tree, the keys match the VS Code Explorer: `y` copies, `p` pastes,
`d` cuts, `x` deletes, `r` renames, `n` creates a file, and `N` creates a
folder. Hidden, dot, ignored, and platform-hidden files are visible. Fzf file
search and grep also include hidden and ignored working files.

Markdownlint uses `.markdownlint-cli2.jsonc`, where `MD013` is disabled so
long prose, links, and tables do not produce line-length diagnostics.

### Native Alternatives After VS Code Overrides

| Native operation | Replacement |
| --- | --- |
| Redo | `<leader>ur` |
| Split right/below | `<leader>wv`, `<leader>ws` |
| Move left/down/up/right | `<leader>wh`, `<leader>wj`, `<leader>wk`, `<leader>wl` |
| Close/equalize windows | `<leader>wc`, `<leader>w=` |
| Comment using native motions | `gcc`, `gc` |
| Run/build commands | `<leader>r…` |

`Ctrl+D` remains the existing multi-cursor mapping from this repository. This
was already an intentional override of Neovim's half-page scroll.

Remote Explorer, Google Tasks, and Data Wrangler remain VS Code-only because
there is no configured Neovim equivalent. HTML opens in the system browser
without Live Server reload, and CSV opens in the system's associated viewer.
MATLAB and R mappings become active when their command-line tools are installed.

## tmux

VS Code terminals use the `tmux` profile by default. The profile launches
`/home/ahm_e/bin/vscode-tmux`, which attaches to a workspace-named session or
creates one when needed.

Inside standalone Neovim running under tmux, VS Code keys take priority. Use:

- `<C-h>`: move left across Neovim splits or tmux panes
- `<leader>wh/wj/wk/wl`: move between Neovim windows
- tmux's prefix followed by an arrow: move between tmux panes

The local tmux configuration enables CSI-u extended keys so tmux transmits
`Ctrl+Shift+B` separately from `Ctrl+B`.

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
