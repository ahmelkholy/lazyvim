-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", ";", ":", { remap = true, desc = "Command mode" })

if vim.g.vscode then
  return
end

-- VS Code muscle-memory bridge for standalone Neovim. VS Code behavior wins
-- when the user's keybindings intentionally overlap with native Neovim keys.
local function toggle_explorer()
  vim.cmd("Neotree toggle reveal_force_cwd dir=" .. vim.fn.fnameescape(LazyVim.root()))
end

local function reveal_explorer()
  vim.cmd("Neotree reveal reveal_force_cwd dir=" .. vim.fn.fnameescape(LazyVim.root()))
end

local function terminal()
  Snacks.terminal.focus(nil, { cwd = LazyVim.root() })
end

local function new_terminal()
  vim.cmd("botright split | terminal")
end

local function cli_terminal(command)
  if vim.fn.executable(command) == 0 then
    vim.notify(command .. " is not installed or is not on PATH", vim.log.levels.WARN)
    return
  end
  Snacks.terminal({ command }, { cwd = LazyVim.root() })
end

local function copy_current_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("The current buffer has no file path", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)
  vim.notify("Copied: " .. path)
end

local function run_current_file(command, args)
  local executable = vim.fn.exepath(command)
  if executable == "" then
    vim.notify(command .. " is not installed or is not on PATH", vim.log.levels.WARN)
    return
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("The current buffer has no file path", vim.log.levels.WARN)
    return
  end

  vim.cmd.write()
  local argv = { executable }
  vim.list_extend(argv, args and args(path) or { path })
  Snacks.terminal(argv, { cwd = LazyVim.root() })
end

local function paste_terminal_clipboard()
  local channel = vim.b.terminal_job_id
  if channel then
    vim.api.nvim_chan_send(channel, vim.fn.getreg("+"))
  end
end

local function new_chat()
  local chat = require("CopilotChat")
  chat.reset()
  chat.open()
end

