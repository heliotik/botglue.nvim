local history = require("botglue.history")
local config = require("botglue.config")
local ui = require("botglue.ui")

local M = {}

--- Build a horizontal divider line: "── Label ────────" padded to width.
--- @param label string section label (e.g. "Recent prompts")
--- @param width number target display width
--- @return string
function M._make_divider(label, width)
  if label == "" then
    return string.rep("─", width)
  end
  local prefix = "── " .. label .. " "
  local prefix_w = vim.fn.strdisplaywidth(prefix)
  if prefix_w >= width then
    return vim.fn.strcharpart(prefix, 0, width)
  end
  return prefix .. string.rep("─", width - prefix_w)
end

--- Truncate prompt text to fit within max_width display columns.
--- Uses strdisplaywidth for correct UTF-8/CJK handling.
--- @param text string prompt text
--- @param max_width number max display columns
--- @return string truncated text (with "…" suffix if truncated)
function M._truncate_prompt(text, max_width)
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  local chars = vim.fn.strchars(text)
  for i = chars, 1, -1 do
    local candidate = vim.fn.strcharpart(text, 0, i) .. "…"
    if vim.fn.strdisplaywidth(candidate) <= max_width then
      return candidate
    end
  end
  return "…"
end

local ACTIVE_HL = "BotglueActiveBorder"

local function setup_highlights()
  local hl = vim.api.nvim_get_hl(0, { name = ACTIVE_HL })
  if vim.tbl_isempty(hl) then
    vim.api.nvim_set_hl(0, ACTIVE_HL, { link = "DiagnosticWarn" })
  end
end

local function layout_dimensions()
  local width = math.min(math.floor(vim.o.columns * 0.6), 80)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor(vim.o.lines * 0.3)
  return width, col, row
end

--- Set border highlight on any float window via winhl.
local function set_border_hl(win, hl_group)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_option_value("winhl", "FloatBorder:" .. hl_group, { win = win })
  end
end

--- Open only Panel 3 (no history to show).
--- @param on_submit fun(prompt: string, model: string)
function M._open_prompt_only(on_submit)
  setup_highlights()
  local width, col, row = layout_dimensions()

  local handle = ui.create_prompt_window({
    width = width,
    row = row,
    col = col,
    model = config.options.model,
  })

  handle.set_border_hl(ACTIVE_HL)

  local closed = false
  local function close_all()
    if closed then
      return
    end
    closed = true
    handle.close()
  end

  local function submit()
    local text = vim.trim(handle.get_text())
    local model = handle.get_model()
    close_all()
    if text ~= "" then
      on_submit(text, model)
    end
  end

  local buf = handle.buf
  vim.keymap.set("n", "<CR>", submit, { buffer = buf })
  vim.keymap.set({ "i", "n" }, "<C-s>", submit, { buffer = buf })
  vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
    handle.cycle_model()
  end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = buf })
  vim.keymap.set("n", "q", close_all, { buffer = buf })
end

