-- Per-project settings, kept outside this public repo like the tmux side's
-- ~/.userconfig/tmux/{profiles,layouts}. A project's file is named after its
-- git root's directory and returns a table:
--
--   -- ~/.userconfig/nvim/projects/<repo-dir-name>.lua
--   return {
--     maven_test_args = { '-Dsome.property=none' },
--   }
--
-- Looked up from the path being worked on, not the cwd, so one nvim spanning
-- several projects gives each its own settings. Read on every call rather than
-- cached: it only happens when a command runs, and edits apply without a
-- restart.
local M = {}

local PROJECTS_DIR = vim.fn.expand('~/.userconfig/nvim/projects')

function M.get(path)
  local root = vim.fs.root(path, '.git')
  if not root then
    return {}
  end

  local file = PROJECTS_DIR .. '/' .. vim.fs.basename(root) .. '.lua'
  if vim.fn.filereadable(file) == 0 then
    return {}
  end

  -- Loud rather than silent: a broken file otherwise just looks like a
  -- setting that did not apply.
  local ok, config = pcall(dofile, file)
  if not ok or type(config) ~= 'table' then
    vim.notify('project-config: ' .. file .. ': ' .. (ok and 'did not return a table' or tostring(config)),
      vim.log.levels.WARN)
    return {}
  end
  return config
end

return M
