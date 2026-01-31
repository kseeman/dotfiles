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

-- M.nvdash = { load_on_startup = true }

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
