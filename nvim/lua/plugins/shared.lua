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

  -- Formatting. Loads on BufWritePre so configs/conform.lua's format_on_save
  -- is registered before the first save. Without a trigger, conform only
  -- loaded on the first <leader>fm, and until then no save formatted anything,
  -- including the SQL that format_on_save exists for. `cmd` keeps :ConformInfo
  -- usable before any save.
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo" },
    opts = require "configs.conform",
  },

  -- Session persistence, scoped to the current directory — which, coming in
  -- through tmux-sessionizer, is the project root.
  --
  -- Saving is automatic on exit; restoring never is. That asymmetry is the
  -- point: an automatic restore would fire when opening a single file from
  -- anywhere and pull in whatever was last open under that directory. The
  -- dashboard's `s` and <leader>qs ask for it instead (see mappings.lua).
  --
  -- `event` rather than lazy-loading on those keys: the save autocmd has to be
  -- registered by the time you quit, and a session you never explicitly
  -- restored still needs to have been written.
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
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

  -- Mason: install the tools a profile needs, rather than relying on the user
  -- having run `:MasonInstall` by hand. LSP servers arrive via lspconfig, but
  -- DAP adapters have no equivalent — a missing one surfaces only as an ENOENT
  -- from nvim-dap at the moment you try to debug.
  --
  -- Same split as treesitter above: this spec owns the install logic, profiles
  -- supply `opts.ensure_installed`. Only one profile loads at a time, so that
  -- list still has exactly one source. NvChad declares mason with an `opts`
  -- *function*; lazy.nvim runs it first (it is the super spec) and merges this
  -- table over the result, so its settings survive.
  --
  -- `event` rather than NvChad's `cmd`: nothing would trigger the check if
  -- mason only loaded on `:Mason`.
  {
    "mason-org/mason.nvim",
    event = "VeryLazy",
    config = function(_, opts)
      require("mason").setup(opts)

      local registry = require "mason-registry"

      -- `is_installed` reads the install dir, so the common case (everything
      -- present) costs no network. Only refresh when something is missing.
      local missing = {}
      for _, pkg in ipairs(opts.ensure_installed or {}) do
        if not registry.is_installed(pkg) then
          table.insert(missing, pkg)
        end
      end

      if #missing == 0 then
        return
      end

      registry.refresh(function()
        for _, name in ipairs(missing) do
          local ok, pkg = pcall(registry.get_package, name)
          if ok and not pkg:is_installed() then
            vim.notify("mason: installing " .. name, vim.log.levels.INFO)
            pkg:install()
          end
        end
      end)
    end,
  },

  -- Treesitter (`main` branch — the post-rewrite plugin, required for Neovim
  -- 0.12). The old `master` branch is frozen for 0.11 and its
  -- `set-lang-from-info-string!` query directive crashes on 0.12, since
  -- directive handlers now receive a list of nodes per capture rather than a
  -- single TSNode.
  --
  -- `main` no longer has modules, so there is no `highlight`/`indent`/`fold`
  -- opts table. Those are Neovim features now and are enabled per-filetype in
  -- `autocmds.lua`. Only `ensure_installed` remains, which each profile
  -- supplies; NvChad's `:TSInstallAll` reads it off this spec.
  --
  -- `lazy = false` and no `event`: upstream states the plugin does not support
  -- lazy-loading.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    event = false,
    build = ":TSUpdate",
    config = function(_, opts)
      require("nvim-treesitter").setup()

      -- Install any configured parsers that aren't present yet. Async, so it
      -- won't block startup; a no-op once they're all installed.
      local installed = require("nvim-treesitter.config").get_installed "parsers"
      local present = {}
      for _, parser in ipairs(installed) do
        present[parser] = true
      end

      local missing = {}
      for _, parser in ipairs(opts.ensure_installed or {}) do
        if not present[parser] then
          table.insert(missing, parser)
        end
      end

      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end
    end,
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

  -- HTTP client. Runs `.http` files (the JetBrains/REST Client format) and
  -- shows the response in a split.
  --
  -- Three external requirements, all already in the package manifests:
  -- `curl` (fetches the kulala-core backend on first run), `git`, and
  -- `tree-sitter-cli`. The CLI is a hard requirement, not an optional extra —
  -- kulala ships its own `kulala_http` grammar and generates the parser
  -- locally rather than downloading a prebuilt one.
  --
  -- That grammar is deliberately kulala's own, so `treesitter.enable` is left
  -- at its default `true` and "http" stays OUT of nvim-treesitter's
  -- `ensure_installed` in the profile specs. The two parsers are different;
  -- installing nvim-treesitter's would only shadow kulala's queries.
  --
  -- `ft` is narrowed to http/rest. Upstream also lists javascript/typescript/
  -- lua so its LSP attaches to external `*.http.{js,ts,lua}` scripts, but
  -- those filetypes are far too broad to lazy-load on here — and by the time
  -- such a script is open, kulala has loaded from the `.http` file that
  -- references it.
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    -- Bodyless `keys` entries are lazy.nvim load triggers only; kulala
    -- installs the real mappings itself on setup, and the key is replayed
    -- against them.
    --
    -- This list is exactly kulala's five *unrestricted* global keymaps. The
    -- other ~16 carry `ft = { "http", "rest" }` in its keymap table, so they
    -- only ever exist in an http buffer — which `ft` above already covers.
    -- Listing one of those here would load the plugin on a keypress that then
    -- resolves to nothing.
    keys = {
      { "<leader>Ro", desc = "Kulala open" },
      { "<leader>Rb", desc = "Kulala scratchpad" },
      { "<leader>Rs", desc = "Kulala send request" },
      { "<leader>Ra", desc = "Kulala send all requests" },
      { "<leader>Rr", desc = "Kulala replay last request" },
    },
    opts = {
      -- Off upstream by default. Enabling it gives the full ~20-key set under
      -- `<leader>R`, which collides with nothing here — `<leader>r` is the
      -- test runner and `<leader>d` is DAP/dadbod.
      global_keymaps = true,
      global_keymaps_prefix = "<leader>R",
    },
  },
}
