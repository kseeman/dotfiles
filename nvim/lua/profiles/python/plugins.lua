-- Python profile, with interactive Jupyter notebooks.
-- Universal specs (conform, lspconfig, dap, treesitter base, nvim-tree base,
-- render-markdown, image.nvim, claude-code, tint) live in plugins/shared.lua.
--
-- The notebook stack is molten-nvim (kernel + output), quarto-nvim/otter.nvim
-- (LSP and cell-aware running inside markdown code blocks) and jupytext.nvim
-- (.ipynb opened as markdown). Plot output renders through the shared
-- image.nvim spec.
--
-- molten is a Python *remote plugin*, which NvChad and this config both switch
-- off by default. The python profile turns them back on in two places:
-- `options.lua` (the python3 provider) and `configs/lazy.lua` (rplugin.vim).

-- The remote-plugin host runs from a dedicated venv, created by install.sh,
-- rather than whatever `python3` happens to be first on PATH — a project venv
-- without pynvim would otherwise break molten on entry. Set here at module
-- load, the same way shared.lua fixes up PATH, because the provider reads it
-- the first time the host starts.
local host_python = vim.fn.expand "~/.local/opt/nvim-python/bin/python"
if vim.fn.executable(host_python) == 1 then
  vim.g.python3_host_prog = host_python
end