local function markdown_links()
  require("fzf-lua").live_grep({ search = [[\[\[]], prompt = "Markdown links> " })
end

local function daily_note()
  local directory = LazyVim.root() .. "/notes/daily"
  vim.fn.mkdir(directory, "p")
  vim.cmd.edit(vim.fn.fnameescape(directory .. "/" .. os.date("%Y-%m-%d") .. ".md"))
end

map("n", "<C-A-d>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<C-S-e>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<C-S-f>", toggle_explorer, { desc = "Toggle activity/sidebar" })
map("n", "<A-f>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<F2>", reveal_explorer, { desc = "Explorer: reveal active file" })

map("n", "<C-p>", LazyVim.pick("files"), { desc = "Quick Open: files" })
map("n", "<C-S-p>", "<cmd>FzfLua commands<cr>", { desc = "Command Palette" })
map("n", "<C-A-q>", LazyVim.pick("live_grep"), { desc = "Search: find in files" })

map("n", "<C-q>", function()
  Snacks.bufdelete()
end, { desc = "Close active editor" })
map("n", "<C-w>", "<cmd>vsplit<cr>", { desc = "Split editor right" })
map("n", "<C-Tab>", "<cmd>bnext<cr>", { desc = "Next editor" })
map("n", "<C-S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous editor" })
map("n", "<C-S-n>", "<cmd>tab split<cr>", { desc = "Move editor to new tab" })
map("n", "<S-A-q>", "<cmd>confirm qall<cr>", { desc = "Close Neovim" })
map("n", "<C-r>", LazyVim.pick("oldfiles"), { desc = "Open recent" })

map({ "n", "t" }, "<A-t>", terminal, { desc = "Toggle terminal" })
map({ "n", "t" }, "<C-A-b>", terminal, { desc = "Toggle terminal panel" })
map({ "n", "t" }, "<C-j>", terminal, { desc = "Toggle panel" })
map("n", "<A-b>", new_terminal, { desc = "New terminal" })
map({ "n", "t" }, "<C-S-b>", new_terminal, { desc = "New terminal" })

local function send_terminal_continuation()
  local channel = vim.b.terminal_job_id
  if channel then
    vim.api.nvim_chan_send(channel, "\\\n")
  end
end

map("t", "<S-CR>", send_terminal_continuation, { desc = "Terminal: continue command" })
map("t", "<C-CR>", send_terminal_continuation, { desc = "Terminal: continue command" })
map("t", "<C-v>", paste_terminal_clipboard, { desc = "Terminal: paste" })
map("t", "<C-S-v>", paste_terminal_clipboard, { desc = "Terminal: paste" })
map("t", "<A-Up>", [[<C-\><C-n><C-w>w]], { desc = "Terminal: focus next" })
map("t", "<A-Down>", [[<C-\><C-n><C-w>W]], { desc = "Terminal: focus previous" })

map({ "n", "x" }, "<S-A-f>", function()
  LazyVim.format({ force = true })
end, { desc = "Format document" })

map("n", "<S-A-2>", "<C-w>v", { remap = true, desc = "Split editor right" })
map("n", "<C-A-w>", "<C-w>H", { remap = true, desc = "Move editor group left" })
map("n", "<C-A-e>", "<C-w>L", { remap = true, desc = "Move editor group right" })
map("n", "<C-\\>", function()
  Snacks.zen.zoom()
end, { desc = "Toggle editor widths" })
map("n", "<C-A-t>", function()
  Snacks.zen.zoom()
end, { desc = "Toggle maximized panel" })
map("n", "<F11>", function()
  Snacks.zen()
end, { desc = "Toggle fullscreen / Zen mode" })
map("n", "<C-A-f>", function()
  require("aerial").toggle({ focus = false, direction = "right" })
end, { desc = "Toggle auxiliary sidebar" })

map("n", "<F12>", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "<S-F12>", vim.lsp.buf.references, { desc = "Go to references" })
map({ "n", "x" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Quick fix / code action" })

map("n", "<A-Left>", "<C-o>", { remap = true, desc = "Navigate back" })
map("n", "<A-Right>", "<C-i>", { remap = true, desc = "Navigate forward" })
map("n", "<C-A-g>", function()
  Snacks.lazygit({ cwd = LazyVim.root.git() })
end, { desc = "Source control" })
map("n", "<C-A-v>", "<cmd>FzfLua git_status<cr>", { desc = "Source control files" })
map("n", "<A-,>", function()
  require("gitsigns").nav_hunk("prev")
end, { desc = "Previous change" })
map("n", "<A-.>", function()
  require("gitsigns").nav_hunk("next")
end, { desc = "Next change" })
map("n", "<A-r>", function()
  require("gitsigns").preview_hunk()
end, { desc = "Preview change" })

map("n", "<A-d>", function()
  local path = vim.api.nvim_buf_get_name(0)
  vim.ui.open(path ~= "" and vim.fs.dirname(path) or LazyVim.root())
end, { desc = "Reveal file in system explorer" })
map("n", "<C-A-s>", copy_current_path, { desc = "Copy file path" })
map("n", "<C-A-p>", "<cmd>Lazy<cr>", { desc = "Package explorer" })
map("n", "<C-S-g>", markdown_links, { desc = "Markdown link graph" })
map("n", "<C-S-Left><Delete>", daily_note, { desc = "Open daily note" })

map("n", "<C-S-A-r>", function()
  vim.opt_local.rightleft = not vim.opt_local.rightleft:get()
end, { desc = "Toggle right-to-left display" })

map({ "n", "x" }, "<A-a>", "<leader>aa", { remap = true, desc = "AI chat" })
map({ "n", "x" }, "<C-A-a>", "<leader>aa", { remap = true, desc = "AI chat" })
map({ "n", "x" }, "<C-S-i>", "<leader>aq", { remap = true, desc = "AI quick chat" })
map({ "n", "x" }, "<S-A-a>", "<leader>ap", { remap = true, desc = "AI prompt actions" })
map({ "n", "x" }, "<C-A-c>", "<leader>aa", { remap = true, desc = "AI chat" })
map({ "n", "x" }, "<C-l>", new_chat, { desc = "AI: new chat" })
map("n", "<A-g>", function()
  cli_terminal("gemini")
end, { desc = "Gemini CLI" })
map("n", "<C-A-o>", function()
  cli_terminal("opencode")
end, { desc = "OpenCode CLI" })
map("n", "<C-A-x>", function()
  cli_terminal("claude")
end, { desc = "Claude CLI" })
map("n", "<S-A-b>", function()
  cli_terminal("matlab")
end, { desc = "MATLAB command window" })
map("n", "<C-A-n>", function()
  cli_terminal("matlab")
end, { desc = "MATLAB terminal" })

map("n", "<leader>W", "<cmd>noautocmd write<cr>", { desc = "Save without formatting" })
map("n", "<C-k>", "<cmd>noautocmd write<cr>", { desc = "Save without formatting" })
map("n", "<leader>ur", "<cmd>redo<cr>", { desc = "Redo" })

for _, lhs in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", lhs, "gcc", { remap = true, desc = "Toggle line comment" })
  map("x", lhs, "gc", { remap = true, desc = "Toggle selection comment" })
end

-- Keep window management available after Ctrl+W/Ctrl+J/K/L adopt VS Code behavior.
map("n", "<leader>wv", "<C-w>v", { remap = true, desc = "Window: split right" })
map("n", "<leader>ws", "<C-w>s", { remap = true, desc = "Window: split below" })
map("n", "<leader>wh", "<C-w>h", { remap = true, desc = "Window: left" })
map("n", "<leader>wj", "<C-w>j", { remap = true, desc = "Window: down" })
map("n", "<leader>wk", "<C-w>k", { remap = true, desc = "Window: up" })
map("n", "<leader>wl", "<C-w>l", { remap = true, desc = "Window: right" })
map("n", "<leader>wc", "<C-w>c", { remap = true, desc = "Window: close" })
map("n", "<leader>w=", "<C-w>=", { remap = true, desc = "Window: equalize" })

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("vscode_bridge_filetypes", { clear = true }),
  pattern = "*",
  callback = function(event)
    local ft = vim.bo[event.buf].filetype
    local opts = { buffer = event.buf }

    if ft == "markdown" then
      map("n", "<A-b>", "<cmd>MarkdownPreviewToggle<cr>", vim.tbl_extend("force", opts, { desc = "Markdown preview" }))
      map("n", "<C-b>", "<cmd>MarkdownPreviewToggle<cr>", vim.tbl_extend("force", opts, { desc = "Markdown preview" }))
    elseif ft == "python" then
      map("n", "<C-b>", function()
        run_current_file("python3")
      end, vim.tbl_extend("force", opts, { desc = "Run Python file" }))
    elseif ft == "julia" then
      map("n", "<C-b>", function()
        run_current_file("julia", function(path)
          return { "--project=@.", path }
        end)
      end, vim.tbl_extend("force", opts, { desc = "Run Julia file" }))
    elseif ft == "r" then
      map("n", "<C-b>", function()
        run_current_file("Rscript")
      end, vim.tbl_extend("force", opts, { desc = "Run R source" }))
    elseif ft == "tex" then
      map("n", "<C-b>", "<cmd>VimtexCompile<cr>", vim.tbl_extend("force", opts, { desc = "Build LaTeX" }))
    elseif ft == "html" then
      map("n", "<C-b>", function()
        vim.ui.open(vim.api.nvim_buf_get_name(event.buf))
      end, vim.tbl_extend("force", opts, { desc = "Open HTML in browser" }))
    elseif ft == "csv" then
      map("n", "<C-b>", function()
        vim.ui.open(vim.api.nvim_buf_get_name(event.buf))
      end, vim.tbl_extend("force", opts, { desc = "Open CSV externally" }))
    elseif ft == "matlab" then
      map("n", "<C-b>", function()
        run_current_file("matlab", function(path)
          return { "-batch", "run('" .. path:gsub("'", "''") .. "')" }
        end)
      end, vim.tbl_extend("force", opts, { desc = "Run MATLAB file" }))
    elseif ft == "copilot-chat" then
      map("n", "<A-.>", "<cmd>CopilotChatModels<cr>", vim.tbl_extend("force", opts, { desc = "AI model picker" }))
    end
  end,
})

-- Preserve the user's existing multi-cursor workflow.
map("n", "<C-d>", "<Plug>(VM-Find-Under)")
map("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)")
