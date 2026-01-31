return {
  -- Base formatting and LSP
  {
    "stevearc/conform.nvim",
    opts = require "configs.conform",
  },

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

  -- .NET specific plugins
  {
    "Hoffs/omnisharp-extended-lsp.nvim",
    ft = { "cs", "vb" },
  },

  {
    "iabdelkareem/csharp.nvim",
    dependencies = {
      "williamboman/mason.nvim", 
      "mfussenegger/nvim-dap",
      "Tastyep/structlog.nvim",
    },
    ft = { "cs" },
    config = function()
      require("csharp").setup({
        -- LSP settings
        lsp = {
          omnisharp = {
            enable_roslyn_analyzers = true,
            enable_import_completion = true,
            organize_imports_on_format = true,
            enable_decompilation_support = true,
          },
        },
      })
    end,
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

  -- Testing support for .NET
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "Issafalcon/neotest-dotnet",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-dotnet")({
            dap = {
              adapter_name = "netcoredbg",
            },
          }),
        },
      })
    end,
  },

  -- Enhanced Treesitter for .NET languages
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "c_sharp", "fsharp", "xml", "json", "yaml", "markdown",
        "lua", "bash", "dockerfile", "sql"
      },
      highlight = { enable = true },
      indent = { enable = true },
      fold = { enable = true },
    },
    build = ":TSUpdate",
  },

  -- NvimTree for .NET projects
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
        timeout = 5000,
        show_on_dirs = true,
        show_on_open_dirs = false,
      },
      filters = {
        custom = { "^.git$", "^node_modules$", "^bin$", "^obj$" },
      },
    },
  },

  -- Enhanced snippets for C#
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
        patterns = { ".git", "*.sln", "*.csproj", "*.fsproj", "package.json" },
      })
    end,
  },

  -- Comments and documentation
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require('neogen').setup({
        languages = {
          cs = {
            template = {
              annotation_convention = "xmldoc"
            }
          }
        }
      })
    end,
  },
}