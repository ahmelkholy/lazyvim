return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      filter = function(mapping)
        return not (mapping.desc or ""):find("^Layout alias: ")
      end,
      spec = {
        { "<leader>g", group = "git / changes" },
        -- Replace LazyVim's nested "hunks" label with a direct Git menu.
        { "<leader>gh", hidden = true },
      },
    },
  },
}
