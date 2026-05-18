-- .NET profile.
-- Universal specs (conform, lspconfig, dap, treesitter base, nvim-tree base,
-- render-markdown, claude-code, tint) live in plugins/shared.lua.
return {
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

  -- Treesitter languages for the .NET profile
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "c_sharp", "fsharp", "xml", "json", "yaml", "markdown",
        "lua", "bash", "dockerfile", "sql"
      },
    },
  },

  -- NvimTree ignore patterns for .NET projects
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
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

  -- Azure Functions debugging support
  {
    "fschaal/azfunc.nvim",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    ft = { "cs" },
    config = function()
      require("azfunc").setup({
        mappings = {
          start = "<leader>as",  -- Azure Functions start
          stop = "<leader>aS",   -- Azure Functions stop
        },
      })
    end,
  },
}
