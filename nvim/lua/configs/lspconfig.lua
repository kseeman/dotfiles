require("nvchad.configs.lspconfig").defaults()

-- Manual LSP Document Highlighting with keymap
local function setup_lsp_keymaps(client, bufnr)
  if client.server_capabilities.documentHighlightProvider then
    -- Manual toggle for LSP reference highlighting
    vim.keymap.set("n", "<leader>*", function()
      if vim.b.lsp_refs_active then
        vim.lsp.buf.clear_references()
        vim.b.lsp_refs_active = false
      else
        vim.lsp.buf.document_highlight()
        vim.b.lsp_refs_active = true
      end
    end, { buffer = bufnr, desc = "Toggle LSP reference highlights" })
    
    -- Optional: Clear on cursor movement for slight automation
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = bufnr,
      callback = function()
        if vim.b.lsp_refs_active then
          vim.lsp.buf.clear_references()
          vim.b.lsp_refs_active = false
        end
      end,
    })
  end
end

-- Custom on_attach function
local on_attach = function(client, bufnr)
  -- First call NvChad's default on_attach to set up standard LSP keymaps (gd, gr, K, etc.)
  require("nvchad.configs.lspconfig").on_attach(client, bufnr)

  -- Then setup our custom manual highlighting keymaps
  setup_lsp_keymaps(client, bufnr)
end

-- Note: jdtls is NOT included here because nvim-jdtls plugin manages it separately
local servers = { "html", "cssls", "omnisharp", "ts_ls", "js_ls", "clangd", "pyright", "ruff" }

-- Configure each server with on_attach
for _, server in ipairs(servers) do
  vim.lsp.config(server, {
    on_attach = on_attach,
  })
end

-- ruff and pyright both answer hover, which stacks two windows on `K`. ruff's
-- is only lint-rule docs, so it steps aside, as ruff's own docs recommend.
vim.lsp.config("ruff", {
  on_attach = function(client, bufnr)
    client.server_capabilities.hoverProvider = false
    on_attach(client, bufnr)
  end,
})

-- pyright checks imports against whatever `python` is first on PATH, which is
-- the system one unless a venv was activated before nvim started. A project's
-- .venv (or venv) at the root pyright picked is used instead, so its packages
-- resolve without activating anything; the same lookup the test runner does.
-- An activated venv ($VIRTUAL_ENV) is left alone, since that choice was
-- deliberate, and a pyrightconfig.json/[tool.pyright] venv still wins inside
-- pyright itself. Otherwise nothing changes.
--
-- The settings table is mutated in place, not replaced as the before_init
-- example in :h vim.lsp.ClientConfig does. The client captured a reference to
-- it when it was created, and answers pyright's workspace/configuration
-- request from that reference, so a new table is never seen. lspconfig's
-- pyright config always supplies `settings`.
vim.lsp.config("pyright", {
  before_init = function(_, config)
    if vim.env.VIRTUAL_ENV then
      return
    end

    local root = config.root_dir or vim.fn.getcwd()
    for _, venv in ipairs({ ".venv", "venv" }) do
      local python = root .. "/" .. venv .. "/bin/python"
      if vim.fn.executable(python) == 1 then
        config.settings.python = config.settings.python or {}
        config.settings.python.pythonPath = python
        return
      end
    end
  end,
})

vim.lsp.enable(servers)

-- Style the highlight groups
vim.api.nvim_set_hl(0, "LspReferenceText", { underline = true, bg = "#3c3836" })
vim.api.nvim_set_hl(0, "LspReferenceRead", { underline = true, bg = "#458588" })
vim.api.nvim_set_hl(0, "LspReferenceWrite", { underline = true, bg = "#cc241d" })

-- read :h vim.lsp.config for changing options of lsp servers
