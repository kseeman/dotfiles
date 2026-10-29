-- Node profile: JavaScript/TypeScript.
-- Universal specs (conform, lspconfig, dap, treesitter base, nvim-tree base,
-- render-markdown, claude-code, tint) live in plugins/shared.lua.
--
-- Most of what this profile needs is already shared: `ts_ls` and `eslint` are
-- in configs/lspconfig.lua's server list, the `pwa-node` DAP adapter is in
-- configs/dap.lua, and prettierd is in configs/conform.lua (on save in this
-- profile only). This file adds the tools those expect, plus testing.
return {
  -- Testing support for JS/TS. vitest is listed first: neotest gives a file to
  -- the first adapter that claims it, and neotest-vitest only claims files in
  -- a project with vitest in its package.json, so jest gets everything else.
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-vitest"),
          require("neotest-jest")({}),
        },
      })
    end,
  },

  -- Mason tools for the Node profile. `js-debug-adapter` backs the `pwa-node`
  -- adapter in configs/dap.lua; `typescript-language-server` and `eslint-lsp`
  -- are the ts_ls and eslint servers configs/lspconfig.lua enables; `prettierd`
  -- backs conform. Servers are listed here, as in the python profile, so the
  -- profile works on first launch. See `plugins/shared.lua` for how this list
  -- is consumed.
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "js-debug-adapter", "typescript-language-server", "eslint-lsp", "prettierd",
      },
    },
  },

  -- Treesitter languages for the Node profile
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "javascript", "typescript", "tsx", "jsdoc", "json", "html", "css",
        "yaml", "markdown", "lua", "bash", "dockerfile", "sql"
      },
    },
  },

  -- NvimTree ignore patterns for Node projects
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      filters = {
        custom = {
          "^.git$", "^node_modules$", "^dist$", "^build$", "^coverage$",
          "^.next$", "^.turbo$"
        },
      },
    },
  },

  -- Enhanced snippets for JS/TS
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    build = "make install_jsregexp",
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        patterns = { ".git", "package.json" },
      })
    end,
  },

  -- Comments and documentation (JSDoc/TSDoc are neogen's defaults)
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require('neogen').setup({})
    end,
  },
}
