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

  -- Java Language Server
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    config = function()
      local jdtls = require('jdtls')
      local profile_manager = require('profile-manager')
      local home = os.getenv('HOME')
      local workspace_dir = home .. '/.cache/jdtls/workspace/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')

      -- Get OS-specific configuration directory name
      local config_name = profile_manager.get_config_dir_name()

      -- Find the jdtls launcher jar file
      local jdtls_install = home .. '/.local/share/nvim/mason/packages/jdtls'
      local launcher_jar = vim.fn.glob(jdtls_install .. '/plugins/org.eclipse.equinox.launcher_*.jar')
      if launcher_jar == '' then
        vim.notify('jdtls launcher jar not found', vim.log.levels.ERROR)
        return
      end

      -- Get default capabilities from NvChad
      local capabilities = require("nvchad.configs.lspconfig").capabilities

      -- Setup LSP keymaps on attach
      local on_attach = function(client, bufnr)
        -- Load NvChad's default LSP keymaps (includes gd, gr, K, etc.)
        require("nvchad.configs.lspconfig").on_attach(client, bufnr)

        -- Add any Java-specific keymaps here if needed
      end

      local config = {
        cmd = {
          'java',
          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
          '-Dlog.protocol=true',
          '-Dlog.level=ALL',
          '-Xms1g',
          '--add-modules=ALL-SYSTEM',
          '--add-opens', 'java.base/java.util=ALL-UNNAMED',
          '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
          '-jar', launcher_jar,
          '-configuration', jdtls_install .. '/' .. config_name,
          '-data', workspace_dir
        },
        root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle'}),
        settings = {
          java = {
            eclipse = {
              downloadSources = true,
            },
            configuration = {
              updateBuildConfiguration = "interactive",
            },
            maven = {
              downloadSources = true,
            },
            implementationsCodeLens = {
              enabled = true,
            },
            referencesCodeLens = {
              enabled = true,
            },
            references = {
              includeDecompiledSources = true,
            },
            format = {
              enabled = true,
            },
          },
          signatureHelp = { enabled = true },
          completion = {
            favoriteStaticMembers = {
              "org.hamcrest.MatcherAssert.assertThat",
              "org.hamcrest.Matchers.*",
              "org.hamcrest.CoreMatchers.*",
              "org.junit.jupiter.api.Assertions.*",
              "java.util.Objects.requireNonNull",
              "java.util.Objects.requireNonNullElse",
              "org.mockito.Mockito.*"
            }
          },
          contentProvider = { preferred = 'fernflower' },
          extendedClientCapabilities = jdtls.extendedClientCapabilities,
          sources = {
            organizeImports = {
              starThreshold = 9999,
              staticStarThreshold = 9999,
            }
          },
          codeGeneration = {
            toString = {
              template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
            },
            useBlocks = true,
          },
        },
        init_options = {
          bundles = {}
        },
        on_attach = on_attach,
        capabilities = capabilities,
      }
      jdtls.start_or_attach(config)
    end,
  },

  -- Testing support for Java
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "rcasia/neotest-java",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-java")({
            ignore_wrapper = false, -- whether to ignore maven/gradle wrapper
          }),
        },
      })
    end,
  },

  -- Enhanced Treesitter for Java
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "java", "kotlin", "groovy", "xml", "json", "yaml", "markdown",
        "lua", "bash", "dockerfile", "sql", "properties"
      },
      highlight = { enable = true },
      indent = { enable = true },
      fold = { enable = true },
    },
    build = ":TSUpdate",
  },

  -- NvimTree for Java projects
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
        custom = { 
          "^.git$", "^node_modules$", "^target$", "^build$", 
          "^.gradle$", "^.m2$", "^.idea$" 
        },
      },
    },
  },

  -- Enhanced snippets for Java
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
        patterns = { 
          ".git", "pom.xml", "build.gradle", "build.gradle.kts", 
          "settings.gradle", "gradlew", "mvnw" 
        },
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
          java = {
            template = {
              annotation_convention = "javadoc"
            }
          }
        }
      })
    end,
  },

  -- Maven/Gradle integration
  {
    "eatgrass/maven.nvim",
    cmd = { "Maven", "MavenExec" },
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require("maven").setup({
        executable = "./mvnw", -- Try wrapper first
      })
    end,
  },

  -- Spring Boot support
  {
    "JavaHello/spring-boot.nvim",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-jdtls",
      "ibhagwan/fzf-lua",
    },
    config = function()
      require("spring_boot").setup()
    end,
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
