-- -----------------------------------------------------------------------------
-- rice -- the desktop palette, as a base46 theme
-- -----------------------------------------------------------------------------
--
-- Structure comes from whichever rice is active; the syntax hues do not.
--
-- That split is the same one kitty makes, for the same reason. The desktop
-- palette is a tonal ramp around one accent, and highlighting needs colours
-- distinguishable *from each other* -- a keyword, a string and a number in
-- three shades of violet is not a theme, it is a fog. Backgrounds, borders and
-- the statusline have no such constraint, so those follow the rice.
--
-- Deriving the hues was tried and does not work with matugen 4.2.0. Its
-- `-b wal` base16 output collapses base08..base0F -- exactly the syntax slots
-- -- to near-black on every image tested (#000000 for two of them), and its own
-- primary/secondary/tertiary/error come out as four shades of one hue, because
-- the default scheme derives them all from a single source colour. So the hues
-- below are tokyonight's, kept verbatim and on purpose.
--
-- The values arrive through $XDG_CACHE_HOME/dotfiles/theme/nvim.lua, written by
-- os/linux/desktop/render-theme.lua. This file is tracked and that one is not,
-- which is the point: no colour of the desktop's is written down here.

local M = {}

-- tokyonight's own structural values, used whole when there is no desktop
-- palette to read: a Mac, a fresh machine, or a Linux box where render-theme
-- has not run yet. A floor rather than a theme -- it is what this file looked
-- like before, so falling back changes nothing visible.
local FLOOR = {
  root = "#16161e",
  base = "#1a1b26",
  raised = "#1f2336",
  overlay = "#414868",
  muted = "#40486a",
  bar = "#1d1e29",
  accent = "#7aa2f7",
  accent_deep = "#3d59a1",
  fg = "#a9b1d6",
  fg_bright = "#c0caf5",
  fg_muted = "#4f5779",
  fg_dim = "#565f89",
}

-- Read on load, never cached across sessions: base46 compiles this file to
-- bytecode, so "reloading" means recompiling, which init.lua triggers when the
-- generated palette is newer than the cache.
--
-- pcall because a half-written file during a rice switch must not take nvim
-- down with it. A partial table is tolerated too -- anything missing falls
-- through to the floor rather than arriving as nil and erroring somewhere far
-- from here.
local function generated()
  local cache = vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")
  local ok, tb = pcall(dofile, cache .. "/dotfiles/theme/nvim.lua")

  return (ok and type(tb) == "table") and tb or {}
end

local c = setmetatable(generated(), { __index = FLOOR })

M.base_30 = {
  -- Structure: the rice. The ramp ascends root -> base -> raised -> overlay
  -- -> muted, which is five steps onto base46's seven, so a couple of its
  -- names share one. They are near-identical in tokyonight too.
  darker_black = c.root,
  black = c.base,
  black2 = c.raised,
  one_bg = c.raised,
  one_bg3 = c.overlay,
  one_bg2 = c.muted,
  grey = c.muted,
  grey_fg = c.fg_dim,
  grey_fg2 = c.fg_muted,
  light_grey = c.fg_muted,
  line = c.overlay,
  lightbg = c.raised,
  statusline_bg = c.bar,
  white = c.fg_bright,

  -- The accent carries focus here exactly as it does on the desktop.
  pmenu_bg = c.accent,
  folder_bg = c.accent,

  -- Hues: tokyonight's, held back from the palette on purpose. See the note at
  -- the top before pointing any of these at c.accent.
  red = "#f7768e",
  baby_pink = "#DE8C92",
  pink = "#ff75a0",
  green = "#9ece6a",
  vibrant_green = "#73daca",
  nord_blue = "#80a8fd",
  blue = "#7aa2f7",
  yellow = "#e0af68",
  sun = "#EBCB8B",
  purple = "#bb9af7",
  dark_purple = "#9d7cd8",
  teal = "#1abc9c",
  orange = "#ff9e64",
  cyan = "#7dcfff",
}

M.base_16 = {
  base00 = c.base,
  base01 = c.root,
  -- Visual selection. Deliberately `overlay` where CursorLine takes `raised`,
  -- or a selection on the cursor line would be invisible.
  base02 = c.overlay,
  base03 = c.muted,
  base04 = c.fg_dim,
  base05 = c.fg,
  base06 = c.fg_bright,
  base07 = c.fg_bright,

  base08 = "#73daca",
  base09 = "#ff9e64",
  base0A = "#0db9d7",
  base0B = "#9ece6a",
  base0C = "#b4f9f8",
  base0D = "#2ac3de",
  base0E = "#bb9af7",
  base0F = "#f7768e",
}

M.polish_hl = {
  -- base46 draws float and Telescope borders with `blue`, which is a syntax
  -- hue -- repointing it would recolour every function call. Overriding the
  -- border alone gets the rice's accent around a popup while leaving code
  -- untouched.
  defaults = {
    FloatBorder = { fg = c.accent },
  },

  -- tokyonight's, carried across with the hues they depend on.
  treesitter = {
    ["@variable"] = { fg = M.base_16.base05 },
    ["@punctuation.bracket"] = { fg = M.base_30.purple },
    ["@function.method.call"] = { fg = M.base_30.red },
    ["@function.call"] = { fg = M.base_30.blue },
    ["@constant"] = { fg = M.base_30.orange },
    ["@variable.parameter"] = { fg = M.base_30.orange },
  },
}

M.type = "dark"

M = require("base46").override_theme(M, "rice")

return M
