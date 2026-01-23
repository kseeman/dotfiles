require "nvchad.autocmds"

-- Automatically resize windows when Neovim is resized
vim.api.nvim_create_autocmd("VimResized", {
  pattern = "*",
  command = "wincmd =",
  desc = "Resize windows automatically when Neovim is resized"
})
