vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- Initialize profile system
local profile_manager = require "profile-manager"
local current_profile = profile_manager.get_current_profile()
local profile_plugins = profile_manager.load_profile(current_profile)

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins with profile system
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  -- Load profile-specific plugins instead of generic plugins
  profile_plugins,

  -- Plugins shared across all profiles (e.g. inactive-pane dimming)
  { import = "plugins.shared" },
}, lazy_config)

-- load theme
--
-- base46 compiles themes to bytecode and this only loads the result, so a
-- change to the desktop palette reaches nvim through a recompile rather than
-- by being read. One stat decides it: the generated palette newer than the
-- cache means a rice was switched or a wallpaper changed since this was built.
--
-- Everywhere else in this repo a palette edit lands at the next login. Here it
-- lands at the next nvim start, which is the same promise for a program that
-- starts far more often.
--
-- pcall'd and best effort: a failed recompile leaves the previous cache in
-- place, which is the old colours rather than no colours. On a machine with no
-- desktop palette the stat fails and nothing runs.
local function palette_newer_than_cache()
  local cache = vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")
  local generated = vim.uv.fs_stat(cache .. "/dotfiles/theme/nvim.lua")

  if not generated then
    return false
  end

  local compiled = vim.uv.fs_stat(vim.g.base46_cache .. "defaults")

  return not compiled or generated.mtime.sec > compiled.mtime.sec
end

if palette_newer_than_cache() then
  pcall(function()
    require("base46").compile()
  end)
end

dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
