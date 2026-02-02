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
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- auto replace selected text in visual mode
map("v", "<leader>s", "\"hy:%s/<C-r>h//g<Left><Left>", { desc = "Replace selected text" })

-- Comment toggle shortcuts
map("n", "<C-/>", "gcc", { desc = "Toggle line comment", remap = true })
map("v", "<C-/>", "gc", { desc = "Toggle comment selection", remap = true })
map("i", "<C-/>", "<ESC>gcca", { desc = "Toggle line comment in insert mode", remap = true })

-- Floating terminal toggle (alternative to Alt+i that works on macOS)
map({ "n", "t" }, "<C-`>", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })

-- Alternative mapping for terminals that don't handle Ctrl+backtick properly (like Warp)
map({ "n", "t" }, "<M-`>", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term (Alt+backtick)" })

-- Note: <leader>ft mapping disabled because it causes Space key lag in terminal
-- map({ "n", "t" }, "<leader>ft", function()
--   require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
-- end, { desc = "terminal toggle floating term" })

-- Setup test runner
local test_runner = require("configs.test-runner")
test_runner.setup()

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--
map("n", "gI", vim.lsp.buf.implementation, {
  desc = "Go to implementation",
})

-- optional Telescope version
map("n", "<leader>li", function()
  require("telescope.builtin").lsp_implementations()
end, { desc = "LSP implementations" })

-- Git mappings
map("n", "<leader>gc", function()
  require("telescope.builtin").git_commits()
end, { desc = "Git commits" })

map("n", "<leader>gb", function()
  require("telescope.builtin").git_branches()
end, { desc = "Git branches" })

map("n", "<leader>gs", function()
  require("telescope.builtin").git_status()
end, { desc = "Git status" })

map("n", "<leader>gf", function()
  require("telescope.builtin").git_files()
end, { desc = "Git files" })

map("n", "<leader>gh", function()
  require("telescope.builtin").git_bcommits()
end, { desc = "Git buffer commits (history)" })

-- Folding mappings
map("n", "zR", "zR", { desc = "Open all folds" })
map("n", "zM", "zM", { desc = "Close all folds" })
map("n", "za", "za", { desc = "Toggle fold" })
map("n", "zo", "zo", { desc = "Open fold" })
map("n", "zc", "zc", { desc = "Close fold" })
map("n", "zj", "zj", { desc = "Move to next fold" })
map("n", "zk", "zk", { desc = "Move to previous fold" })

-- Additional git operations
map("n", "<leader>gd", function()
  vim.cmd("Gitsigns diffthis")
end, { desc = "Git diff current file" })

map("n", "<leader>gr", function()
  vim.cmd("Gitsigns reset_hunk")
end, { desc = "Git reset hunk" })

map("n", "<leader>gp", function()
  vim.cmd("Gitsigns preview_hunk")
end, { desc = "Git preview hunk" })

-- Profile switching commands
local profile_manager = require("profile-manager")

-- Create user commands for profile management
vim.api.nvim_create_user_command("ProfileSwitch", function()
  profile_manager.switch_profile()
end, { desc = "Switch nvim profile" })

vim.api.nvim_create_user_command("ProfileRestart", function()
  profile_manager.restart_with_profile()
end, { desc = "Restart nvim with current profile" })

vim.api.nvim_create_user_command("ProfileStatus", function()
  local current = profile_manager.get_current_profile()
  vim.notify("Current profile: " .. current, vim.log.levels.INFO)
end, { desc = "Show current profile" })

vim.api.nvim_create_user_command("ProfileClear", function()
  profile_manager.clear_persisted_profile()
end, { desc = "Clear persisted profile" })

-- Profile switching keymaps
map("n", "<leader>ps", ":ProfileSwitch<CR>", { desc = "Switch profile" })
map("n", "<leader>pr", ":ProfileRestart<CR>", { desc = "Restart with profile" })
map("n", "<leader>pi", ":ProfileStatus<CR>", { desc = "Profile info" })
map("n", "<leader>pc", ":ProfileClear<CR>", { desc = "Clear saved profile" })

-- Load local/work-specific commands if they exist (git-ignored)
local ok, local_commands = pcall(require, "local-commands")
if ok then
  local_commands.setup()
end

