-- :KeyDrill — flashcards for keybindings. A description is shown, you press
-- the keys that do it. Keys are read with getcharstr() and compared, never
-- fed to nvim, so a wrong guess cannot run anything.
--
-- The cards come from the live keymap table, not a list kept here: whatever
-- is mapped when the drill starts, with a `desc`, is fair game. That keeps it
-- in step with the config and the active profile for free, and buffer-local
-- maps (LSP keys) come from the buffer it was started in. A binding without a
-- `desc` never appears, which is also a hint that it needs one.
--
-- Progress is a Leitner box per card, kept per machine under stdpath("data").
-- A miss sends a card back to box 0, a hit moves it up one, and lower boxes
-- are drawn more often.
local M = {}

local STATE_FILE = vim.fn.stdpath("data") .. "/keydrill.json"
local ROUND = 20
local MAX_BOX = 5
local WIDTH = 60
local ESC = vim.keycode("<Esc>")
local CTRL_C = vim.keycode("<C-c>")

local ns = vim.api.nvim_create_namespace("keydrill")

local function leader()
  return vim.g.mapleader or "\\"
end

-- Raw key bytes as they are written in a mapping: `<leader>` for a leading
-- leader, <> notation for the rest.
local function display(raw)
  local lead = leader()
  if raw:sub(1, #lead) == lead then
    return "<leader>" .. vim.fn.keytrans(raw:sub(#lead + 1))
  end
  return vim.fn.keytrans(raw)
end

-- Events getcharstr() reports that are not keypresses.
local function is_noise(key)
  local name = vim.fn.keytrans(key)
  return name:find("Mouse") or name:find("Scroll") or name:find("Focus")
    or name == "<Ignore>" or name == "<CursorHold>"
end

local function load_state()
  local ok, lines = pcall(vim.fn.readfile, STATE_FILE)
  if not ok then
    return {}
  end
  local decoded_ok, state = pcall(vim.json.decode, table.concat(lines, "\n"))
  return decoded_ok and type(state) == "table" and state or {}
end

local function save_state(state)
  pcall(vim.fn.writefile, { vim.json.encode(state) }, STATE_FILE)
end

-- One card per description, since several keys can share one (<F12> and
-- <M-i> both toggle the floating terminal); any of them is a right answer.
-- The id includes the keys, so rebinding something starts it over.
local function collect(buf, opts)
  local maps = {}
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    maps[m.lhs] = m
  end
  -- Buffer-local maps shadow global ones with the same keys, as in use.
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    maps[m.lhs] = m
  end

  local prefix = opts.prefix ~= "" and vim.keycode(opts.prefix) or nil
  local by_desc = {}
  for lhs, m in pairs(maps) do
    local raw = vim.keycode(lhs)
    local wanted = m.desc and m.desc ~= "" and not lhs:find("<Plug>")
      and (opts.all or vim.startswith(raw, leader()))
      and (not prefix or vim.startswith(raw, prefix))
    if wanted then
      by_desc[m.desc] = by_desc[m.desc] or {}
      table.insert(by_desc[m.desc], raw)
    end
  end

  local cards = {}
  for desc, keys in pairs(by_desc) do
    table.sort(keys)
    local shown = vim.tbl_map(display, keys)
    table.insert(cards, {
      desc = desc,
      keys = keys,
      answer = table.concat(shown, " or "),
      id = desc .. "\t" .. table.concat(shown, " "),
    })
  end
  return cards
end

-- Weighted draw without replacement: box 0 is 2^MAX_BOX times as likely as
-- a card that has been answered right MAX_BOX times running.
local function draw(cards, state, n)
  local pool, round = vim.list_extend({}, cards), {}
  local function weight(card)
    return 2 ^ (MAX_BOX - (state[card.id] or 0))
  end
  while #round < n and #pool > 0 do
    local total = 0
    for _, card in ipairs(pool) do
      total = total + weight(card)
    end
    local r = math.random() * total
    for i, card in ipairs(pool) do
      r = r - weight(card)
      if r <= 0 or i == #pool then
        table.insert(round, table.remove(pool, i))
        break
      end
    end
  end
  return round
end

local function open_window(title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local height = 9
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = WIDTH,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - WIDTH) / 2),
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })
  return buf, win
end

