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

Think of `Ctrl+W` as "window command", then press the action:

| Action | Key |
| --- | --- |
| Split right | `Ctrl+W v` |
| Split below | `Ctrl+W s` |
| Move left/down/up/right | `Ctrl+H/J/K/L` |
| Close current window | `Ctrl+W c` |
| Equalize sizes | `Ctrl+W =` |
| Maximize/restore | `<leader>wm` |

These navigation keys also cross tmux panes, so the same movement works inside
and outside Neovim splits.

## Files, Buffers, and Search

| Action | Key |
| --- | --- |
| Files | `<leader><space>` |
| Recent files | `<leader>fr` |
| Text search | `<leader>/` |
| Explorer | `<leader>e` or `Ctrl+Alt+D` |
| Next/previous buffer | `Shift+L`, `Shift+H` |
| Close current buffer | `<leader>bd` |
| Search in current file | `/`, then type and press Enter |
| Next/previous match | `n`, `N` |
| Search word under cursor | `*`, `#` |

Hidden, ignored, and dot files are visible in Neo-tree and included in file and
grep pickers. Inside Neo-tree, `y` copies, `p` pastes, `d` cuts, `x` deletes,
`r` renames, `n` creates a file, and `N` creates a directory.

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
