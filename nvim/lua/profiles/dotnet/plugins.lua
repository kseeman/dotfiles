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
      "mason-org/mason.nvim",
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

  -- Mason tools for the .NET profile. `netcoredbg` backs the `coreclr` DAP
  -- adapter in `configs/dap.lua` — neotest-dotnet and azfunc.nvim both launch
  -- through it, and neither can install it. See `plugins/shared.lua` for how
  -- this list is consumed.
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "netcoredbg" },
    },
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

  -- Azure Functions debugging support.
  --
  -- Loaded on key/command rather than `ft = { "cs" }`. Nothing in azfunc.nvim
  -- reads the current buffer, so the filetype trigger was the only reason
  -- `<leader>as` required a C# file to be open — lazy.nvim simply had not
  -- loaded the plugin yet, so the mapping did not exist. `keys` stubs it until
  -- first press, which costs no startup time and works from any buffer.
  --
  -- `mappings = false` because the keys are declared here instead: lazy needs
  -- the names in the spec to build the stubs, and letting the plugin bind them
  -- too would define each key in two places. They route through
  -- `configs.azfunc`, which searches from the git root rather than the cwd.
  {
    "fschaal/azfunc.nvim",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    cmd = { "AzFuncStart", "AzFuncStop", "AzFuncList" },
    keys = {
      {
        "<leader>as",
        function()
          require("configs.azfunc").start()
        end,
        desc = "Azure Functions start",
      },
      {
        "<leader>aS",
        function()
          require("configs.azfunc").stop()
        end,
        desc = "Azure Functions stop",
      },
    },
    config = function()
      require("azfunc").setup({
        mappings = false,
      })
    end,
  },
}
