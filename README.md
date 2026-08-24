# Cross-Platform Neovim LazyVim Config

The single `main` branch supports Windows, macOS, and Linux. Windows behavior is
the source of truth; the Unix support is conditional and does not change the
Windows keymaps or workflow. Install it in the normal platform configuration
path:

```text
Windows: %LOCALAPPDATA%\nvim
macOS/Linux: ~/.config/nvim
```

## Status

- Branch: `main`
- Main target: identical standalone and VSCode-Neovim behavior on every OS
- Branch policy: `main` is the only configuration branch
- Base: [LazyVim](https://www.lazyvim.org/)
- Local Neovim path: `C:\Program Files\Neovim\bin\nvim.exe`
- Default theme: Monokai
- Default icon theme in VS Code: Material Icon Theme

## What This Config Does

- Boots LazyVim from `%LOCALAPPDATA%\nvim\init.lua`.
- Uses PowerShell when `pwsh` is available.
- Keeps wrapping and linebreak enabled.
- Opens Explorer on a clean bare startup, then creates up to two editor panes
  only as real files are opened.
- Gives every window its own filename/title bar and uses one global status line.
- Uses JetBrainsMono Nerd Font Mono for graphical clients. Terminal Neovim
  inherits the terminal application's font, while VS Code uses platform-safe
  ordered fallbacks.
- Maps `;` to `:` in normal mode.
- Keeps `vim-visual-multi` for regular Neovim only.
- Enables Treesitter for standalone Neovim.
- Disables VS Code-conflicting UI and Treesitter plugins only when running inside
  the VSCode Neovim extension.
- Uses a lightweight `init-vscode.lua` backend in VS Code so the full standalone
  plugin stack cannot slow down or interfere with VS Code's UI.
- Adds Windows, macOS, and Linux VS Code paths in the same settings file.
- Shows opened workspaces in the top tab row and automatically remembers Git
  roots.
- Adds LazyVim extras for Python, Julia, C/C++, CMake, Docker, Git, SQL, YAML,
  TypeScript, DAP, projects, Aerial, Overseer, refactoring, tests, and Prettier.
- Enables native GitHub Copilot inline completion in standalone Neovim. It uses
  Neovim 0.12's built-in completion support and keeps VS Code completion under
  VS Code's control.
- Adds run shortcuts for Julia, Python, Make, C, and C++ files.
- Adds R and LaTeX support and a conservative VS Code muscle-memory layer.

## Installed Location

Clone or link this repository to:

```text
%LOCALAPPDATA%\nvim
```

Keep it checked out on the `main` branch.

## Requirements

Recommended tools:

- Neovim 0.12 or newer
- Git
- ripgrep
- fd
- fzf
- lazygit
- Node.js and npm
- a C/C++ compiler and `make`
- Julia through juliaup when Julia support is needed
- Mason language tools for Python, C/C++, CMake, shell, Lua, JSON, YAML,
  TypeScript, Docker, Markdown, TOML, SQL, formatting, and debugging
- JetBrainsMono Nerd Font or another Nerd Font
- VSCode Neovim extension
- VS Code Material Icon Theme installed and selected
- Monokai selected as the default Neovim and VS Code theme
- A GitHub account with Copilot access for AI inline completion

Optional language/tool support:

- R and `Rscript` for R execution, R.nvim, and the R language server
- MATLAB for the MATLAB run and command-window shortcuts
- Biber for LaTeX projects that use a Biber bibliography backend

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

Inside VSCode-Neovim, `gj` and `gk` are explicitly delegated to VS Code's
wrapped-line cursor command in normal and visual mode. This preserves display
line movement even though the custom `g` prefix menu is also enabled.

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
| `L`, `H` | Cycle files across every open pane/tab; the menu shows each file's window |
| `Space`, `,` | Fuzzy switch to any open file without scanning the disk |
| `Space`, `Space` | Find project files with ignored/generated directories excluded |
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
| `Alt+G`, `Ctrl+Alt+O`, `Ctrl+Alt+X` | Gemini/OpenCode/Claude terminal |
| `Ctrl+Shift+G` | Search Markdown wiki links as a graph-like index |
| `Ctrl+Shift+Left`, then `Delete` | Open today's project note under `notes/daily/` |
| `Ctrl+Shift+Alt+R` | Toggle right-to-left display |
| `Shift+Alt+Q` | Confirm and close Neovim |

The terminal group opens at twice the former panel height. Its two-terminal
limit divides that same area side by side instead of stacking extra rows.
`Alt+B` also works while typing in a terminal: it creates and selects the
second terminal, then cycles between both terminals. It is the reliable
fallback when a terminal emulator sends `Ctrl+Shift+B` as plain `Ctrl+B`.

On the remapped Mac keyboard, press physical Fn+Left Command+B for Windows
Ctrl+Alt+B. Physical Fn+B remains Ctrl+B, including the context-sensitive SVG
preview. Terminal.app must have “Use Option as Meta key” enabled; the Karabiner
repository's `apply-macos-settings.sh` configures it for the default profile.

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
| Close current file, keep pane | `<leader>wq` or `<leader>bd` |
| Close current window/pane | `<leader>wQ` |
| Split right/below | `Ctrl+W v`, `Ctrl+W s` |
| Move left/down/up/right | `Ctrl+H/J/K/L` |
| Close/equalize windows | `Ctrl+W c`, `Ctrl+W =` |
| Restore Explorer + file-backed panes | `<leader>wL` or `:WorkspaceLayout` |
| Undo/redo | `u`, `Ctrl+R` |
| Scroll half-page down/up | `Ctrl+D`, `Ctrl+U` |
| Comment line/selection | `gcc`, `gc` |
| Terminal | `<leader>ft` or `Ctrl+/` |
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

## First Run

Start Neovim and let Lazy install plugins:

```powershell
nvim
```

If needed, sync plugins manually:

```vim
:Lazy sync
```

Then restart Neovim.

Authorize GitHub Copilot once from standalone Neovim:

```vim
:LspCopilotSignIn
```

Follow the GitHub device-login prompt. The saved authorization is reused on
later starts; press `Tab` to accept an inline suggestion.

## VS Code

Install the extension:

```bash
code --install-extension asvetliakov.vscode-neovim
```

The workspace and user settings point VS Code at the lightweight backend:

```text
C:\Program Files\Neovim\bin\nvim.exe
C:\Users\ahm_e\AppData\Local\nvim\init-vscode.lua
```

If `code` is not available, install the extension from the VS Code Extensions
view and reload the window.

## Updating

```powershell
Set-Location $env:LOCALAPPDATA\nvim
git pull
nvim --headless "+Lazy! sync" +qa
```

## Troubleshooting

Yanking with `y`, `yy`, or visual `y` mirrors the copied text to the system
clipboard. Deletes and changes do not replace that clipboard content.

If icons render as boxes, install a Nerd Font and configure your terminal or VS
Code to use it.

If VS Code cannot find Neovim, confirm the path:

```powershell
where.exe nvim
```

Then update `vscode-neovim.neovimExecutablePaths.win32` in VS Code settings.

## License

This project is released under the Apache License 2.0. See [LICENSE](LICENSE).