return {
  -- Jupyter kernels. Output shows as virtual text under the cell, with images
  -- drawn by image.nvim.
  --
  -- `lazy = false` is deliberate. :UpdateRemotePlugins scans the runtimepath
  -- and rewrites the whole manifest, so running it while molten is not yet
  -- loaded silently drops every :Molten* command.
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    lazy = false,
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_auto_open_output = false
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
      -- Cells in markdown end on a ``` fence; this puts output below it.
      vim.g.molten_virt_lines_off_by_1 = true
    end,
    config = function()
      local map = vim.keymap.set

      map("n", "<leader>ji", "<cmd>MoltenInit<cr>", { desc = "Jupyter init kernel" })
      map("n", "<leader>jd", "<cmd>MoltenDeinit<cr>", { desc = "Jupyter stop kernel" })
      map("n", "<leader>jk", "<cmd>MoltenInterrupt<cr>", { desc = "Jupyter interrupt" })
      map("n", "<leader>jR", "<cmd>MoltenRestart!<cr>", { desc = "Jupyter restart kernel" })

      map("n", "<leader>je", "<cmd>MoltenEvaluateOperator<cr>", { desc = "Jupyter evaluate operator" })
      map("n", "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", { desc = "Jupyter evaluate line" })
      map("v", "<leader>je", ":<C-u>MoltenEvaluateVisual<cr>gv", { desc = "Jupyter evaluate selection" })
      map("n", "<leader>jr", "<cmd>MoltenReevaluateCell<cr>", { desc = "Jupyter re-run cell" })

      -- `noautocmd` stops the output window's BufEnter from immediately
      -- closing it again, per upstream.
      map("n", "<leader>jo", "<cmd>noautocmd MoltenEnterOutput<cr>", { desc = "Jupyter enter output" })
      map("n", "<leader>jh", "<cmd>MoltenHideOutput<cr>", { desc = "Jupyter hide output" })
      map("n", "<leader>jx", "<cmd>MoltenDelete<cr>", { desc = "Jupyter delete cell" })
      map("n", "<leader>jm", "<cmd>MoltenImagePopup<cr>", { desc = "Jupyter image popup" })
      map("n", "<leader>jn", "<cmd>MoltenNext<cr>", { desc = "Jupyter next cell" })
      map("n", "<leader>jp", "<cmd>MoltenPrev<cr>", { desc = "Jupyter previous cell" })
    end,
  },

  -- LSP, completion and cell-aware running inside markdown code blocks, which
  -- is what an .ipynb becomes once jupytext has converted it.
  --
  -- quarto sets no keymaps of its own. otter's LSP client picks up gd/K/etc.
  -- from NvChad's LspAttach autocmd like any other server.
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "markdown" },
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
      "benlubas/molten-nvim",
    },
    config = function()
      local quarto = require "quarto"

      quarto.setup {
        lspFeatures = {
          enabled = true,
          languages = { "python" },
          chunks = "all",
          diagnostics = { enabled = true, triggers = { "BufWritePost" } },
          completion = { enabled = true },
        },
        codeRunner = {
          enabled = true,
          default_method = "molten",
        },
      }

      local runner = require "quarto.runner"
      local map = vim.keymap.set

      map("n", "<leader>jc", runner.run_cell, { desc = "Jupyter run cell" })
      map("n", "<leader>ja", runner.run_above, { desc = "Jupyter run cells above" })
      map("n", "<leader>jA", runner.run_all, { desc = "Jupyter run all cells" })

      -- Activating is per-buffer. The buffer whose FileType loaded this plugin
      -- is covered too: after an ft-triggered load, lazy.nvim re-fires
      -- FileType for that buffer, which reaches this autocmd.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown", "quarto" },
        desc = "Activate quarto (otter LSP, cell runner) in markdown buffers",
        callback = function()
          quarto.activate()
        end,
      })
    end,
  },

  -- Opens .ipynb as markdown and writes it back as a notebook on save.
  -- Requires `jupytext` on PATH; install.sh links it into ~/.local/bin from
  -- the nvim-python venv.
  --
  -- `lazy = false` per upstream: it registers BufReadCmd for *.ipynb, which
  -- has to exist before the first notebook is opened.
  --
  -- The config patches around upstream issue #41: get_ipynb_metadata reads
  -- `metadata.kernelspec.language` unguarded, so opening a notebook with no
  -- kernelspec (made by `jupytext --to notebook`, or metadata-stripped) fails
  -- in BufReadCmd. Such notebooks fall back to the language jupytext recorded,
  -- then Jupyter's language_info, then python. Notebooks that have a
  -- kernelspec go through the original untouched. Delete this once #41 is
  -- fixed upstream.
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    config = function(_, opts)
      local utils = require "jupytext.utils"
      local get_ipynb_metadata = utils.get_ipynb_metadata

      -- Mirrors upstream's own table, which is local to utils.lua.
      local extensions = { python = "py", julia = "jl", r = "r", R = "r", bash = "sh" }

      utils.get_ipynb_metadata = function(filename)
        local file = io.open(filename, "r")
        local ok, notebook = pcall(vim.json.decode, file and file:read "a" or "")
        if file then
          file:close()
        end

        local metadata = ok and type(notebook) == "table" and notebook.metadata or {}
        if metadata.kernelspec then
          return get_ipynb_metadata(filename)
        end

        local language = (metadata.jupytext or {}).main_language
          or (metadata.language_info or {}).name
          or "python"

        return { language = language, extension = extensions[language] }
      end

      require("jupytext").setup(opts)

      -- Format notebook cells on save. conform's format_on_save never sees a
      -- notebook: jupytext saves through a buffer-local BufWriteCmd, Neovim
      -- sends no BufWritePre for writes a BufWriteCmd handles, and the
      -- handler's own inner :write runs without nested autocmds. Its write
      -- function is local to init.lua, so it cannot be patched like
      -- get_ipynb_metadata above. Instead, once jupytext has read a notebook
      -- and registered that handler, it is re-registered wrapped: format,
      -- then jupytext's own callback. The wrapper only ever exists where
      -- jupytext's handler does, so it can never claim a write jupytext
      -- would not have made. Defined after setup(), so this BufReadCmd runs
      -- after jupytext's.
      vim.api.nvim_create_autocmd("BufReadCmd", {
        pattern = "*.ipynb",
        group = vim.api.nvim_create_augroup("jupytext-format-on-save", { clear = true }),
        callback = function(ev)
          local handlers = vim.api.nvim_get_autocmds({ group = "jupytext-nvim", event = "BufWriteCmd", buffer = ev.buf })
          for _, handler in ipairs(handlers) do
            local write = handler.callback
            -- jupytext registers BufWriteCmd and FileWriteCmd in one call, so
            -- they share this id and deleting it drops both. FileWriteCmd
            -- (a partial write, e.g. :'<,'>w) is put back unwrapped.
            vim.api.nvim_del_autocmd(handler.id)
            vim.api.nvim_create_autocmd("FileWriteCmd", { buffer = ev.buf, group = "jupytext-nvim", callback = write })
            vim.api.nvim_create_autocmd("BufWriteCmd", {
              buffer = ev.buf,
              group = "jupytext-nvim",
              callback = function(write_ev)
                require("conform").format({ bufnr = write_ev.buf, timeout_ms = 2000, lsp_format = "never" })
                return write(write_ev)
              end,
            })
          end
        end,
      })
    end,
    opts = {
      style = "markdown",
      output_extension = "md",
      force_ft = "markdown",
    },
  },

  -- Python debugging. `debugpy-adapter` through `mason/bin`, not into the
  -- package's venv, for the same reason as netcoredbg in configs/dap.lua:
  -- `mason/bin` is the stable name.
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-python").setup(vim.fn.stdpath "data" .. "/mason/bin/debugpy-adapter")
    end,
  },

  -- Testing support for Python. neotest-python finds the project venv itself.
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            runner = "pytest",
          }),
        },
      })
    end,
  },

  -- Mason tools for the Python profile. `debugpy` backs nvim-dap-python above;
  -- `pyright` and `ruff` are the servers configs/lspconfig.lua enables (ruff
  -- also backs conform's ruff_format). Listing the servers here departs from
  -- the other profiles, which leave theirs to a manual :MasonInstall, so the
  -- profile works on first launch. See `plugins/shared.lua` for how this list
  -- is consumed.
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "debugpy", "pyright", "ruff" },
    },
  },

  -- Treesitter languages for the Python profile. markdown_inline is needed by
  -- quarto/otter to find code cells in converted notebooks.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "python", "markdown", "markdown_inline", "json", "yaml", "toml",
        "lua", "bash", "dockerfile", "sql", "csv"
      },
    },
  },

  -- NvimTree ignore patterns for Python projects
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      filters = {
        custom = {
          "^.git$", "^node_modules$", "^__pycache__$", "^.venv$",
          "^.mypy_cache$", "^.pytest_cache$", "^.ruff_cache$",
          "^.ipynb_checkpoints$"
        },
      },
    },
  },

  -- Enhanced snippets for Python
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
          ".git", "pyproject.toml", "setup.py", "setup.cfg",
          "requirements.txt", "Pipfile"
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
          python = {
            template = {
              annotation_convention = "google_docstrings"
            }
          }
        }
      })
    end,
  },
}
