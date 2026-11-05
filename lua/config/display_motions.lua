local M = {}

function M.setup()
  for key, label in pairs({ j = "Down", k = "Up" }) do
    vim.keymap.set({ "n", "x" }, key, function()
      -- Counts keep file-line navigation; operators such as dj stay native.
      return vim.v.count == 0 and ("g" .. key) or key
    end, {
      expr = true,
      remap = true, -- Embedded gj/gk must reach VS Code's actual wrapped lines.
      silent = true,
      desc = label .. " by display line (count: file lines)",
    })
  end
end

return M
