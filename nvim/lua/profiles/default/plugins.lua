return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- Debug Adapter Protocol (DAP) for debugging
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require "configs.dap"
    end,
  },
  
  -- Java debugging
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },

  -- NvimTree configuration for large repositories
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      view = {
        width = function()
          return math.floor(vim.o.columns * 0.15)
        end,
      },
      git = {
        enable = true,
        timeout = 5000, -- Increase from 400ms to 5 seconds for large repos
        show_on_dirs = true,
        show_on_open_dirs = false,
      },
    },
  },

  -- Treesitter for language-aware folding
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "java", "javascript", "typescript", "python", "lua", "json",
        "html", "css", "bash", "markdown", "yaml"
      },
      highlight = { enable = true },
      indent = { enable = true },
      fold = { enable = true }, -- This enables Treesitter-based folding
    },
    build = ":TSUpdate",
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
  }
}