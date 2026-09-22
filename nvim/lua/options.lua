require "nvchad.options"

-- add yours here!

local o = vim.o
o.relativenumber = true
o.number = true
o.scrolloff = 8

-- Folding options - Language-aware Treesitter folding
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldcolumn = "1"       -- Show fold indicators in gutter
o.foldlevel = 99         -- Start with all folds open
o.foldlevelstart = 99
o.foldenable = true
o.foldminlines = 1       -- Allow single-line folds

-- `nvchad.options` disables the Python 3 provider. The Python profile needs it
-- back: molten-nvim runs inside the pynvim host. The provider's guard is
-- `exists()`, so deleting the variable is the only way to re-enable it; the
-- host itself only starts on first use. Its interpreter is set in
-- profiles/python/plugins.lua.
if vim.g.current_nvim_profile == "python" then
  vim.g.loaded_python3_provider = nil
end

-- o.cursorlineopt ='both' -- to enable cursorline!
