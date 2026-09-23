-- Project switching, from inside Neovim.
--
-- In this setup tmux owns projects and Neovim owns editing, so "open a project"
-- means "switch to that project's tmux session" — a session that already has
-- its own Neovim in it. This module is only the bridge to tmux-sessionizer, so
-- the dashboard's Projects action, prefix + f and `dev` all pick from one list
-- with one definition of what a project is.

local M = {}

local SESSIONIZER = vim.fn.expand "~/.dotfiles/tmux/scripts/tmux-sessionizer"

-- Outside tmux there is no session to switch to, so the best that can be done
-- is to move this instance to the project: a window-local directory change,
-- not a global one, so other windows and any restored session keep their cwd.
local function open_here(dir)
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  require("telescope.builtin").find_files { cwd = dir }
end

function M.pick()
  if vim.fn.executable(SESSIONIZER) == 0 then
    vim.notify("tmux-sessionizer not found at " .. SESSIONIZER, vim.log.levels.ERROR)
    return
  end

  if vim.env.TMUX then
    -- Fire and forget. tmux draws the popup over this pane and switches the
    -- client once a project is picked, so waiting for the command to return
    -- would only block Neovim's redraw while its own window is being replaced.
    vim.fn.jobstart { "tmux", "display-popup", "-E", "-w", "80%", "-h", "80%", SESSIONIZER }
    return
  end

  local projects = vim.fn.systemlist { SESSIONIZER, "--list" }

  if vim.v.shell_error ~= 0 or #projects == 0 then
    vim.notify("No projects found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(projects, {
    prompt = "Project",
    format_item = function(path)
      return vim.fn.fnamemodify(path, ":~")
    end,
  }, function(choice)
    if choice then
      open_here(choice)
    end
  end)
end

return M
