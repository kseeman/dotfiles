-- Default profile.
-- Universal specs (conform, lspconfig, dap, treesitter base, nvim-tree base,
-- render-markdown, claude-code, tint) live in plugins/shared.lua.
return {
  -- Java debugging (bare spec; the Java profile configures jdtls fully)
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },

  -- Treesitter languages for the default profile
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "java", "javascript", "typescript", "python", "lua", "json",
        "html", "css", "bash", "markdown", "yaml",
      },
    },
  },

  -- .NET Nuget Manager
  {
    "d7omdev/nuget.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = { "NugetInstall", "NugetUpdate", "NugetRemove", "NugetSearch" },
    config = function()
      require("nuget").setup()
    end,
  },
}
