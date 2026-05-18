-- Dim inactive windows/splits.
-- Works alongside chadrc's `transparency = true`: by default tint only
-- adjusts foreground/syntax colors (not the background), so the terminal
-- background still shows through inactive panes.
local tint = require "tint"

tint.setup {
  -- Negative = darker. Lower (more negative) = stronger dim on inactive panes.
  tint = -45,
  -- Pull color toward grayscale on inactive panes (0 = fully gray, 1 = no change).
  saturation = 0.6,
  -- Default transform: saturate then tint. Keeps syntax readable while dimmed.
  transforms = tint.transforms.SATURATE_TINT,
  -- Keep false so transparency is preserved on inactive panes. Set to true
  -- if you'd rather inactive panes get a solid dimmed background instead.
  tint_background_colors = false,
  -- Don't dim window separators or the statusline (kept readable).
  highlight_ignore_patterns = { "WinSeparator", "Status.*", "NvimTreeWinSeparator" },
  -- Never dim floating windows or non-file/special buffers (telescope,
  -- claude-code terminal, dap-ui, etc.).
  window_ignore_function = function(winid)
    local bufid = vim.api.nvim_win_get_buf(winid)
    local buftype = vim.bo[bufid].buftype
    local floating = vim.api.nvim_win_get_config(winid).relative ~= ""
    return buftype == "terminal" or buftype == "prompt" or floating
  end,
}
