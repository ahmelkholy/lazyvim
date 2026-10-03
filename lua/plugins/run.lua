if vim.g.vscode then
  return {}
end

local build = require("config.build")
local executable = build.executable
local current_file = build.current_file
local python = build.python
local terminal = build.terminal
local run_file = build.run_file
local compile_and_run = build.compile_and_run

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
