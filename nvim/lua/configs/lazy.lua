local config = {
  defaults = { lazy = true },
  install = { colorscheme = { "nvchad" } },

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
