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
- Default theme: Gruvbox
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
- Uses `init-vscode.lua` to enter the same LazyVim configuration in VS Code.
  LazyVim's official VS Code extra keeps the editing-safe plugin subset active,
  while native VS Code surfaces replace terminal-only UI plugins.
- Builds the editor's Space menu from the effective Neovim mappings, so new or
  buffer-local LazyVim actions appear in VS Code without maintaining a second
  static menu tree.
- Adds Windows, macOS, and Linux VS Code paths in the same settings file.
- Shows the current workspace above Explorer without consuming a full-width
  row and automatically remembers Git roots.
- Adds LazyVim extras for Python, Julia, C/C++, CMake, Docker, Git, SQL, YAML,
  TypeScript, DAP, projects, Aerial, Overseer, refactoring, tests, and Prettier.
- Enables native GitHub Copilot inline completion in standalone Neovim. It uses
  Neovim 0.12's built-in completion support and keeps VS Code completion under
  VS Code's control.
- Uses Tab to accept completion suggestions while Enter remains a normal
  newline key.
- Adapts Arabic rendering to BiDi-capable terminals on macOS, Linux, and
  Windows while keeping mixed Arabic/English source safe and pane-local.
- Detects Arabic, Russian, and English input automatically from the active OS
  layout and keeps physical Vim commands working outside Insert mode.
- Renders Markdown tables inside the live pane width without resizing the page
  or modifying their source.
- Adds run shortcuts for Julia, Python, Make, C, and C++ files.
- Adds R and LaTeX support and a conservative VS Code muscle-memory layer.
- Keeps every configuration-owned runtime helper in Lua; there are no custom
  shell or Python scripts.

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
- lazygit
- Node.js and npm
- a C/C++ compiler and `make`
- Julia through juliaup when Julia support is needed
- Mason language tools for Python, C/C++, CMake, shell, Lua, JSON, YAML,
  TypeScript, Docker, Markdown, TOML, SQL, formatting, and debugging
- JetBrainsMono Nerd Font or another Nerd Font
- VSCode Neovim extension
- VS Code Material Icon Theme installed and selected
- Gruvbox selected as the default Neovim theme
- A GitHub account with Copilot access for AI inline completion

Optional language/tool support:

- Python is needed only for running Python programs, not for Neovim or SVG
  previews.
- R and `Rscript` for R execution, R.nvim, and the R language server
- MATLAB for the MATLAB run and command-window shortcuts
- Biber for LaTeX projects that use a Biber bibliography backend
- `rsvg-convert`, ImageMagick, or Inkscape for in-terminal SVG previews

## Development Shortcuts

- `<leader>Rj`: open a Julia REPL with `--project=@.`
- `<leader>RJ`: run the current Julia file with `--project=@.`
- `<leader>Rp`: open a Python REPL, preferring the active virtualenv
- `<leader>RP`: run the current Python file
- `<leader>Rm`: run `make`
- `<leader>RM`: prompt for a `make` target
- `<leader>Rc`: build and run the current C file with GCC
- `<leader>RC`: build and run the current C++ file with G++

## Arabic, Russian, and Mixed-Direction Text

The display mode is selected from terminal capabilities, not from the operating
system. In a BiDi-capable terminal, Neovim keeps its grid and source code LTR
while the terminal shapes and reorders Arabic runs. The first strong letter
chooses each line's natural alignment: Arabic-first lines align right and
English-first lines stay left. The alignment is display-only virtual padding,
so it never changes the file, pane width, or saved UTF-8 text. Long lines
soft-wrap inside a stable one-cell margin. This works for Arabic comments,
Markdown, string literals, and output such as:

```julia
# ويستخدم promote بدل ما يعلن أن العالم كله Float64 وانتهى النقاش.
println("النتيجة = ", value)
```

Here the Julia syntax remains LTR, Arabic reads RTL with connected letters, and
`promote`, `Float64`, and `value` remain LTR. Responsive Markdown tables use the
remote UI's connected box-drawing borders and stay within the live pane width.
The original Markdown appears unchanged while editing and is the only content
saved to disk.
Use `<leader>mt` near a table (or `:MarkdownTableEdit`) to reveal and edit its
source; leaving Insert mode restores the formatted reading view.

| Terminal | Detection and behavior |
| --- | --- |
| macOS Terminal.app | BiDi is detected automatically |
| Linux GNOME Terminal or another VTE 0.58+ frontend | BiDi is detected automatically |
| Linux Konsole | Its default complex-text BiDi mode is detected automatically |
| mlterm on macOS, Linux, or Windows | BiDi is detected automatically |
| Windows Terminal, kitty, Alacritty, and unknown terminals | Safe native-shaping fallback; no false claim of mixed BiDi |