--- Open the full three-panel UI with custom float windows.
--- @param entries table[] history entries sorted by frequency
--- @param on_submit fun(prompt: string, model: string)
function M._open_full(entries, on_submit)
  setup_highlights()
  local width, col, top_row = layout_dimensions()

  -- State
  local all_entries = entries
  local filtered_entries = entries
  local selected_idx = 1
  local draft = { text = "", model = config.options.model }
  local closed = false
  local autocmd_ids = {}

  -- Panel dimensions
  local list_height = math.min(#entries, 10)
  -- Vertical stacking: each window adds 2 rows for border (top + bottom)
  local filter_row = top_row
  local list_row = filter_row + 1 + 2
  local prompt_row = list_row + list_height + 2

  -- === Create windows ===

  -- Panel 1: Filter
  local filter_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[filter_buf].bufhidden = "wipe"
  local filter_win = vim.api.nvim_open_win(filter_buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    row = filter_row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Botglue ",
    title_pos = "center",
  })

  -- Panel 2: List
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[list_buf].bufhidden = "wipe"
  vim.bo[list_buf].modifiable = false
  local list_win = vim.api.nvim_open_win(list_buf, false, {
    relative = "editor",
    width = width,
    height = list_height,
    row = list_row,
    col = col,
    style = "minimal",
    border = "rounded",
  })
  vim.wo[list_win].cursorline = true

  -- Panel 3: Prompt (via ui.lua factory)
  local prompt_handle = ui.create_prompt_window({
    width = width,
    row = prompt_row,
    col = col,
    model = draft.model,
    enter = false,
  })

  -- === Core functions ===

  local function render_list()
    local lines = {}
    for _, entry in ipairs(filtered_entries) do
      local prompt_text = entry.prompt
      local model_tag = "[" .. entry.model .. "]"
      local available = width - 4 - #model_tag - 1
      if #prompt_text > available then
        prompt_text = prompt_text:sub(1, available - 1) .. "…"
      end
      local padding = available - #prompt_text + 1
      if padding < 1 then
        padding = 1
      end
      table.insert(lines, "  " .. prompt_text .. string.rep(" ", padding) .. model_tag)
    end
    if #lines == 0 then
      lines = { "  (no matches)" }
    end
    vim.bo[list_buf].modifiable = true
    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
    vim.bo[list_buf].modifiable = false
    selected_idx = math.max(1, math.min(selected_idx, #filtered_entries))
    if vim.api.nvim_win_is_valid(list_win) and #filtered_entries > 0 then
      vim.api.nvim_win_set_cursor(list_win, { selected_idx, 0 })
    end
  end

  local function update_preview()
    if not prompt_handle or not prompt_handle.is_valid() then
      return
    end
    if #filtered_entries == 0 then
      return
    end
    local entry = filtered_entries[selected_idx]
    if entry then
      prompt_handle.set_preview(entry.prompt)
      prompt_handle.set_model(entry.model)
    end
  end

  local function apply_filter()
    local text = vim.trim(vim.api.nvim_buf_get_lines(filter_buf, 0, 1, false)[1] or "")
    if text == "" then
      filtered_entries = all_entries
    else
      local prompts = vim.tbl_map(function(e)
        return e.prompt
      end, all_entries)
      local matched_set = {}
      for _, m in ipairs(vim.fn.matchfuzzy(prompts, text)) do
        matched_set[m] = true
      end
      filtered_entries = vim.tbl_filter(function(e)
        return matched_set[e.prompt]
      end, all_entries)
    end
    selected_idx = 1
    render_list()
    update_preview()
  end

  -- === Focus management ===

  local function focus_list()
    set_border_hl(filter_win, "FloatBorder")
    set_border_hl(list_win, ACTIVE_HL)
    prompt_handle.set_border_hl("FloatBorder")
    if vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_set_current_win(list_win)
    end
  end

  local function focus_filter()
    set_border_hl(filter_win, ACTIVE_HL)
    set_border_hl(list_win, "FloatBorder")
    prompt_handle.set_border_hl("FloatBorder")
    if vim.api.nvim_win_is_valid(filter_win) then
      vim.api.nvim_set_current_win(filter_win)
      vim.cmd("startinsert!")
    end
  end

  local function focus_prompt(selected_text)
    if selected_text then
      draft.text = selected_text
    end
    set_border_hl(filter_win, "FloatBorder")
    set_border_hl(list_win, "FloatBorder")
    prompt_handle.set_border_hl(ACTIVE_HL)
    prompt_handle.set_draft(draft.text)
    prompt_handle.focus()
  end

  -- === Actions ===

  local function close_all()
    if closed then
      return
    end
    closed = true
    for _, id in ipairs(autocmd_ids) do
      pcall(vim.api.nvim_del_autocmd, id)
    end
    prompt_handle.close()
    if vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_win_close(list_win, true)
    end
    if vim.api.nvim_win_is_valid(filter_win) then
      vim.api.nvim_win_close(filter_win, true)
    end
  end

  local function quick_submit()
    if #filtered_entries == 0 then
      return
    end
    local entry = filtered_entries[selected_idx]
    if entry then
      close_all()
      on_submit(entry.prompt, entry.model)
    end
  end

  local function submit_prompt()
    if not prompt_handle or not prompt_handle.is_valid() then
      return
    end
    local text = vim.trim(prompt_handle.get_text())
    local model = prompt_handle.get_model()
    close_all()
    if text ~= "" then
      on_submit(text, model)
    end
  end

  local function select_entry()
    if #filtered_entries == 0 then
      return
    end
    local entry = filtered_entries[selected_idx]
    if entry then
      focus_prompt(entry.prompt)
      prompt_handle.set_model(entry.model)
    end
  end

  local function navigate_from_filter(direction)
    if direction == "down" then
      selected_idx = math.min(selected_idx + 1, #filtered_entries)
    else
      selected_idx = math.max(selected_idx - 1, 1)
    end
    if vim.api.nvim_win_is_valid(list_win) and #filtered_entries > 0 then
      vim.api.nvim_win_set_cursor(list_win, { selected_idx, 0 })
    end
    update_preview()
  end

  -- === Keymaps: List (Panel 2) ===

  vim.keymap.set("n", "/", focus_filter, { buffer = list_buf })
  vim.keymap.set("n", "<CR>", select_entry, { buffer = list_buf })
  vim.keymap.set("n", "<C-s>", quick_submit, { buffer = list_buf })
  vim.keymap.set("n", "<Tab>", function()
    focus_prompt(nil)
  end, { buffer = list_buf })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = list_buf })
  vim.keymap.set("n", "q", close_all, { buffer = list_buf })

  -- === Keymaps: Filter (Panel 1) ===

  vim.keymap.set("i", "<CR>", select_entry, { buffer = filter_buf })
  vim.keymap.set("i", "<C-j>", function()
    navigate_from_filter("down")
  end, { buffer = filter_buf })
  vim.keymap.set("i", "<C-k>", function()
    navigate_from_filter("up")
  end, { buffer = filter_buf })
  vim.keymap.set("i", "<C-s>", quick_submit, { buffer = filter_buf })
  vim.keymap.set("i", "<Esc>", function()
    vim.api.nvim_buf_set_lines(filter_buf, 0, -1, false, { "" })
    apply_filter()
    focus_list()
  end, { buffer = filter_buf })
  vim.keymap.set("i", "<Tab>", function()
    focus_prompt(nil)
  end, { buffer = filter_buf })

  -- === Keymaps: Prompt (Panel 3) ===

  local pbuf = prompt_handle.buf
  vim.keymap.set("n", "<CR>", submit_prompt, { buffer = pbuf })
  vim.keymap.set({ "i", "n" }, "<C-s>", submit_prompt, { buffer = pbuf })
  vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
    prompt_handle.cycle_model()
  end, { buffer = pbuf })
  vim.keymap.set("n", "<Tab>", function()
    draft.text = prompt_handle.get_text()
    draft.model = prompt_handle.get_model()
    update_preview()
    focus_list()
  end, { buffer = pbuf })
  vim.keymap.set("i", "<Tab>", function()
    draft.text = prompt_handle.get_text()
    draft.model = prompt_handle.get_model()
    vim.cmd("stopinsert")
    update_preview()
    focus_list()
  end, { buffer = pbuf })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = pbuf })
  vim.keymap.set("n", "q", close_all, { buffer = pbuf })

  -- === Autocmds ===

  table.insert(
    autocmd_ids,
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = list_buf,
      callback = function()
        if closed then
          return
        end
        local ok, cursor = pcall(vim.api.nvim_win_get_cursor, list_win)
        if ok then
          selected_idx = cursor[1]
          update_preview()
        end
      end,
    })
  )

  table.insert(
    autocmd_ids,
    vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = filter_buf,
      callback = function()
        if closed then
          return
        end
        apply_filter()
      end,
    })
  )

  -- === Initial state ===

  render_list()
  update_preview()
  focus_list()
end

--- Open the picker UI.
--- @param on_submit fun(prompt: string, model: string)
function M.open(on_submit)
  local entries = history.get_sorted()
  if #entries == 0 then
    M._open_prompt_only(on_submit)
  else
    M._open_full(entries, on_submit)
  end
end

return M
