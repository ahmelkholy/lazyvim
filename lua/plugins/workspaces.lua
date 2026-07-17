if vim.g.vscode then
  return {}
end

return {
  {
    "ahmedkhalf/project.nvim",
    opts = function(_, opts)
      opts.manual_mode = false
      opts.detection_methods = { "pattern" }
      opts.patterns = { ".git" }
      opts.scope_chdir = "tab"
    end,
  },
}