Terminal Neovim inherits its font from the terminal. Use a monospaced font with
Arabic forms on every machine; DejaVuSansM Nerd Font provides both Arabic and
Neovim icons. A terminal cell grid cannot reproduce a browser's complete
Obsidian-style paragraph layout by itself, so exact mixed BiDi requires a
capable terminal such as those above. `:ArabicStatus` reports the detected mode.

For a terminal with BiDi enabled but no detectable environment marker, opt in
explicitly after verifying the terminal profile:

```text
macOS/Linux: NVIM_TUI_BIDI=1 nvim
PowerShell:  $env:NVIM_TUI_BIDI = "1"; nvim
cmd.exe:     set NVIM_TUI_BIDI=1 && nvim
```

- Input needs no Neovim command: change the normal OS keyboard layout and type.
  Neovim detects Arabic, Russian, or English from inserted characters without
  adding local UI elements to the remote status line.
- `<leader>ua` or `Ctrl+Shift+Alt+R`: toggle mixed Arabic/English bidi display
- `:Arabic` or `:ArabicAuto`: restore the recommended mixed mode
- `:ArabicMixed`: explicitly keep code LTR and render Arabic runs with bidi
- `:ArabicRTL`: use Neovim's window-wide native RTL only for a document that is
  entirely Arabic
- `:ArabicOff`: disable bidi
- `:ArabicStatus`: show the active terminal and mode

Neovim's built-in `rightleft` reverses a complete screen line and therefore is
not used automatically for code or Markdown. Pane and table edges retain the
remote UI's connected `│` box-drawing separator.

Normal, Visual, Select, and Operator-pending Vim commands follow physical QWERTY
keys automatically while the OS keyboard is Arabic or Russian. For example,
Arabic `ا/ت/ن/م` and Russian `р/о/л/д` continue to act as `h/j/k/l`; counts also work
with Arabic-Indic and Persian digits. Insert mode accepts the active OS layout
directly, avoiding Neovim-specific switching and double translation on every OS.

## VS Code Muscle-Memory Bridge

Standalone Neovim and VSCode-Neovim share the same Normal, Visual, Select, and
Operator-pending editing keys. VS Code-native file, search, debug, test, Git,
terminal, pane, and settings surfaces are translated behind the corresponding
LazyVim leader paths. Insert mode remains under VS Code's control so typing,
completion, and platform clipboard shortcuts retain normal editor behavior.

Pressing Space in an editor opens the live Which Key window immediately. Its
tree is built from the effective global and buffer-local leader mappings,
including groups and nested actions, so the following keys work like a Neovim
leader sequence. Space in a non-writing VS Code list still opens the static
native list menu. `Ctrl+Z` is a deliberate Normal-mode exception: VS Code
handles undo because sending Neovim's suspend command would stop the embedded
process. `u` also undoes, `Ctrl+R` opens Recent in both hosts, and `:redo`
remains available in standalone Neovim.

Inside VSCode-Neovim, `gj` and `gk` are explicitly delegated to VS Code's
wrapped-line cursor command in normal and visual mode. This preserves display
line movement even though the custom `g` prefix menu is also enabled.

