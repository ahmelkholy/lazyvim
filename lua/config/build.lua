local M = {}

-- One context-sensitive build/run/preview action for both editor hosts. Commands
-- stay argv lists: Windows paths containing spaces never pass through a shell.
function M.root()
  return require("config.workspace").root() or vim.fn.getcwd()
end

function M.executable(name)
  local path = vim.fn.exepath(name)
  if path ~= "" then
    return path
  end
  vim.notify(name .. " is not installed or is not on PATH", vim.log.levels.WARN, { title = "Build / Run" })
end

function M.current_file()
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or path == "" or path:match("^%a[%w+.-]*://") then
    vim.notify("Save this buffer to a local file before building it", vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(vim.cmd.write)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Build / Run" })
    return
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

function M.python()
  local windows = vim.fn.has("win32") == 1
  for _, venv in ipairs({ vim.env.VIRTUAL_ENV or "", M.root() .. "/.venv", M.root() .. "/venv" }) do
    local path = venv .. (windows and "/Scripts/python.exe" or "/bin/python")
    if venv ~= "" and vim.fn.executable(path) == 1 then
      return path
    end
  end
  return M.executable(windows and "python" or "python3")
end

function M.terminal(argv, cwd)
  if argv and argv[1] then
    require("snacks").terminal(argv, { cwd = cwd or M.root() })
  end
end

function M.run_file(command, args, cwd)
  local executable = M.executable(command)
  if not executable then
    return
  end
  local file = M.current_file()
  if file then
    M.terminal(vim.list_extend({ executable }, args(file)), cwd)
  end
end

function M.compile_and_run(compiler)
  local executable = M.executable(compiler)
  local file = executable and M.current_file()
  if not file then
    return
  end
  local directory = vim.fn.stdpath("cache") .. "/run"
  vim.fn.mkdir(directory, "p")
  -- Include the full-path hash to avoid two projects overwriting a.out/name.exe.
  local output = directory .. "/" .. vim.fn.fnamemodify(file, ":t:r") .. "-" .. vim.fn.sha256(file):sub(1, 12)
  output = output .. (vim.fn.has("win32") == 1 and ".exe" or "")
  local cwd = M.root()
  vim.system(
    { executable, file, "-O0", "-g", "-Wall", "-Wextra", "-o", output },
    { text = true, cwd = cwd },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          local message = result.stderr or ""
          if message == "" then
            message = result.stdout or ""
          end
          if message == "" then
            message = compiler .. " exited with code " .. result.code
          end
          vim.notify(message, vim.log.levels.ERROR)
        else
          M.terminal({ output }, cwd)
        end
      end)
    end
  )
end

local native = {
  python = "python.execInTerminal",
  julia = "language-julia.executeActiveFile",
  r = "r.runSource",
  matlab = "matlab.runFile",
  tex = "latex-workshop.build",
  plaintex = "latex-workshop.build",
  latex = "latex-workshop.build",
  ["latex-expl3"] = "latex-workshop.build",
  doctex = "latex-workshop.build",
  rnoweb = "latex-workshop.build",
  rsweave = "latex-workshop.build",
  jlweave = "latex-workshop.build",
  pweave = "latex-workshop.build",
  markdown = "office.markdown.switch",
  csv = "edit-csv.edit",
  html = "simpleBrowser.show",
  htm = "simpleBrowser.show",
  c = "workbench.action.tasks.build",
  cpp = "workbench.action.tasks.build",
  svg = "svgeditor.openSvgEditor",
}

function M.kind()
  local path = vim.api.nvim_buf_get_name(0)
  return path:lower():match("%.svg$") and "svg" or vim.bo.filetype
end

function M.native_command(kind)
  return native[kind]
end

local function scroll_back()
  local sequence = (vim.v.count > 0 and tostring(vim.v.count) or "") .. "<C-b>"
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "n", false)
end

function M.run(opts)
  opts = opts or {}
  local kind = M.kind()
  local command = M.native_command(kind)
  if vim.g.vscode then
    if not command and opts.scroll then
      return scroll_back()
    end
    -- Use VS Code's existing language extensions and their project/interpreter
    -- settings instead of launching a second toolchain inside embedded Neovim.
    require("vscode").action(command or "workbench.action.tasks.build")
    return
  end
  if kind == "svg" then
    require("config.svg_preview").toggle()
  elseif kind == "python" then
    local executable = M.python()
    local file = executable and M.current_file()
    M.terminal(executable and file and { executable, file })
  elseif kind == "julia" then
    M.run_file("julia", function(file)
      return { "--project=@.", file }
    end)
  elseif kind == "r" then
    M.run_file("Rscript", function(file)
      return { file }
    end)
  elseif kind == "matlab" then
    M.run_file("matlab", function(file)
      return { "-batch", "run('" .. file:gsub("'", "''") .. "')" }
    end)
  elseif kind == "c" or kind == "cpp" then
    M.compile_and_run(kind == "c" and "gcc" or "g++")
  elseif command == "latex-workshop.build" then
    if vim.fn.exists(":VimtexCompile") == 2 then
      vim.cmd.VimtexCompile()
    else
      local executable = M.executable("latexmk")
      local file = executable and M.current_file()
      M.terminal(
        executable and file and { executable, "-pdf", "-interaction=nonstopmode", file },
        file and vim.fs.dirname(file)
      )
    end
  elseif kind == "markdown" then
    if vim.fn.exists(":MarkdownPreviewToggle") == 2 then
      vim.cmd.MarkdownPreviewToggle()
    else
      require("render-markdown").toggle()
    end
  elseif kind == "html" or kind == "htm" or kind == "csv" then
    local file = M.current_file()
    if file then
      vim.ui.open(file)
    end
  elseif opts.scroll then
    scroll_back()
  elseif vim.fn.filereadable(M.root() .. "/Makefile") == 1 then
    local executable = M.executable("make")
    M.terminal(executable and { executable })
  else
    vim.notify("No build action for " .. kind .. "; use Space R m for Make or a language run key", vim.log.levels.INFO)
  end
end

function M.setup()
  vim.keymap.set("n", "<C-b>", function()
    M.run({ scroll = true })
  end, { desc = "Build / Run / Preview current file", silent = true })
  vim.keymap.set("n", "<leader>RB", M.run, { desc = "Build / Run / Preview current file", silent = true })
end

return M
