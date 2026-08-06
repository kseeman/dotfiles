require "nvchad.autocmds"

-- Automatically resize windows when Neovim is resized
vim.api.nvim_create_autocmd("VimResized", {
  pattern = "*",
  command = "wincmd =",
  desc = "Resize windows automatically when Neovim is resized"
})

-- Treesitter indentation.
--
-- nvim-treesitter's `main` branch dropped the modules system, so
-- `opts.indent = { enable = true }` no longer exists. Indentation is still
-- provided by the plugin (upstream considers it experimental) and must be
-- opted into per-buffer via `indentexpr`.
--
-- Highlighting is handled by NvChad's own FileType autocmd (`vim.treesitter.start`)
-- and folding by the global `foldexpr` in options.lua, so neither is repeated here.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  desc = "Enable treesitter indentation where a parser is available",
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if not lang or not pcall(vim.treesitter.language.add, lang) then
      return
    end

    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
