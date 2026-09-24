-- Gutter with the absolute and relative line number side by side.
--
-- Relative numbers are for jumping (`5j`); absolute ones are for people
-- watching the screen, who can only name the cursor line under a plain hybrid
-- setup. Setting 'statuscolumn' replaces the whole gutter, so the fold (%C)
-- and sign (%s) columns are put back in their default order ahead of the
-- numbers. Clicking a fold marker in %C still toggles the fold.

local M = {}

-- Evaluated once per drawn line, with v:lnum/v:relnum/v:virtnum set for it
-- and the window being drawn temporarily current.
function M.numbers()
  -- Each half follows its own option, so NvChad's <leader>n / <leader>rn
  -- toggles still work. Without 'relativenumber' Neovim stops redrawing the
  -- gutter on cursor movement, so a relative column left up would go stale.
  -- Windows that turn both off (nvim-tree, terminals, pickers) inherit this
  -- global option and get their folds and signs only.
  local abs, rel = vim.wo.number, vim.wo.relativenumber
  if not (abs or rel) then
    return ""
  end

  local width = math.max(#tostring(vim.api.nvim_buf_line_count(0)), 2)
  local abs_text = abs and string.format("%" .. width .. "d ", vim.v.lnum) or ""
  -- The cursor line has no offset to show, so its relative slot stays empty.
  local rel_text = rel and string.format("%3s ", vim.v.relnum == 0 and "" or vim.v.relnum) or ""

  -- Wrapped continuation and virtual lines get a blank gutter, like the default.
  if vim.v.virtnum ~= 0 then
    return string.rep(" ", #abs_text + #rel_text)
  end
  return abs_text .. rel_text
end

function M.setup()
  vim.o.statuscolumn = "%C%s%{v:lua.require'configs.statuscolumn'.numbers()}"
end

return M
