-- Plugins shared across ALL profiles (default, dotnet, java).
-- Imported once from init.lua so they aren't duplicated per profile.
--
-- Profiles may still add a *minimal* override spec for treesitter
-- (`opts.ensure_installed`) and nvim-tree (`opts.filters`). Those keys are
-- disjoint from the common ones set here, so lazy.nvim merges the fragments
-- cleanly (no list is ever merged from two sources).
return {
  -- Dim inactive windows/splits.
  {
    "levouh/tint.nvim",
    event = "VeryLazy",
    config = function()
      require "configs.tint"
    end,
  },

  -- Formatting
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- LSP
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

  -- Treesitter: common settings. Each profile supplies its own
  -- `opts.ensure_installed` list (disjoint from these keys).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      highlight = { enable = true },
      indent = { enable = true },
      fold = { enable = true },
    },
    build = ":TSUpdate",
  },

  -- NvimTree: common view/git settings. Profiles may add
  -- `opts.filters.custom` (disjoint from these keys).
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

  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = "markdown",
    opts = {},
  },

  -- Claude Code integration
  {
    "greggh/claude-code.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeContinue", "ClaudeCodeResume", "ClaudeCodeVerbose" },
    keys = { { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" } },
    opts = {},
  },
}
