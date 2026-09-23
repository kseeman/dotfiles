-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "tokyonight",
  transparency = true,

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}

-- Landing screen, shown when nvim starts with no file argument. NvChad already
-- ships this (nvdash), so there is no separate dashboard plugin here.
--
-- `header` is left alone and inherited from NvChad's defaults; only the actions
-- are ours. `keys` are pressed bare inside the dash buffer, not with a leader,
-- and each `cmd` is a string run as an Ex command.
--
-- Note what is NOT here: nothing restores a session on its own. `s` does it on
-- request, which keeps opening a specific file from ever dragging an unrelated
-- project's windows along with it.
M.nvdash = {
  load_on_startup = true,

  buttons = {
    { txt = "  Find File", keys = "f", cmd = "Telescope find_files" },
    { txt = "󰈭  Find Text", keys = "g", cmd = "Telescope live_grep" },
    { txt = "  Recent Files", keys = "r", cmd = "Telescope oldfiles" },
    { txt = "  Restore Session", keys = "s", cmd = "lua require('persistence').load()" },
    { txt = "  Projects", keys = "p", cmd = "lua require('configs.projects').pick()" },
    {
      txt = "  Neovim Config",
      keys = "c",
      cmd = "lua require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }",
    },
    { txt = "󰒲  Plugin Manager", keys = "l", cmd = "Lazy" },
    { txt = "  Quit", keys = "q", cmd = "quitall" },

    { txt = "─", hl = "NvDashFooter", no_gap = true, rep = true },

    -- Keep this line short. nvdash centres every button on the *widest* one, so
    -- a footer wider than the window drives the computed column negative and
    -- nvim_win_set_cursor throws "Invalid cursor column: out of range" before
    -- the dashboard ever appears. The cwd belongs on the statusline, which
    -- already carries it, not here.
    {
      txt = function()
        local stats = require("lazy").stats()
        local profile = require("profile-manager").get_current_profile()

        return "  "
          .. profile
          .. "  󰒲 "
          .. stats.loaded
          .. "/"
          .. stats.count
          .. "  󱐋 "
          .. math.floor(stats.startuptime)
          .. " ms"
      end,
      hl = "NvDashFooter",
      no_gap = true,
      content = "fit",
    },

    { txt = "─", hl = "NvDashFooter", no_gap = true, rep = true },
  },
}

-- Add profile to statusline
M.ui = {
  statusline = {
    theme = "default",
    separator_style = "default",
    order = { "mode", "file", "git", "%=", "lsp_msg", "%=", "diagnostics", "profile", "lsp", "cwd", "cursor" },
    modules = {
      profile = function()
        local profile_manager = require("profile-manager")
        local current_profile = profile_manager.get_current_profile()
        return "%#St_gitIcons#" .. "󰏗 " .. "%#St_LspHints#" .. current_profile:upper() .. " "
      end,
    },
  },
}

return M
