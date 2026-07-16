if vim.g.vscode then
  return {}
end

local function root()
  return LazyVim.root()
end

local function executable(name)
  local path = vim.fn.exepath(name)
  if path == "" then
    vim.notify(name .. " is not installed or is not on PATH", vim.log.levels.WARN)
    return nil
  end
  return path
end

local function current_file()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("The current buffer has no file path", vim.log.levels.WARN)
    return nil
  end
  vim.cmd.write()
  return path
end

local function python()
  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= "" then
    local suffix = vim.fn.has("win32") == 1 and "/Scripts/python.exe" or "/bin/python"
    local candidate = venv .. suffix
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  return executable(vim.fn.has("win32") == 1 and "python" or "python3")
end

local function terminal(argv)
  if argv and argv[1] then
    Snacks.terminal(argv, { cwd = root() })
  end
end

local function run_file(command, args)
  local command_path = executable(command)
  if not command_path then
    return
  end
  local file = current_file()
  if file then
    terminal(vim.list_extend({ command_path }, args(file)))
  end
end

local function compile_and_run(compiler)
  local compiler_path = executable(compiler)
  local file = current_file()
  if not compiler_path or not file then
    return
  end

  local output_dir = vim.fn.stdpath("cache") .. "/run"
  vim.fn.mkdir(output_dir, "p")
  local output = output_dir .. "/" .. vim.fn.fnamemodify(file, ":t:r")
  if vim.fn.has("win32") == 1 then
    output = output .. ".exe"
  end

  vim.system({ compiler_path, file, "-O0", "-g", "-Wall", "-Wextra", "-o", output }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local stderr = result.stderr or ""
        local stdout = result.stdout or ""
        local message = stderr ~= "" and stderr or stdout
        if message == "" then
          message = compiler .. " exited with code " .. result.code
        end
        vim.notify(message, vim.log.levels.ERROR, { title = compiler .. " failed" })
        return
      end
      terminal({ output })
    end)
  end)
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>R", "", desc = "+run" },
      {
        "<leader>Rj",
        function()
          local julia = executable("julia")
          terminal(julia and { julia, "--project=@." })
        end,
        desc = "Julia REPL",
      },
      {
        "<leader>RJ",
        function()
          run_file("julia", function(file)
            return { "--project=@.", file }
          end)
        end,
        desc = "Run Julia File",
        ft = "julia",
      },
      {
        "<leader>Rp",
        function()
          local python_path = python()
          terminal(python_path and { python_path })
        end,
        desc = "Python REPL",
      },
      {
        "<leader>RP",
        function()
          local python_path = python()
          local file = current_file()
          terminal(python_path and file and { python_path, file })
        end,
        desc = "Run Python File",
        ft = "python",
      },
      {
        "<leader>Rm",
        function()
          local make = executable("make")
          terminal(make and { make })
        end,
        desc = "Run Make",
      },
      {
        "<leader>RM",
        function()
          local make = executable("make")
          if make then
            local target = vim.fn.input("make target: ")
            terminal(target ~= "" and { make, target } or { make })
          end
        end,
        desc = "Run Make Target",
      },
      {
        "<leader>Rc",
        function()
          compile_and_run("gcc")
        end,
        desc = "Build and Run C File",
        ft = "c",
      },
      {
        "<leader>RC",
        function()
          compile_and_run("g++")
        end,
        desc = "Build and Run C++ File",
        ft = "cpp",
      },
    },
  },
}
