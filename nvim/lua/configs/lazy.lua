local config = {
  defaults = { lazy = true },
  install = { colorscheme = { "nvchad" } },

  -- One lockfile per profile, rather than lazy.nvim's single
  -- `<config>/lazy-lock.json`.
  --
  -- The default cannot work here. `lazy/manage/lock.lua` loads the lockfile and
  -- then drops every entry that is not in the *current* spec — a plugin belonging
  -- to another profile is in neither `spec.disabled` nor `spec.ignore_installed`,
  -- so it is purged. Install, update and clean all trigger that write, and
  -- switching profiles auto-installs the new profile's missing plugins on
  -- startup, which is a write. The result is a lockfile that thrashes: whichever
  -- profile ran last wins and the other three profiles lose their pins.
  --
  -- Keying the file by profile makes each set self-consistent, so switching
  -- profiles never rewrites a lockfile belonging to a different one.
  --
  -- `current_nvim_profile` is set by profile-manager's load_profile(), which
  -- init.lua calls before requiring this module. It is the *resolved* profile —
  -- already fallen back to "default" if an unknown one was asked for — so the
  -- filename can never name a profile that does not exist.
  lockfile = vim.fn.stdpath "config" .. "/lazy-lock." .. (vim.g.current_nvim_profile or "default") .. ".json",

  -- lazy.nvim's luarocks integration needs Lua 5.1, but Homebrew ships Lua 5.5.
  -- `hererocks = true` makes lazy.nvim bootstrap its own pinned Lua 5.1 +
  -- luarocks under stdpath('data'), so plugins like image.nvim can build the
  -- `magick` rock without a system Lua 5.1.
  rocks = {
    hererocks = true,
  },

  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },

  performance = {
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
        "matchit",
        "tar",
        "tarPlugin",
        "rrhelper",
        "spellfile_plugin",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
        "tutor",
        "rplugin",
        "syntax",
        "synmenu",
        "optwin",
        "compiler",
        "bugreport",
        "ftplugin",
      },
    },
  },
}

-- rplugin.vim is what sources the :UpdateRemotePlugins manifest, so with it
-- disabled no remote plugin ever defines its commands. The Python profile's
-- molten-nvim is one; every other profile has none. lazy.nvim matches these
-- names against runtime filenames, so the entry has to be removed rather than
-- re-enabled later. `current_nvim_profile` is set by init.lua before this
-- module is required.
if vim.g.current_nvim_profile == "python" then
  config.performance.rtp.disabled_plugins = vim.tbl_filter(function(name)
    return name ~= "rplugin"
  end, config.performance.rtp.disabled_plugins)
end

return config
