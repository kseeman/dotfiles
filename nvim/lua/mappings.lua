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

-- Floating terminal toggle using F12 (works reliably on macOS)
map({ "n", "t" }, "<F12>", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })

-- Note: <leader>ft mapping disabled because it causes Space key lag in terminal
-- map({ "n", "t" }, "<leader>ft", function()
--   require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
-- end, { desc = "terminal toggle floating term" })

-- Inlay hints: parameter names beside arguments, as IntelliJ shows them. On
-- globally, so every client that sends them (jdtls included) is covered.
-- Servers still have to be asked for parameter-name hints in their settings;
-- see configs/lspconfig.lua and the java profile. <leader>th is NvChad's theme
-- picker, hence <leader>ih. SQL has no server that sends them, so
-- configs/sql-hints draws INSERT column names itself and follows this switch.
vim.lsp.inlay_hint.enable(true)
local sql_hints = require("configs.sql-hints")
sql_hints.setup()
map("n", "<leader>ih", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  sql_hints.refresh_all()
end, { desc = "Toggle inlay hints" })

-- Setup test runner
local test_runner = require("configs.test-runner")
test_runner.setup()

-- Manual format current buffer. Async, so a slow formatter (sqlfluff on a
-- large file) finishes instead of hitting a timeout.
map({ "n", "v" }, "<leader>fm", function()
  require("conform").format({ lsp_fallback = true, async = true })
end, { desc = "Format buffer" })

-- Machine-local nvim code, outside the repo like ~/.userconfig/zsh/local.zsh,
-- so it can neither be committed nor lost with the checkout. A plain script,
-- run again by `:Reload local`: anything it defines must be safe to redefine
-- (autocmds in an augroup with `clear = true`). Errors warn rather than being
-- swallowed, since a silently skipped file just looks like a missing setting.
local USER_LOCAL = vim.fn.expand("~/.userconfig/nvim/local.lua")

local function load_user_local()
  if vim.fn.filereadable(USER_LOCAL) == 0 then
    return false
  end
  local ok, err = pcall(dofile, USER_LOCAL)
  if not ok then
    vim.notify("Failed to load " .. USER_LOCAL .. ": " .. err, vim.log.levels.WARN)
  end
  return ok
end

-- Reload config modules without restarting nvim
vim.api.nvim_create_user_command("Reload", function(opts)
  local targets = opts.fargs
  if #targets == 0 then
    targets = { "mappings" }
  end

  for _, target in ipairs(targets) do
    if target == "conform" then
      package.loaded["configs.conform"] = nil
      require("conform").setup(require("configs.conform"))
      vim.notify("Reloaded conform config", vim.log.levels.INFO)
    elseif target == "mappings" then
      package.loaded["mappings"] = nil
      require("mappings")
      vim.notify("Reloaded mappings", vim.log.levels.INFO)
    elseif target == "local" then
      if vim.fn.filereadable(USER_LOCAL) == 0 then
        vim.notify(USER_LOCAL .. " not found", vim.log.levels.WARN)
      elseif load_user_local() then
        vim.notify("Reloaded " .. USER_LOCAL, vim.log.levels.INFO)
      end
    else
      local module = "configs." .. target
      package.loaded[module] = nil
      local ok, err = pcall(require, module)
      if ok then
        vim.notify("Reloaded " .. module, vim.log.levels.INFO)
      else
        vim.notify("Failed to reload " .. module .. ": " .. err, vim.log.levels.ERROR)
      end
    end
  end
end, {
  nargs = "*",
  complete = function()
    return { "mappings", "conform", "local", "dap", "lspconfig", "test-runner" }
  end,
  desc = "Reload config: :Reload [mappings|conform|local|<configs.*>]",
})

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

-- Copy file path to clipboard
map("n", "<leader>fp", function()
  local path = vim.fn.expand('%:p')
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { desc = "Copy file path to clipboard" })

-- Session persistence (persistence.nvim). Restoring is always explicit — see
-- the spec in plugins/shared.lua for why. <leader>q is free: NvChad binds
-- nothing under it, and <leader>p is already profiles and NvChad's terminals.
map("n", "<leader>qs", function()
  require("persistence").load()
end, { desc = "Session restore for this directory" })

map("n", "<leader>ql", function()
  require("persistence").load { last = true }
end, { desc = "Session restore last used" })

-- Leaves the session on disk as it was, rather than overwriting it with
-- whatever this instance happens to have open.
map("n", "<leader>qd", function()
  require("persistence").stop()
end, { desc = "Session don't save on exit" })

-- Switch projects. Inside tmux this hands off to tmux-sessionizer, the same
-- picker prefix + f and `dev` use.
map("n", "<leader>fP", function()
  require("configs.projects").pick()
end, { desc = "Find project" })

map("n", "<leader>fd", function()
  require("configs.folders").pick()
end, { desc = "Find folder and reveal in tree" })

-- Back to earlier searches, with their results as they were. How many are
-- kept is `cache_picker` in the telescope spec (plugins/shared.lua).
map("n", "<leader>fr", function()
  require("telescope.builtin").resume()
end, { desc = "Resume last search" })

map("n", "<leader>fR", function()
  require("telescope.builtin").pickers()
end, { desc = "Recent searches" })

-- Profile switching keymaps
map("n", "<leader>ps", ":ProfileSwitch<CR>", { desc = "Switch profile" })
map("n", "<leader>pr", ":ProfileRestart<CR>", { desc = "Restart with profile" })
map("n", "<leader>pi", ":ProfileStatus<CR>", { desc = "Profile info" })
map("n", "<leader>pc", ":ProfileClear<CR>", { desc = "Clear saved profile" })

load_user_local()

