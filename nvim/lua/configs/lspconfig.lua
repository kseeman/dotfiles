require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "omnisharp", "ts_ls", "js_ls", "jdtls", "clangd" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
