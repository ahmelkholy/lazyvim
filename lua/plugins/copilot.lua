return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      require("config.copilot").setup()
    end,
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.copilot =
        vim.tbl_deep_extend("force", opts.servers.copilot or {}, require("config.copilot").server_options())
    end,
  },
}
