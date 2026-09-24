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
  -- The option is global, so windows that turn numbers off (nvim-tree,
  -- terminals, pickers) inherit it; they get their folds and signs only.
  if not (vim.wo.number or vim.wo.relativenumber) then
    return ""
  end

  local width = math.max(#tostring(vim.api.nvim_buf_line_count(0)), 2)
  -- Wrapped continuation and virtual lines get a blank gutter, like the default.
  if vim.v.virtnum ~= 0 then
    return string.rep(" ", width + 5)
  end

  -- The cursor line has no offset to show, so its relative slot stays empty.
  local rel = vim.v.relnum == 0 and "" or tostring(vim.v.relnum)
  return string.format("%" .. width .. "d %3s ", vim.v.lnum, rel)
end

function M.setup()
  vim.o.statuscolumn = "%C%s%{v:lua.require'configs.statuscolumn'.numbers()}"
end

return M
