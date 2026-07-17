# Linux and macOS Neovim LazyVim Config

The `linux` branch supports Linux and macOS while keeping the VSCode Neovim
workflow available. The config lives in the normal Unix path:

```text
~/.config/nvim
```

## Status

- Branch: `linux`
- Main target: Linux/macOS standalone Neovim, VSCode Neovim, and daily development
- Branch policy: `main` is Windows; `linux` is Linux and macOS
- Base: [LazyVim](https://www.lazyvim.org/)
- Local Neovim path: `/usr/bin/nvim`
- Default theme: Gruvbox
- Default icon theme in VS Code: Material Icon Theme

## What This Config Does

- Boots LazyVim from `~/.config/nvim/init.lua`.
- Uses the Unix login shell from `$SHELL` instead of forcing PowerShell.
- Keeps wrapping and linebreak enabled.
- Opens Explorer on a clean bare startup, then creates up to two editor panes
  only as real files are opened.
- Gives every window its own filename/title bar and uses one global status line.
- Uses JetBrainsMono Nerd Font Mono for graphical clients and the VS Code
  workspace; terminal Neovim inherits the terminal application's font.
- Maps `;` to `:` in normal mode.
- Keeps `vim-visual-multi` for regular Neovim only.
- Enables Treesitter for standalone Neovim.
- Disables VS Code-conflicting UI and Treesitter plugins only when running inside
  the VSCode Neovim extension.
- Uses a lightweight `init-vscode.lua` backend in VS Code so the full standalone
  plugin stack cannot slow down or interfere with VS Code's UI.
- Adds Linux and macOS VS Code settings for the Neovim executable and init file.
- Shows opened workspaces in the top tab row and automatically remembers Git
  roots.
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

- `<leader>Rj`: open a Julia REPL with `--project=@.`
- `<leader>RJ`: run the current Julia file with `--project=@.`
- `<leader>Rp`: open a Python REPL, preferring the active virtualenv
- `<leader>RP`: run the current Python file
- `<leader>Rm`: run `make`
- `<leader>RM`: prompt for a `make` target
- `<leader>Rc`: build and run the current C file with GCC
- `<leader>RC`: build and run the current C++ file with G++

## VS Code Muscle-Memory Bridge

Standalone Neovim keeps its native editing, scrolling, undo, and window keys.
Only non-conflicting VS Code-style shortcuts are added. VS Code continues to
own its familiar shortcuts while VSCode-Neovim is active.

| VS Code habit | Standalone Neovim action |
| --- | --- |
| `Ctrl+Alt+D` | Open or focus Explorer; never close it |
| `Ctrl+Shift+E`, `Alt+F` | Toggle Explorer when you intentionally want to close it |
| `F2` | Reveal the current file in the Explorer |
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+Alt+Q` | Search in files |
| `Shift+Alt+2` | Split the current editor to the right |
| `Ctrl+Shift+B`, `Alt+B` | Add/focus a second terminal beside the first; maximum two |
| `Alt+T`, `Ctrl+Alt+B` | Show or hide the complete terminal group |
| `Ctrl+Tab`, `Ctrl+Shift+Tab` | Next/previous tab in the current pane |
| `Ctrl+Shift+N` | Move the current editor to a new tab |
| `Ctrl+Alt+W`, `Ctrl+Alt+E` | Move the split to the far left/right |
| `Ctrl+Alt+T` | Toggle the current editor/panel zoom |
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

The terminal group opens at twice the former panel height. Its two-terminal
limit divides that same area side by side instead of stacking extra rows.

Inside Neo-tree, the keys match the VS Code Explorer: `y` copies, `p` pastes,
`d` cuts, `x` deletes, `r` renames, `n` creates a file, and `N` creates a
folder. Hidden, dot, ignored, and platform-hidden files are visible. Fzf file
search and grep also include hidden and ignored working files.

Explorer starts without a blank editor. The first selected file creates pane
`L`, and the second creates pane `R`. Later selections rotate between them: from
the right to the left, then from the left to the right. If a pane has no file,
it closes automatically. Modified unnamed content is retained to prevent data
loss. Directories still expand and collapse inside Explorer. Each editor pane
shows up to four local tabs in its own title bar; opening a fifth removes that
pane's oldest tab. A hidden, unmodified evicted buffer is closed automatically,
while a modified or still-visible buffer is retained in Neovim.

Markdownlint uses `.markdownlint-cli2.jsonc`, where `MD013` is disabled so
long prose, links, and tables do not produce line-length diagnostics.

### Native Neovim Keys to Learn

`<leader>` is the Space key. Press Space and pause to let WhichKey show the
available actions.

| Habit or operation | Stable Neovim/LazyVim key |
| --- | --- |
| Quick Open | `<leader><space>` |
| Recent files | `<leader>fr` |
| Workspaces | `<leader>fw` or `:Workspaces` |
| Pane tabs | `<leader><Tab>` then `Tab`, `[`, `]`, `1`–`4`, `f`, `l`, `d`, or `o` |
| Close buffer | `<leader>bd` |
| Split right/below | `Ctrl+W v`, `Ctrl+W s` |
| Move left/down/up/right | `Ctrl+H/J/K/L` |
| Close/equalize windows | `Ctrl+W c`, `Ctrl+W =` |
| Restore Explorer + file-backed panes | `<leader>wL` or `:WorkspaceLayout` |
| Undo/redo | `u`, `Ctrl+R` |
| Scroll half-page down/up | `Ctrl+D`, `Ctrl+U` |
| Comment line/selection | `gcc`, `gc` |
| Terminal | `<leader>ft` or `Ctrl+/` |
| AI chat | `<leader>aa` |
| Multi-cursor | `<leader>mc` |
| Run/build commands | `<leader>R…` |

Run `:NvimTransition` inside Neovim for the personalized migration guide.
Run `:ShortcutHealth` to verify leader mappings, custom shortcuts, commands,
plugin modules, external tools, and clipboard support without changing files.

The automatic Explorer workspace is deliberately limited to a clean `nvim`
start. It does not rearrange explicit file/directory opens, diffs, stdin, or
restored sessions. It never keeps a blank editor: file selections grow the
layout from Explorer-only to one and then two file panes. Bufferline is disabled
because one shared buffer row makes split ownership unclear; each window instead
owns a local four-tab row directly above it. `▸` marks the selected pane tab, `+`
marks unsaved changes, and the `L`/`R` badge identifies the editor group. The
top tab row shows opened workspaces; Git roots are added automatically, while
`:WorkspaceAdd` saves a non-Git directory manually.

Remote Explorer, Google Tasks, and Data Wrangler remain VS Code-only because
there is no configured Neovim equivalent. HTML opens in the system browser
without Live Server reload, and CSV opens in the system's associated viewer.
MATLAB and R mappings become active when their command-line tools are installed.

## tmux

VS Code terminals use the `tmux` profile by default. The profile launches
`/home/ahm_e/bin/vscode-tmux`, which attaches to a workspace-named session or
creates one when needed.

Inside standalone Neovim running under tmux, use the standard navigation keys:

- `<C-h/j/k/l>`: move left/down/up/right across Neovim splits or tmux panes
- `<C-\\>`: return to the previous pane
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

Yanking with `y`, `yy`, or visual `y` mirrors the copied text to the system
clipboard. Deletes and changes do not replace that clipboard content.

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
