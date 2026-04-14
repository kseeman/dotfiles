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
local servers = { "html", "cssls", "omnisharp", "ts_ls", "js_ls", "clangd" }

-- Configure each server with on_attach
for _, server in ipairs(servers) do
  vim.lsp.config(server, {
    on_attach = on_attach,
  })
end

vim.lsp.enable(servers)

-- Style the highlight groups
vim.api.nvim_set_hl(0, "LspReferenceText", { underline = true, bg = "#3c3836" })
vim.api.nvim_set_hl(0, "LspReferenceRead", { underline = true, bg = "#458588" })
vim.api.nvim_set_hl(0, "LspReferenceWrite", { underline = true, bg = "#cc241d" })

-- read :h vim.lsp.config for changing options of lsp servers
