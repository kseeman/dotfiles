require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- move lines up and down
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '>-2<CR>gv=gv")

-- center cursor after paging
map("n", "<C-d>", "<C-d>zz", { desc = "Page down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Page up and center" })

-- auto replace current word
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>"]])

-- auto replace selected text in visual mode
map("v", "<leader>s", "\"hy:%s/<C-r>h//g<Left><Left>", { desc = "Replace selected text" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--
map("n", "gI", vim.lsp.buf.implementation, {
  desc = "Go to implementation",
})

-- optional Telescope version
map("n", "<leader>li", function()
  require("telescope.builtin").lsp_implementations()
end, { desc = "LSP implementations" })