-- Lines: question, typed keys, feedback, score. `hl` colours the feedback.
local function render(buf, s)
  local score = string.format("✓ %d   ✗ %d   streak %d", s.right, s.wrong, s.streak)
  local progress = string.format("%d/%d", s.index, s.total)
  local lines = {
    "",
    "  " .. s.question,
    "",
    "  > " .. s.typed .. "_",
    "",
    "  " .. (s.feedback or ""),
    "",
    "  " .. score .. string.rep(" ", WIDTH - 4 - vim.fn.strdisplaywidth(score .. progress)) .. progress,
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 1, 0, { end_col = #lines[2], hl_group = "Title" })
  if s.hl then
    vim.api.nvim_buf_set_extmark(buf, ns, 5, 0, { end_col = #lines[6], hl_group = s.hl })
  end
  vim.cmd.redraw()
end

local function getkey()
  local ok, key = pcall(vim.fn.getcharstr)
  if not ok then
    return CTRL_C
  end
  return key
end

-- true/false for a finished answer, nil to quit. Stops at the first key that
-- cannot lead to any right answer, so a wrong guess needs no confirming.
local function ask(buf, s, card)
  local typed = ""
  while true do
    s.typed = display(typed)
    render(buf, s)
    local key = getkey()
    if not is_noise(key) then
      local candidate = typed .. key
      local possible, done = false, false
      for _, raw in ipairs(card.keys) do
        possible = possible or vim.startswith(raw, candidate)
        done = done or raw == candidate
      end
      if key == CTRL_C or (key == ESC and not possible) then
        return nil
      end
      typed = candidate
      if done then
        return true
      elseif not possible then
        s.typed = display(typed)
        return false
      end
    end
  end
end

local function summary(buf, s, missed)
  local lines = {
    "",
    string.format("  Done: %d of %d right.", s.right, s.right + s.wrong),
    "",
  }
  if #missed > 0 then
    table.insert(lines, "  Missed:")
    for i = 1, math.min(#missed, 4) do
      local card = missed[i]
      table.insert(lines, string.format("    %-14s %s", card.answer, card.desc))
    end
  else
    table.insert(lines, "  No misses.")
  end
  table.insert(lines, "")
  table.insert(lines, "  Any key to close")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 1, 0, { end_col = #lines[2], hl_group = "Title" })
  vim.cmd.redraw()
  getkey()
end

local function play(buf, round, state)
  local s = { right = 0, wrong = 0, streak = 0, index = 0, total = #round }
  local missed = {}

  for i, card in ipairs(round) do
    s.index, s.question = i, card.desc
    local result = ask(buf, s, card)
    if result == nil then
      return
    end

    if result then
      s.right, s.streak = s.right + 1, s.streak + 1
      state[card.id] = math.min((state[card.id] or 0) + 1, MAX_BOX)
      s.feedback, s.hl = "✓ " .. card.answer, "DiagnosticOk"
    else
      s.wrong, s.streak = s.wrong + 1, 0
      state[card.id] = 0
      table.insert(missed, card)
      -- Wait on a miss so the answer gets read before the next question.
      s.feedback, s.hl = "✗ it's " .. card.answer .. "   (any key)", "DiagnosticError"
      render(buf, s)
      if getkey() == CTRL_C then
        return
      end
      s.feedback, s.hl = nil, nil
    end
    save_state(state)
  end

  summary(buf, s, missed)
end

-- opts.all: every normal-mode map with a desc, not just <leader> ones.
-- opts.prefix: only maps under these keys, in <> notation ("<leader>d").
function M.start(opts)
  opts = opts or {}
  opts.prefix = opts.prefix or ""

  local cards = collect(vim.api.nvim_get_current_buf(), opts)
  if #cards == 0 then
    vim.notify("KeyDrill: no mapped keys with a description match", vim.log.levels.WARN)
    return
  end

  math.randomseed(vim.uv.hrtime())
  local state = load_state()
  local round = draw(cards, state, math.min(ROUND, #cards))

  local profile = vim.g.current_nvim_profile
  local title = " KeyDrill" .. (profile and (" ─ " .. profile) or "") .. " "
  local buf, win = open_window(title)

  local ok, err = pcall(play, buf, round, state)
  save_state(state)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if not ok then
    vim.notify("KeyDrill: " .. err, vim.log.levels.ERROR)
  end
end

return M
