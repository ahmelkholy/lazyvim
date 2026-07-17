# VS Code to Neovim: Ahmed's Transition Guide

This configuration now chooses stability over copying every VS Code shortcut.
VS Code keeps your established keybindings. Standalone Neovim keeps native
motions and LazyVim conventions so plugins, help pages, and other Neovim setups
behave predictably.

## The One Rule

`<leader>` means Space. When you do not know a command, press Space and wait.
WhichKey will show the available groups and actions.

## Your Most Important Replacements

| Your VS Code instinct | Use in standalone Neovim | Why |
| --- | --- | --- |
| `Ctrl+P` Quick Open | `<leader><space>` | LazyVim file picker |
| `Ctrl+R` Recent | `<leader>fr` | `Ctrl+R` remains native redo |
| `Ctrl+Q` Close editor | `<leader>bd` | `Ctrl+Q` remains blockwise Visual mode |
| `Ctrl+W` Split right | `Ctrl+W v` or `<leader>\|` | `Ctrl+W` is Neovim's window prefix |
| `Ctrl+J` Toggle panel | `<leader>ft` or `Ctrl+/` | `Ctrl+J` moves to the lower split |
| `Ctrl+K` Save without format | `<leader>W` | `Ctrl+K` moves to the upper split |
| `Ctrl+L` New AI chat | `<leader>aa` | `Ctrl+L` moves right/redraws |
| `Ctrl+/` Comment | `gcc` or visual `gc` | LazyVim uses `Ctrl+/` for the terminal |
| `Ctrl+D` Add cursor | `<leader>mc` | `Ctrl+D` scrolls half a page down |
| `Ctrl+B` Run/build | `<leader>R…` | `Ctrl+B` scrolls a page backward |
| `Ctrl+Shift+B` New terminal | `Ctrl+Shift+B` | Safe; this one is retained |
| `Shift+Alt+F` Format | `Shift+Alt+F` or `<leader>cf` | Safe; this one is retained |
| `Ctrl+.` Quick fix | `Ctrl+.` or `<leader>ca` | Safe; this one is retained |
| `F12` Definition | `F12` or `gd` | Both are available |
| `Shift+F12` References | `Shift+F12` or `gr` | Both are available |

## Windows and Panes

On a bare `nvim` start, the config opens Explorer without a blank editor. The
first selected file creates pane `L`; the second creates pane `R`. A pane closes
automatically when it no longer has a file, except that modified unnamed content
is preserved for safety. Each file pane has its own title at the top, while the
bottom status line remains global. Opening a file, directory, diff, stdin stream,
or saved session keeps the layout requested on the command line.

Think of `Ctrl+W` as "window command", then press the action:

| Action | Key |
| --- | --- |
| Split right | `Ctrl+W v` |
| Split below | `Ctrl+W s` |
| Move left/down/up/right | `Ctrl+H/J/K/L` |
| Close current window | `Ctrl+W c` |
| Equalize sizes | `Ctrl+W =` |
| Maximize/restore | `<leader>wm` |
| Restore Explorer and file panes | `<leader>wL` or `:WorkspaceLayout` |

These navigation keys also cross tmux panes, so the same movement works inside
and outside Neovim splits.

The title above each pane is the ownership marker that VS Code normally provides
with editor-group tabs. Each editor pane holds up to four local tabs. `▸` marks
the selected tab, `+` marks unsaved changes, and the badge says `L` or `R`.
Opening a fifth file removes that pane's oldest tab. Modified or visible buffers
are kept safely loaded even when they leave the four-tab row.

## Workspaces

The top row lists opened workspaces as Neovim tab pages. Any folder containing
`.git` is detected and saved automatically when you open one of its files. Use
`<leader>fw` or `:Workspaces` for the VS Code-style workspace picker. Enter
switches to an open workspace or opens a saved one, `Ctrl+T` opens another
workspace tab, `Ctrl+A` saves the current directory, and `Ctrl+D` removes the
selected saved entry.

Use `<leader>wa` or `:WorkspaceAdd` to save a non-Git directory. Use
`<leader>wc` or `:WorkspaceClose` to close the current workspace. Native `gt`
and `gT` move to the next and previous opened workspace.

## Files, Buffers, and Search

| Action | Key |
| --- | --- |
| Files | `<leader><space>` |
| Recent files | `<leader>fr` |
| Text search | `<leader>/` |
| Open or focus Explorer | `Ctrl+Alt+D` |
| Toggle/close Explorer | `<leader>e`, `Ctrl+Shift+E`, or `Alt+F` |
| Next/previous tab in this pane | `Ctrl+Tab`, `Ctrl+Shift+Tab` |
| Next/previous buffer | `Shift+L`, `Shift+H` |
| Close current buffer | `<leader>bd` |
| Search in current file | `/`, then type and press Enter |
| Next/previous match | `n`, `N` |
| Search word under cursor | `*`, `#` |

Hidden, ignored, and dot files are visible in Neo-tree and included in file and
grep pickers. Inside Neo-tree, `y` copies, `p` pastes, `d` cuts, `x` deletes,
`r` renames, `n` creates a file, and `N` creates a directory.

Pressing Enter or double-clicking a file in an empty workspace creates pane `L`.
The next file creates pane `R`; later selections open in the opposite pane, so
they rotate between `L` and `R`. Each pane retains its previous files in its own
four-tab row. Selecting a directory expands or collapses it in Explorer instead
of replacing an editor.

## Editing Essentials

| Action | Key |
| --- | --- |
| Insert before cursor | `i` |
| Insert after cursor | `a` |
| Return to Normal mode | `Esc` |
| Character/line/block selection | `v`, `V`, `Ctrl+V` |
| Undo/redo | `u`, `Ctrl+R` |
| Repeat the last change | `.` |
| Copy/delete/paste | `y`, `d`, `p` |
| Comment line/selection | `gcc`, `gc` |
| Rename symbol | `<leader>cr` |
| Code action | `<leader>ca` |

## Running Code

Use the stable `<leader>R` group rather than changing `Ctrl+B` by file type.
Uppercase `R` avoids LazyVim's existing `<leader>r` refactoring group:

| Action | Key |
| --- | --- |
| Julia REPL/current file | `<leader>Rj`, `<leader>RJ` |
| Python REPL/current file | `<leader>Rp`, `<leader>RP` |
| Make/prompt for target | `<leader>Rm`, `<leader>RM` |
| Build and run C/C++ | `<leader>Rc`, `<leader>RC` |

## A Practical Learning Order

1. First week: learn modes, `hjkl`, `w`, `b`, `u`, `Ctrl+R`, and `.`.
2. Then learn files: `<leader><space>`, `<leader>/`, and `<leader>e`.
3. Then learn windows: `Ctrl+W v/s/c/=` and `Ctrl+H/J/K/L`.
4. Add language actions only when needed: `gd`, `gr`, `<leader>ca`, and
   `<leader>cr`.
5. Keep pressing Space and waiting instead of trying to memorize every leader
   command at once.

The goal is not to abandon your VS Code knowledge. It is to keep VS Code
familiar while giving standalone Neovim a coherent, transferable vocabulary.
