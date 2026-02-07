# Picker Rewrite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Telescope-based picker with three custom float windows (filter + list + prompt) for full control over focus, keymaps, and borders.

**Architecture:** Three custom float windows owned by `picker.lua`. Panel 1 (filter) is a 1-line input buffer. Panel 2 (list) is a read-only buffer with `cursorline=true`. Panel 3 (prompt) uses the existing `ui.create_prompt_window` factory. Focus management, draft/preview state, and lifecycle are all in `picker.lua` closures. Telescope dependency removed entirely.

**Tech Stack:** Lua, Neovim API (`nvim_open_win`, `nvim_create_buf`, `nvim_create_autocmd`), `vim.fn.matchfuzzy` for filtering

**Design document:** `docs/plans/2026-02-07-picker-rewrite-design.md`

---

## Task 1: Rewrite picker.lua

**Files:**
- Modify: `lua/botglue/picker.lua`

**Step 1: Replace the entire file with:**

```lua
local history = require("botglue.history")
local config = require("botglue.config")
local ui = require("botglue.ui")

local M = {}

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
```

**Step 2: Run format + lint**

Run: `make fmt && make lint`
Expected: No errors

---

## Task 2: Update README.md — Remove Telescope Dependency

**Files:**
- Modify: `README.md`

**Step 1: Update requirements section**

Remove the telescope.nvim line from Requirements:
```markdown
## Requirements

- Neovim 0.10+
- [Claude Code CLI](https://claude.ai/code) installed and available in PATH
```

**Step 2: Update lazy.nvim installation**

Remove `dependencies`:
```lua
{
  "heliotik/botglue.nvim",
  config = function()
    require("botglue").setup()
  end,
}
```

**Step 3: Update packer.nvim installation**

Remove `requires`:
```lua
use {
  "heliotik/botglue.nvim",
  config = function()
    require("botglue").setup()
  end,
}
```

**Step 4: Update Controls section**

Replace the Controls section with updated keymaps:

```markdown
### Controls

**History list (Panel 2):**
- `j`/`k` — navigate, preview shown in prompt editor
- `Enter` — select and move to prompt editor
- `Ctrl+S` — quick submit without editing
- `/` — open filter
- `Tab` — move to prompt editor
- `Esc`/`q` — close

**Filter (Panel 1):**
- Type — fuzzy filter history list
- `Ctrl+J`/`Ctrl+K` — navigate list without leaving filter
- `Enter` — select top match, move to prompt editor
- `Esc` — clear filter, return to list
- `Tab` — move to prompt editor

**Prompt editor (Panel 3):**
- `Enter` — new line (insert mode) / submit (normal mode)
- `Ctrl+S` — submit prompt (any mode)
- `Shift+Tab` — cycle model (opus → sonnet → haiku)
- `Tab` — return to history list
- `q` / `Esc` — close (normal mode)
```

**Step 5: Update Workflow step 4-6**

```markdown
4. Browse history with `j`/`k`, press `/` to filter, or `Tab` to prompt editor
5. `Enter` on a history item populates the prompt editor for editing
6. `Ctrl+S` submits — from history list (quick submit) or from prompt editor. `Enter` in normal mode also submits from prompt editor
```

---

## Task 3: Run All Checks

**Step 1: Run full verification**

Run: `make pr-ready`
Expected: All checks pass (lint + test + format check)

**Step 2: Fix any issues**

If lint flags unused variables: prefix with `_` or remove.
If format differs: `make fmt` already ran in Task 1.

---

## Task 4: Commit

**Step 1: Commit all changes**

```bash
git add lua/botglue/picker.lua README.md
git commit -m "$(cat <<'EOF'
feat(picker): rewrite with custom float windows, drop Telescope

Replace Telescope-based picker with three custom float windows for full
control over focus, keymaps, and borders. Telescope's results window had
focusable=false which broke focus management, j/k navigation, CursorMoved
preview, and border highlights.

New architecture: Filter (1-line input) + List (cursorline, focusable) +
Prompt editor (existing ui.lua factory). Fuzzy filtering via matchfuzzy.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Manual Smoke Test

Open Neovim, test all 6 scenarios from the design doc:

- **A:** Quick reuse — `<leader>pp` → `j`/`k` → `Ctrl+S` → submitted
- **B:** Reuse with edits — `j`/`k` → `Enter` → edit → `Enter` (normal) → submitted
- **C:** Search history — `/` → type filter → `Enter` → edit → `Ctrl+S`
- **D:** New prompt — `Tab` → type → `Enter` (normal) → submitted
- **E:** Draft persistence — `Enter` on item → edit → `Tab` → browse → `Tab` → draft restored
- **F:** No history — clear history file → `<leader>pp` → only Panel 3 opens

Verify:
- [ ] Yellow border on active panel, gray on inactive
- [ ] Preview updates when navigating list with `j`/`k`
- [ ] `Ctrl+J`/`Ctrl+K` navigate list from filter
- [ ] Filter clears on `Esc` from filter
- [ ] All `Esc`/`q` close all three panels
- [ ] Model cycling with `Shift+Tab` in prompt
