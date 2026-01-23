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

-- o.cursorlineopt ='both' -- to enable cursorline!
