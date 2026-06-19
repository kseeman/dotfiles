-- Plugins shared across ALL profiles (default, dotnet, java).
-- Imported once from init.lua so they aren't duplicated per profile.
--
-- Profiles may still add a *minimal* override spec for treesitter
-- (`opts.ensure_installed`) and nvim-tree (`opts.filters`). Those keys are
-- disjoint from the common ones set here, so lazy.nvim merges the fragments
-- cleanly (no list is ever merged from two sources).

-- Make nvm-installed node binaries discoverable to plugins that shell out
-- (mermaider.nvim, diagram.nvim, etc.). Many shells lazy-load nvm, so
-- nvim's inherited $PATH lacks the node bin dir at launch. The same
-- `~/.nvm/versions/node/<v>/bin` layout is used on macOS and Linux.
if vim.fn.exepath("mmdc") == "" then
  local matches = vim.fn.glob(vim.fn.expand("$HOME/.nvm/versions/node/*/bin"), false, true)
  if #matches > 0 then
    vim.env.PATH = matches[#matches] .. ":" .. vim.env.PATH
  end
end

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
        preserve_window_proportions = true,
      },
      actions = {
        open_file = {
          resize_window = false,
        },
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

  -- Mermaid diagram rendering. Requires `mmdc` (npm i -g
  -- @mermaid-js/mermaid-cli) and a terminal with Kitty graphics or Sixel
  -- support. The `magick` luarocks dep is built via lazy.nvim's hererocks
  -- (see configs/lazy.lua).
  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
      },
      max_width = nil,
      max_height = nil,
      max_width_window_percentage = nil,
      max_height_window_percentage = 50,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },

  -- Standalone .mmd / .mermaid file rendering. Using lancekrogers's fork
  -- of snrogers/mermaider.nvim, which fixes the upstream `utils.log_error`
  -- crash and image.nvim integration bugs.
  {
    "lancekrogers/mermaider.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "mermaid", "mmd" },
    config = function(_, opts)
      -- Silence the plugin's hardcoded `debug_mode = true` flag and stub
      -- log_debug entirely. Every log_debug() in upstream becomes a
      -- vim.notify, which forces "Press ENTER" prompts on small windows.
      local utils = require("mermaider.utils")
      utils.debug_mode = false
      utils.log_debug = function(_) end
      require("mermaider").setup(opts)
    end,
    opts = {
      -- The plugin substitutes {{IN_FILE}} (with .mmd) and {{OUT_FILE}}
      -- (without extension); we must append `.png` so mmdc accepts it.
      mermaider_cmd = "mmdc -i {{IN_FILE}} -o {{OUT_FILE}}.png",
      mmdc_options = "-s 3",
      theme = "forest",
      background_color = "#1e1e2e",
      auto_render = true,
      -- Disabled: the BufEnter autocmd fires before Neovim populates the
      -- buffer from disk, so mermaider hashes an empty buffer and feeds
      -- 0 bytes to mmdc on first open. Render fires on save instead.
      auto_render_on_open = false,
      auto_preview = true,
      -- Inline render anchors the image past EOF on small diagrams and
      -- spams E966 "Invalid line number" errors. Split-window preview
      -- avoids the row-arithmetic entirely.
      inline_render = false,
      temp_dir = vim.fn.expand("$HOME/.cache/mermaider"),
    },
  },

  -- Mermaid (and d2/plantuml/gnuplot) diagrams inside markdown fenced
  -- blocks. By the same author as image.nvim. Renders inline; no default
  -- keymap, but `:lua require("diagram").show_diagram_hover()` opens a
  -- preview tab for the diagram under the cursor.
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown", "norg" },
    opts = function()
      return {
        integrations = {
          require("diagram.integrations.markdown"),
        },
        renderer_options = {
          mermaid = {
            theme = "forest",
            background = "#1e1e2e",
            scale = 3,
          },
        },
      }
    end,
  },

  -- Claude Code integration
  {
    "greggh/claude-code.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeContinue", "ClaudeCodeResume", "ClaudeCodeVerbose" },
    keys = { { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" } },
    opts = {},
  },

  -- Database client (vim-dadbod + UI + completion)
  {
    "tpope/vim-dadbod",
    cmd = "DB",
    lazy = true,
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = { "tpope/vim-dadbod" },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    keys = { { "<leader>du", "<cmd>DBUIToggle<cr>", desc = "Toggle DB UI" } },
  },
  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = { "tpope/vim-dadbod" },
    ft = { "sql", "mysql", "plsql" },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          vim.schedule(function()
            local ok, cmp = pcall(require, "cmp")
            if ok then
              cmp.setup.buffer({
                sources = {
                  { name = "vim-dadbod-completion" },
                  { name = "buffer" },
                },
              })
            end
          end)
        end,
      })
    end,
  },
}