| VS Code habit | Standalone Neovim action |
| --- | --- |
| `Ctrl+Alt+D` | Open or focus Explorer; never close it |
| `Ctrl+Shift+E`, `Alt+F` | Toggle Explorer when you intentionally want to close it |
| `Space`, `e`, `r` | Reveal the current file in Explorer |
| `F2` | Rename the symbol under the cursor; rename a file when Explorer is focused |
| `Ctrl+P` | Quick Open project files |
| `Ctrl+Q` | Close the current file and keep its pane |
| `Ctrl+R` | Open Recent files |
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+Shift+F` | Toggle the Activity Bar in VS Code or Explorer in Neovim |
| `Ctrl+Alt+Q` | Search in files |
| `Ctrl+Tab`, `Ctrl+Shift+Tab` | Next/previous open editor |
| `Shift+Alt+2` | Split the current editor to the right |
| `Ctrl+Shift+B`, `Alt+B` | Add/focus a second terminal beside the first; maximum two |
| `Alt+T`, `Ctrl+Alt+B` | Show or hide the complete terminal group |
| `Alt+L` (lowercase `l`) | Cycle files across every open pane/tab; the menu shows each file's window |
| `Space`, `,` | Fuzzy switch to any open file without scanning the disk |
| `Space`, `Space` | Find project files with ignored/generated directories excluded |
| `Ctrl+Shift+N` | Move the current editor to a new tab |
| `Ctrl+Alt+W`, `Ctrl+Alt+E` | Move the current file to the left/right editor pane |
| `Ctrl+\` | Toggle the current file/pane wide, then restore it |
| `Ctrl+Alt+T` | Toggle a maximized panel inside Neovim |
| `F11` | Toggle the active host's Zen view |
| `Ctrl+Alt+F` | Toggle the right-side symbol outline |
| `Shift+Alt+F` | Format document or selection |
| `Alt+Up`, `Alt+Down` | Move the current line or selection |
| `F12`, `Shift+F12` | Definition/references |
| `F8`, `Shift+F8` | Next/previous problem |
| `Ctrl+Enter`, `Ctrl+LeftClick` | Open the function or symbol definition under the cursor |
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
| `Ctrl+Shift+Alt+R` | Toggle mixed Arabic/English bidi |
| `Shift+Alt+Q` | Confirm and close Neovim |

Shared physical shortcuts have one bidirectional route manifest:
`shared-keybindings.json`. Its generated counterpart is the marked `NVIM
SHARED KEY ROUTES` block in VS Code's `keybindings.json`. While Neovim is
running, changing either side updates the other; on startup, the newer side
wins. Keep each `NVIM SHARED` metadata comment with its VS Code binding so its
standalone Neovim meaning travels with it. Use `:SharedKeysHealth`,
`:SharedKeysSync`, `:SharedKeysPush`, or `:SharedKeysPull` to audit or reconcile
the routes explicitly. The Space menu needs no duplicate manifest: it is built
directly from the effective Neovim mappings and buffer-local menus.

The terminal group opens at twice the former panel height. Its two-terminal
limit divides that same area side by side instead of stacking extra rows.
`Alt+B` also works while typing in a terminal: it creates and selects the
second terminal, then cycles between both terminals. It is the reliable
fallback when a terminal emulator sends `Ctrl+Shift+B` as plain `Ctrl+B`.

On the remapped Mac keyboard, press physical Fn+Left Command+B for Windows
Ctrl+Alt+B. Physical Fn+B remains Ctrl+B, including the context-sensitive SVG
preview. Terminal.app must have “Use Option as Meta key” enabled; the Karabiner
profile can configure this once in Terminal settings.

Inside Neo-tree, the keys match the VS Code Explorer: `y` copies, `p` pastes,
`d` cuts, `x` deletes, `r` renames, `n` creates a file, and `N` creates a
folder. Hidden, dot, ignored, and platform-hidden files are visible. File search
and grep include hidden working files while respecting ignore rules.

`Ctrl+B` on an SVG uses an adaptive Lua preview with a 2×4 Braille sample grid
per terminal cell, giving twice the former vertical detail without Python. The
preview grows with the terminal; `v` opens the original true vector externally.

Project files use Snacks' in-process Lua matcher on Windows, macOS, and Linux;
the external `fzf` process that caused the earlier memory failure is no longer
used. Its portable `fd` source is capped at 20,000 candidates and skips
dependency, cache, environment, coverage, and build directories. File previews
are size-bounded, while live grep stops at 2,000 results. Open-buffer switching
with `Space`, `,` never scans the filesystem.

Files changed by Git, a formatter, or another editor reload automatically when
Neovim regains focus, provided the local buffer has no unsaved edits. Modified
buffers are preserved and receive Neovim's normal conflict warning.

Explorer starts without a blank editor. The first selected file creates pane
`L`, and the second creates pane `R`. Later selections rotate between them: from
the right to the left, then from the left to the right. If a pane has no file,
it closes automatically. Modified unnamed content is retained to prevent data
loss. Directories still expand and collapse inside Explorer. Each editor pane
shows up to four local tabs in its own title bar; opening a fifth removes that
pane's oldest tab. A hidden, unmodified evicted buffer is closed automatically,
while a modified or still-visible buffer is retained in Neovim.
File movement never targets Explorer: `Ctrl+Alt+W` is a no-op in the left
editor pane, and `Ctrl+Alt+E` is a no-op in the right editor pane.
When a pane owns multiple files, its displayed filename uses a subtle accent
color and the hidden filenames remain muted. Pane-local file ownership is saved
with the workspace session and restored lazily without loading hidden files.

Markdownlint uses `.markdownlint-cli2.jsonc`, where `MD013` is disabled so
long prose, links, and tables do not produce line-length diagnostics.

### Native Neovim Keys to Learn

`<leader>` is the Space key. Press Space and pause to let WhichKey show the
available actions.

| Habit or operation | Stable Neovim/LazyVim key |
| --- | --- |
| Quick Open | `<leader><space>` |
| Recent files | `Ctrl+R` or `<leader>fr` |
| Workspaces | `<leader>fw` or `:Workspaces` |
| Pane tabs | `<leader><Tab>` then `Tab`, `[`, `]`, `1`–`4`, `f`, `l`, `d`, or `o` |
| Close current file, keep pane | `Ctrl+Q`, `<leader>wq`, or `<leader>bd` |
| Close current window/pane | `<leader>wQ` |
| Split right/below | `Ctrl+W v`, `Ctrl+W s` |
| Move left/down/up/right | `Ctrl+H/J/K/L` or `<leader>wh/wj/wk/wl` |
| Space window menu | `<leader>w`, then `h/j/k/l`, `s`, `v`, `w` (next), `W` (previous), or `=` |
| Close/equalize windows | `Ctrl+W c`, `Ctrl+W =` |
| Toggle current file/pane wide | `Ctrl+\` |
| Restore Explorer + file-backed panes | `<leader>wL` or `:WorkspaceLayout` |
| Undo/redo | `u`, `:redo` |
| Scroll half-page down/up | `Ctrl+D`, `Ctrl+U` |
| Comment line/selection | `gcc`, `gc` |
| Terminal | `<leader>ft` or `Ctrl+/` |
| Multi-cursor | `<leader>mc` |
| Run/build commands | `<leader>R…` |
| Definition under cursor | `gd`, `F12`, or `Ctrl+Enter` |

Run `:NvimTransition` inside Neovim for the personalized migration guide.
Run `:ShortcutHealth` to verify leader mappings, custom shortcuts, commands,
plugin modules, external tools, and clipboard support without changing files.
For behavioral regression checks, run:

```sh
nvim --headless "+luafile scripts/nvim_regression.lua"
```

The automatic Explorer workspace is deliberately limited to a clean `nvim`
start. It does not rearrange explicit file/directory opens, diffs, stdin, or
restored sessions. It never keeps a blank editor: file selections grow the
layout from Explorer-only to one and then two file panes. Bufferline is disabled
because one shared buffer row makes split ownership unclear; each window instead
owns a local four-tab row directly above it. `▸` marks the selected pane tab, `+`
marks unsaved changes, and the `L`/`R` badge identifies the editor group. The
workspace name appears only above Explorer, leaving each editor's file tabs on
the first screen row. Git roots are added automatically, while `:WorkspaceAdd`
saves a non-Git directory manually.

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

Automatic background update polling is disabled. Run `:Lazy check` when you
want to inspect available plugin updates.

Git and plugin installers inherit the standard `HTTPS_PROXY`, `HTTP_PROXY`, or
`ALL_PROXY` environment variables on every operating system. On macOS, Neovim
also discovers the enabled System Settings proxy before lazy.nvim starts. Use
`NVIM_NETWORK_PROXY` when an explicit per-Neovim override is needed. Certificate
verification is never disabled. The `:Lazy` interface retains the remote
configuration's centered dialog instead of taking over the complete grid.

Then restart Neovim.

Open a code file in standalone Neovim, then authorize GitHub Copilot once:

```vim
:LspCopilotSignIn
```

Follow the GitHub device-login prompt. The saved authorization is reused on
later starts; press `Tab` to accept an inline suggestion.

Copilot automatically uses `NVIM_COPILOT_PROXY`, then the standard HTTPS/HTTP
proxy variables. Keep credentials out of this repository and export the proxy
before starting Neovim, for example:

```bash
export NVIM_COPILOT_PROXY="http://proxy-host:port"
nvim .
```

Copilot receives a portable 512 MiB Node heap ceiling and a two-thread libuv
pool on Windows, macOS, and Linux. It is force-stopped when its Neovim session
closes and is not started by headless maintenance or regression commands. These
limits protect the system if the language server or proxy connection enters a
retry loop.

Run `:CopilotHealth` to confirm which route Copilot received. Copilot account
or network messages are notifications rather than modal prompts, so they can no
longer block directory startup.

On this SSH host, Neovim and VS Code Remote share the reachable client proxy at
`192.168.137.1:10808`. VS Code Remote proxy support is set to `override` in its
machine settings. If the client proxy address changes, update both
`NVIM_COPILOT_PROXY` in `~/.zshenv` and `http.proxy` in
`~/.vscode-server/data/Machine/settings.json`, then reload the VS Code window.

## VS Code

Install the extension:

```bash
code --install-extension asvetliakov.vscode-neovim
```

The workspace and user settings point VS Code at the shared-config entrypoint:

```text
C:\Program Files\Neovim\bin\nvim.exe
C:\Users\ahm_e\AppData\Local\nvim\init-vscode.lua
```

If `code` is not available, install the extension from the VS Code Extensions
view and reload the window.

Inside VSCode-Neovim, run `:VscodeParityHealth` to audit the generated Space
menu, every leader mapping, and the native discovery prefixes. If Space reports
that `whichkey.show` is missing, install `vspacecode.whichkey` and reload the VS
Code window.

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
