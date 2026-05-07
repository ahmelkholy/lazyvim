# VS Code Neovim LazyVim Config

This is a public Neovim configuration for people who want Vim/Neovim editing inside
Visual Studio Code.

This branch is VS Code-first. It is not meant to be a full standalone Neovim
distribution. VS Code keeps handling the editor UI, file explorer, tabs, search,
LSP, completion, Git UI, and extensions. Neovim handles modal editing, Lua
keymaps, motions, operators, and the parts of LazyVim that work well inside the
[VSCode Neovim](https://github.com/vscode-neovim/vscode-neovim) extension.

## Status

- Branch: `windows`
- Main target: Windows + VS Code + VSCode Neovim
- Base: [LazyVim](https://www.lazyvim.org/)
- Neovim outside VS Code may start, but it is not the main supported workflow.

## What This Config Does

- Enables the LazyVim VS Code extra.
- Uses `vim.g.vscode` checks so VS Code-specific behavior only loads inside VS Code.
- Disables UI-heavy plugins in VS Code, including dashboard, bufferline, neo-tree,
  noice, lualine, trouble, and similar plugins.
- Disables Treesitter because VS Code already owns syntax highlighting here.
- Keeps wrapping and linebreak enabled.
- Uses PowerShell (`pwsh`) as the Neovim shell on Windows.
- Maps `;` to `:` in normal mode.
- Keeps `vim-visual-multi` for regular Neovim only, while VS Code handles its own
  multi-cursor behavior.

## Requirements

Install these first:

- [Visual Studio Code](https://code.visualstudio.com/)
- [Neovim 0.10.0 or newer](https://neovim.io/doc/install/)
- [Git](https://git-scm.com/)
- [VSCode Neovim extension](https://marketplace.visualstudio.com/items?itemName=asvetliakov.vscode-neovim)

Optional but recommended:

- A Nerd Font if you use icons in your VS Code theme or terminal.
- PowerShell 7, because this config sets `vim.opt.shell = "pwsh"`.

## Install On Windows

Back up your existing Neovim config first if you already have one:

```powershell
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (Test-Path "$env:LOCALAPPDATA\nvim") {
  Rename-Item -Path "$env:LOCALAPPDATA\nvim" -NewName "nvim.backup.$stamp"
}
```

Install Neovim:

```powershell
winget install Neovim.Neovim
```

Install the VSCode Neovim extension:

```powershell
code --install-extension asvetliakov.vscode-neovim
```

If the `code` command is not available, open VS Code, go to Extensions, and
install `VSCode Neovim` by `asvetliakov`.

Clone this branch into the standard Windows Neovim config folder:

```powershell
git clone -b windows https://github.com/ahmelkholy/lazyvim.git "$env:LOCALAPPDATA\nvim"
```

Start Neovim once from a terminal so Lazy can install plugins:

```powershell
nvim
```

When Neovim opens, wait for Lazy to finish installing plugins. If needed, run:

```vim
:Lazy sync
```

Then quit Neovim:

```vim
:qa
```

## Connect It To VS Code

The VSCode Neovim extension reads your normal Neovim config from:

```text
%LOCALAPPDATA%\nvim\init.lua
```

After cloning this repo there, VS Code should find the config automatically if
`nvim` is available on your `PATH`.

If VS Code cannot find Neovim, open VS Code settings JSON:

1. Open the Command Palette.
2. Run `Preferences: Open User Settings (JSON)`.
3. Add the Windows Neovim executable path:

```json
{
  "vscode-neovim.neovimExecutablePaths.win32": "C:\\Program Files\\Neovim\\bin\\nvim.exe"
}
```

If your Neovim path is different, find it with:

```powershell
where.exe nvim
```

Then restart the extension:

1. Open the Command Palette.
2. Run `Neovim: Restart Extension`.

You can also run `Developer: Reload Window` if the extension still does not pick
up the config.

## Check That It Works

Open a file in VS Code and try these:

- Press `Esc`, then use normal-mode motions like `h`, `j`, `k`, `l`, `w`, `b`.
- Press `;` and confirm it opens the Neovim command line.
- Run this command from Neovim command mode:

```vim
:echo g:vscode
```

It should print `1` when Neovim is running inside VS Code.

## Updating

Pull the latest changes and sync plugins:

```powershell
cd "$env:LOCALAPPDATA\nvim"
git pull
nvim
```

Inside Neovim:

```vim
:Lazy sync
```

Restart VS Code after updating if the extension was already running.

## Troubleshooting

### VS Code says it cannot find Neovim

Run:

```powershell
where.exe nvim
```

Copy the full path into:

```json
{
  "vscode-neovim.neovimExecutablePaths.win32": "C:\\Path\\To\\nvim.exe"
}
```

Then run `Neovim: Restart Extension` from the Command Palette.

### Keybindings do not work

Make sure you are using `VSCode Neovim`, not the separate `Vim` extension. If
`VSCodeVim` is installed, disable it for this workspace to avoid conflicts.

### The extension starts without this config

Check that the repo was cloned to:

```text
%LOCALAPPDATA%\nvim
```

Also check that `init.lua` exists directly inside that folder:

```text
%LOCALAPPDATA%\nvim\init.lua
```

### Plugins behave strangely inside VS Code

This config intentionally disables plugins that fight with VS Code's UI. If you
add new plugins later, prefer plugins for motions, text objects, editing, and
small Lua helpers. Avoid plugins that create custom UI windows, file trees,
status lines, dashboards, completion menus, or syntax highlighting inside VS
Code.

### I want normal Neovim, not VS Code

This branch is not focused on that use case. You can still fork it and remove the
VS Code-specific choices, but the public goal of this branch is to help people
use Neovim through VS Code.

## Contributing

Issues and pull requests are welcome, especially for:

- clearer Windows installation steps
- VS Code compatibility fixes
- better keymaps for VSCode Neovim
- documentation improvements for new users

Please keep changes friendly to the VS Code workflow.

## License

This project is released under the Apache License 2.0. See [LICENSE](LICENSE).
