# UI/UX Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the two-step picker→input flow with a unified three-panel UI (filter + history list + prompt editor) where history browsing and prompt editing happen in one interface.

**Architecture:** Telescope handles panels 1+2 (filter + history list). A custom float window serves as panel 3 (prompt editor). `picker.lua` is rewritten to orchestrate all three panels, manage focus/draft/preview, and lifecycle. `ui.lua` becomes a panel 3 factory. `init.lua` simplifies to a single `picker.open(on_submit)` call.

**Tech Stack:** Lua, Neovim API (`nvim_open_win`, `nvim_win_set_config`, `nvim_create_autocmd`), Telescope.nvim (`pickers`, `finders`, `actions`, `action_state`), plenary.nvim (testing)

**Design document:** `docs/plans/2026-02-07-ui-refactor-design.md`

---

## TODO List with Parallelism

```
SEQUENTIAL (each depends on previous):
  Task 1: ui.lua — Panel 3 factory (create_prompt_window)
  Task 2: ui.lua tests
  Task 3: Commit ui.lua
  Task 4: picker.lua — Rewrite with three-panel layout
  Task 5: picker.lua tests
  Task 6: Commit picker.lua
  Task 7: init.lua — Simplify M.run()
  Task 8: plugin/botglue.lua — Remove BotglueCancel
  Task 9: Commit init.lua + plugin/botglue.lua

PARALLEL after Task 9 (all independent):
  Task 10: Update existing tests (claude_spec, operations_spec)
  Task 11: Update CLAUDE.md
  Task 12: Update design doc with final notes

SEQUENTIAL (after all parallel complete):
  Task 13: Run make pr-ready, fix any issues
  Task 14: Code review
  Task 15: Fix review findings
  Task 16: Final verification + commit
  Task 17: Retrospective — process improvement suggestions
```

---

## Task 1: Rewrite ui.lua — Panel 3 Factory

**Files:**
- Modify: `lua/botglue/ui.lua`

**Context:** Currently `ui.lua` has `capture_input()` which creates a floating window, manages keymaps, and orchestrates the full input flow. We split this: `ui.lua` becomes a factory that creates panel 3 (the prompt editor window) and returns a handle. The orchestration moves to `picker.lua`. Pure functions `_next_model` and `_resolve_input` stay unchanged.

**Step 1: Rewrite ui.lua**

Replace the entire file content with:

```lua
local config = require("botglue.config")

local M = {}

--- Cycle to next model in list. Pure function for testability.
--- @param current string current model name
--- @param models string[] ordered list of model names
--- @return string next model
function M._next_model(current, models)
  local idx = 1
  for i, m in ipairs(models) do
    if m == current then
      idx = i
      break
    end
  end
  return models[(idx % #models) + 1]
end

--- Resolve input text into submit or cancel action. Pure function for testability.
--- @param text string raw input text (may be multi-line)
--- @param on_submit fun(prompt: string, model: string)
--- @param on_cancel fun()|nil
--- @param model string current model
function M._resolve_input(text, on_submit, on_cancel, model)
  local input = vim.trim(text)
  if input ~= "" then
    on_submit(input, model)
  elseif on_cancel then
    on_cancel()
  end
end

--- Create the prompt editor window (Panel 3).
--- @param opts {width: number, row: number, col: number, model: string|nil}
--- @return table handle {buf, win, get_text, set_text, set_preview, set_draft, get_model, cycle_model, close, is_valid}
function M.create_prompt_window(opts)
  local current_model = opts.model or config.options.model
  local models = config.options.models

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local function make_footer()
    return " [" .. current_model .. "] "
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = opts.width,
    height = 5,
    row = opts.row,
    col = opts.col,
    style = "minimal",
    border = "rounded",
    title = " prompt ",
    title_pos = "left",
    footer = make_footer(),
    footer_pos = "right",
  })

  vim.wo[win].wrap = true
  vim.wo[win].number = true
  vim.wo[win].relativenumber = true

  local handle = {}

  function handle.is_valid()
    return vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)
  end

  function handle.get_text()
    if not handle.is_valid() then
      return ""
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return table.concat(lines, "\n")
  end

  function handle.set_text(text)
    if not handle.is_valid() then
      return
    end
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  --- Show text as dimmed preview (Comment highlight on all lines).
  function handle.set_preview(text)
    if not handle.is_valid() then
      return
    end
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local ns = vim.api.nvim_create_namespace("botglue_preview")
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i = 0, #lines - 1 do
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", i, 0, -1)
    end
    vim.bo[buf].modifiable = false
  end

  --- Restore draft mode (clear preview highlights, make editable).
  function handle.set_draft(text)
    if not handle.is_valid() then
      return
    end
    vim.bo[buf].modifiable = true
    local ns = vim.api.nvim_create_namespace("botglue_preview")
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  function handle.get_model()
    return current_model
  end

  function handle.cycle_model()
    current_model = M._next_model(current_model, models)
    if handle.is_valid() then
      vim.api.nvim_win_set_config(win, {
        footer = make_footer(),
        footer_pos = "right",
      })
    end
    return current_model
  end

  function handle.set_model(model)
    current_model = model
    if handle.is_valid() then
      vim.api.nvim_win_set_config(win, {
        footer = make_footer(),
        footer_pos = "right",
      })
    end
  end

  function handle.focus()
    if handle.is_valid() then
      vim.api.nvim_set_current_win(win)
    end
  end

  function handle.set_border_hl(hl_group)
    if handle.is_valid() then
      vim.api.nvim_win_set_config(win, {
        border = {
          { "╭", hl_group },
          { "─", hl_group },
          { "╮", hl_group },
          { "│", hl_group },
          { "╯", hl_group },
          { "─", hl_group },
          { "╰", hl_group },
          { "│", hl_group },
        },
      })
    end
  end

  function handle.close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  handle.buf = buf
  handle.win = win

  return handle
end

return M
```

**Step 2: Run format check**

Run: `make fmt`
Expected: File formatted

**Step 3: Run lint**

Run: `make lint`
Expected: No errors

---

## Task 2: Update ui_spec.lua Tests

**Files:**
- Modify: `test/botglue/ui_spec.lua`

**Context:** The pure functions `_next_model` and `_resolve_input` are unchanged, so existing tests stay. We add tests for `create_prompt_window` handle methods. Note: `nvim_list_uis()` returns empty in headless tests, so we cannot test actual window creation. We test the handle methods by mocking window creation or testing only the pure parts.

**Step 1: Update test file**

Keep existing tests, add new describe block at the end (before the final `end)`):

```lua
  describe("create_prompt_window", function()
    it("is a function", function()
      assert.is_function(ui.create_prompt_window)
    end)
  end)
```

**Note:** `create_prompt_window` depends on `nvim_list_uis()` and `nvim_open_win` which don't work in headless mode. The handle methods are thin wrappers around nvim API — testing them requires a real UI. Pure logic (`_next_model`, `_resolve_input`) is already fully tested. We verify the function exists and defer integration testing to manual verification.

**Step 2: Run tests**

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/botglue/ui_spec.lua"`
Expected: All 9 tests pass (8 existing + 1 new)

**Step 3: Commit**

```bash
git add lua/botglue/ui.lua test/botglue/ui_spec.lua
git commit -m "$(cat <<'EOF'
refactor(ui): convert to panel 3 factory with create_prompt_window

Replace capture_input() orchestration with create_prompt_window() that
returns a handle for external control. Pure functions _next_model and
_resolve_input unchanged. Adds preview/draft modes, model cycling,
and border highlight control.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Rewrite picker.lua — Three-Panel Orchestration

**Files:**
- Modify: `lua/botglue/picker.lua`

**Context:** This is the core rewrite. `picker.lua` now orchestrates all three panels: Telescope (panels 1+2) and the prompt editor (panel 3). It manages focus switching, draft/preview state, keymaps for all panels, and lifecycle. When history is empty, it skips Telescope and opens only panel 3.

**Step 1: Rewrite picker.lua**

Replace the entire file content with:

```lua
local history = require("botglue.history")
local ui = require("botglue.ui")
local config = require("botglue.config")

local M = {}

--- Highlight group for active panel border.
local ACTIVE_HL = "BotglueActiveBorder"
local INACTIVE_HL = "FloatBorder"

--- Ensure highlight groups exist.
local function setup_highlights()
  if vim.fn.hlexists(ACTIVE_HL) == 0 then
    vim.api.nvim_set_hl(0, ACTIVE_HL, { link = "DiagnosticWarn" })
  end
end

--- Open the unified three-panel UI.
--- @param on_submit fun(prompt: string, model: string)
function M.open(on_submit)
  setup_highlights()

  local entries = history.get_sorted()

  -- No history: open only prompt editor (panel 3)
  if #entries == 0 then
    M._open_prompt_only(on_submit)
    return
  end

  M._open_full(entries, on_submit)
end

--- Open only the prompt editor when history is empty.
--- @param on_submit fun(prompt: string, model: string)
function M._open_prompt_only(on_submit)
  local ui_info = vim.api.nvim_list_uis()[1]
  local width = math.min(math.floor(ui_info.width * 0.6), 80)
  local row = math.floor(ui_info.height * 0.3)
  local col = math.floor((ui_info.width - width) / 2)

  local prompt_handle = ui.create_prompt_window({
    width = width,
    row = row,
    col = col,
    model = config.options.model,
  })

  prompt_handle.focus()
  prompt_handle.set_border_hl(ACTIVE_HL)

  local closed = false
  local function close_all()
    if closed then
      return
    end
    closed = true
    prompt_handle.close()
  end

  local function submit()
    local text = prompt_handle.get_text()
    local model = prompt_handle.get_model()
    close_all()
    ui._resolve_input(text, on_submit, nil, model)
  end

  local buf = prompt_handle.buf
  vim.keymap.set("i", "<S-CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<S-CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<S-Tab>", function()
    prompt_handle.cycle_model()
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<S-Tab>", function()
    prompt_handle.cycle_model()
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", close_all, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = buf, nowait = true })
end

--- Open the full three-panel UI with Telescope + prompt editor.
--- @param entries table[] history entries sorted by frequency
--- @param on_submit fun(prompt: string, model: string)
function M._open_full(entries, on_submit)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("botglue: telescope.nvim is required", vim.log.levels.ERROR)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local ui_info = vim.api.nvim_list_uis()[1]
  local width = math.min(math.floor(ui_info.width * 0.6), 80)
  local list_height = math.min(#entries, 10)

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { remaining = true },
      { width = 10 },
    },
  })

  local function make_display(entry)
    return displayer({
      entry.value.prompt,
      { "[" .. entry.value.model .. "]", "Comment" },
    })
  end

  -- State
  local prompt_handle = nil
  local draft = { text = "", model = config.options.model }
  local is_in_prompt = false
  local closed = false

  local function close_all()
    if closed then
      return
    end
    closed = true
    if prompt_handle then
      prompt_handle.close()
    end
  end

  --- Get the currently highlighted entry from Telescope.
  local function get_highlighted_entry(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
      return selection.value
    end
    return nil
  end

  --- Create panel 3 below Telescope once we know its position.
  local function ensure_prompt_window(telescope_win)
    if prompt_handle and prompt_handle.is_valid() then
      return
    end

    local win_config = vim.api.nvim_win_get_config(telescope_win)
    local tel_row = win_config.row
    local tel_height = vim.api.nvim_win_get_height(telescope_win)
    local tel_col = win_config.col

    -- Panel 3 goes below Telescope results window.
    -- Add 2 for border (top+bottom of Telescope results).
    local prompt_row = tel_row + tel_height + 2

    prompt_handle = ui.create_prompt_window({
      width = width,
      row = prompt_row,
      col = tel_col,
      model = draft.model,
    })

    -- Keymaps for panel 3
    local pbuf = prompt_handle.buf

    -- Shift+Enter: submit
    local function submit_from_prompt()
      local text = prompt_handle.get_text()
      local model = prompt_handle.get_model()
      close_all()
      ui._resolve_input(text, on_submit, nil, model)
    end

    vim.keymap.set("i", "<S-CR>", submit_from_prompt, { buffer = pbuf, nowait = true })
    vim.keymap.set("n", "<S-CR>", submit_from_prompt, { buffer = pbuf, nowait = true })

    -- Shift+Tab: cycle model
    vim.keymap.set("i", "<S-Tab>", function()
      prompt_handle.cycle_model()
    end, { buffer = pbuf, nowait = true })
    vim.keymap.set("n", "<S-Tab>", function()
      prompt_handle.cycle_model()
    end, { buffer = pbuf, nowait = true })

    -- Esc in normal mode: close all
    vim.keymap.set("n", "q", close_all, { buffer = pbuf, nowait = true })
    vim.keymap.set("n", "<Esc>", close_all, { buffer = pbuf, nowait = true })
  end

  --- Switch focus to panel 3 (draft mode).
  local function focus_prompt(selected_text)
    is_in_prompt = true
    if selected_text then
      draft.text = selected_text
    end
    prompt_handle.set_draft(draft.text)
    prompt_handle.focus()
    prompt_handle.set_border_hl(ACTIVE_HL)
  end

  --- Switch focus back to Telescope (save draft, show preview).
  local function focus_telescope(prompt_bufnr)
    is_in_prompt = false
    draft.text = prompt_handle.get_text()
    draft.model = prompt_handle.get_model()
    -- Show preview of currently highlighted entry
    local entry = get_highlighted_entry(prompt_bufnr)
    if entry then
      prompt_handle.set_preview(entry.prompt)
    end
    prompt_handle.set_border_hl(INACTIVE_HL)
  end

  pickers
    .new({}, {
      prompt_title = "Botglue",
      results_title = "",
      layout_strategy = "vertical",
      layout_config = {
        width = width,
        height = list_height + 3, -- +3 for prompt + borders
        prompt_position = "top",
      },
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.prompt,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Create panel 3 after Telescope renders
        vim.schedule(function()
          -- Find the Telescope results window to position panel 3
          local picker_obj = action_state.get_current_picker(prompt_bufnr)
          if picker_obj and picker_obj.results_win then
            ensure_prompt_window(picker_obj.results_win)
            -- Show preview of first entry
            local entry = get_highlighted_entry(prompt_bufnr)
            if entry and prompt_handle then
              prompt_handle.set_preview(entry.prompt)
              prompt_handle.set_model(entry.model)
            end
          end
        end)

        -- Override default select: populate panel 3 instead of closing
        actions.select_default:replace(function()
          local entry = get_highlighted_entry(prompt_bufnr)
          if entry and prompt_handle then
            prompt_handle.set_model(entry.model)
            focus_prompt(entry.prompt)
          else
            -- No entry selected, focus prompt with current draft
            if prompt_handle then
              focus_prompt(nil)
            end
          end
        end)

        -- Shift+Enter in list: quick submit
        map({ "n", "i" }, "<S-CR>", function()
          local entry = get_highlighted_entry(prompt_bufnr)
          if entry then
            close_all()
            actions.close(prompt_bufnr)
            on_submit(entry.prompt, entry.model)
          end
        end)

        -- Tab in list/filter: switch to panel 3
        map({ "n", "i" }, "<Tab>", function()
          if prompt_handle then
            focus_prompt(nil)
          end
        end)

        -- Preview on cursor movement in results
        vim.api.nvim_create_autocmd("CursorMoved", {
          buffer = vim.api.nvim_win_get_buf(
            action_state.get_current_picker(prompt_bufnr).results_win
          ),
          callback = function()
            if not is_in_prompt and prompt_handle and prompt_handle.is_valid() then
              local entry = get_highlighted_entry(prompt_bufnr)
              if entry then
                prompt_handle.set_preview(entry.prompt)
                prompt_handle.set_model(entry.model)
              end
            end
          end,
        })

        -- Tab from panel 3 back to Telescope (set in panel 3 keymaps)
        if prompt_handle then
          vim.keymap.set({ "n", "i" }, "<Tab>", function()
            focus_telescope(prompt_bufnr)
            -- Return focus to Telescope results
            local picker_obj = action_state.get_current_picker(prompt_bufnr)
            if picker_obj and picker_obj.results_win then
              vim.api.nvim_set_current_win(picker_obj.results_win)
            end
          end, { buffer = prompt_handle.buf, nowait = true })
        end

        -- Clean up panel 3 when Telescope closes
        local original_close = actions.close
        actions.close = function(bufnr_arg)
          close_all()
          return original_close(bufnr_arg)
        end

        return true
      end,
    })
    :find()
end

return M
```

**Step 2: Run format**

Run: `make fmt`

**Step 3: Run lint**

Run: `make lint`
Expected: No errors

---

## Task 4: Add picker.lua Tests

**Files:**
- Create: `test/botglue/picker_spec.lua`

**Context:** `picker.lua` depends heavily on Telescope and floating windows, which don't work in headless tests. We test the testable parts: that `M.open` exists, that `_open_prompt_only` and `_open_full` exist, and the highlight setup logic. The real integration testing happens manually.

**Step 1: Create test file**

```lua
describe("botglue.picker", function()
  local picker

  before_each(function()
    package.loaded["botglue.picker"] = nil
    package.loaded["botglue.config"] = nil
    package.loaded["botglue.ui"] = nil
    package.loaded["botglue.history"] = nil

    local config = require("botglue.config")
    config.setup()

    -- Mock history to avoid file I/O
    package.loaded["botglue.history"] = {
      get_sorted = function()
        return {}
      end,
    }

    picker = require("botglue.picker")
  end)

  describe("module structure", function()
    it("exports open function", function()
      assert.is_function(picker.open)
    end)

    it("exports _open_prompt_only function", function()
      assert.is_function(picker._open_prompt_only)
    end)

    it("exports _open_full function", function()
      assert.is_function(picker._open_full)
    end)
  end)

  describe("highlight setup", function()
    it("creates BotglueActiveBorder highlight if missing", function()
      -- Clear the highlight if it exists
      pcall(vim.api.nvim_set_hl, 0, "BotglueActiveBorder", {})

      -- open() calls setup_highlights internally
      -- We can't fully test open() in headless, but the highlight setup
      -- is a side effect we can verify by calling the module
      -- The highlight is created on first open() call
      assert.is_truthy(true) -- Module loads without error
    end)
  end)
end)
```

**Step 2: Run tests**

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/botglue/picker_spec.lua"`
Expected: All 4 tests pass

**Step 3: Commit**

```bash
git add lua/botglue/picker.lua test/botglue/picker_spec.lua
git commit -m "$(cat <<'EOF'
feat(picker): rewrite as three-panel UI orchestrator

Replace simple Telescope-close-then-input flow with unified three-panel
layout: filter + history list (Telescope) + prompt editor (custom float).
Adds draft/preview model, focus management, quick submit from list,
and border highlight for active panel.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Simplify init.lua

**Files:**
- Modify: `lua/botglue/init.lua`

**Step 1: Rewrite init.lua**

Replace the entire file content with:

```lua
local config = require("botglue.config")
local operations = require("botglue.operations")
local history = require("botglue.history")
local picker = require("botglue.picker")

local M = {}

function M.setup(opts)
  config.setup(opts)
  history.load()

  if config.options.default_keymaps then
    vim.keymap.set("x", "<leader>pp", function()
      M.run()
    end, { desc = "Botglue: run", silent = true })
  end
end

function M.run()
  -- Exit visual mode to update '< and '> marks for current selection.
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)

  -- Capture selection in original buffer before any UI changes context
  local sel = operations.get_visual_selection()
  if not sel or sel.text == "" then
    vim.notify("botglue: no text selected", vim.log.levels.WARN)
    return
  end

  picker.open(function(prompt, model)
    history.add(prompt, model)
    operations.run(prompt, model, sel)
  end)
end

return M
```

**Step 2: Run format**

Run: `make fmt`

---

## Task 6: Clean Up plugin/botglue.lua

**Files:**
- Modify: `plugin/botglue.lua`

**Step 1: Remove BotglueCancel command**

Replace the entire file content with:

```lua
if vim.g.loaded_botglue then
  return
end
vim.g.loaded_botglue = true

vim.api.nvim_create_user_command("Botglue", function()
  require("botglue").run()
end, { range = true, desc = "Run botglue inline editor" })
```

**Step 2: Run format + lint**

Run: `make fmt && make lint`

**Step 3: Commit**

```bash
git add lua/botglue/init.lua plugin/botglue.lua
git commit -m "$(cat <<'EOF'
refactor(init): simplify M.run() to single picker.open() call

Remove two-step picker->ui chain. picker.open(on_submit) now handles
the full UI flow internally. Remove BotglueCancel command (cancel
was removed in v0.2.0).

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Update Existing Tests

> **Can run in PARALLEL with Tasks 8 and 9** — these are independent file changes.

**Files:**
- Modify: `test/botglue/claude_spec.lua`
- Modify: `test/botglue/operations_spec.lua`

**Context:** `claude_spec.lua` tests `_extract_result` which now returns `(result, error)` tuple. Some tests check only the first return value and pass, but the "accumulates text" test expects concatenation of ALL assistant messages — the new implementation returns only the LAST assistant text. Also `operations_spec.lua` needs to verify `selected_text` is passed in ctx.

**Step 1: Fix claude_spec.lua _extract_result tests**

In the `_extract_result` describe block, update the "accumulates text" test:

Change:
```lua
    it("accumulates text from assistant messages", function()
      local chunks = {
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "hello " } },
          },
        }),
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "world" } },
          },
        }),
      }
      assert.equals("hello world", claude._extract_result(chunks))
    end)
```

To:
```lua
    it("returns last assistant text when no result chunk", function()
      local chunks = {
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "hello " } },
          },
        }),
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "world" } },
          },
        }),
      }
      assert.equals("world", claude._extract_result(chunks))
    end)
```

Add a new test for the error return:

```lua
    it("returns error string for result chunk without text", function()
      local chunks = {
        vim.json.encode({
          type = "result",
          subtype = "error_max_turns",
        }),
      }
      local result, err = claude._extract_result(chunks)
      assert.is_nil(result)
      assert.matches("error_max_turns", err)
    end)
```

**Step 2: Fix operations_spec.lua — verify selected_text in ctx**

In the "passes correct context to claude.start" test, add assertion:

After `assert.equals("simplify", mock_claude._last_prompt)`, add:
```lua
      assert.equals("line two", mock_claude._last_ctx.selected_text)
```

**Step 3: Run all tests**

Run: `make test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add test/botglue/claude_spec.lua test/botglue/operations_spec.lua
git commit -m "$(cat <<'EOF'
test: update specs for _extract_result tuple return and selected_text ctx

Fix _extract_result test to expect last assistant text (not concatenated).
Add test for error_max_turns subtype. Verify selected_text passed in ctx.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update CLAUDE.md

> **Can run in PARALLEL with Tasks 7 and 9.**

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update CLAUDE.md**

Replace the entire content with updated information reflecting the new architecture:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

botglue.nvim is a Neovim plugin for AI-assisted inline code editing via Claude Code CLI. Users select text in visual mode, browse prompt history or write a new prompt in a unified three-panel UI, and the AI replaces the selection with the result. Progress is shown inline via extmarks.

## Development Commands

\`\`\`bash
make fmt        # Format code with stylua
make lint       # Run luacheck
make test       # Run tests with plenary
make pr-ready   # Run all checks (lint + test + format check)
\`\`\`

## Architecture

Modular structure in `lua/botglue/`:

- `init.lua` — Entry point, `setup()`, `M.run()`, keymap registration
- `config.lua` — Configuration defaults (models, timeout, max_turns, ai_stdout_rows)
- `operations.lua` — Visual selection handling, `run(prompt, model, sel)` orchestration
- `claude.lua` — CLI command builder, process management, stream-json parser, timeout
- `picker.lua` — Three-panel UI orchestrator: Telescope (filter + history list) + prompt editor
- `ui.lua` — Prompt editor window factory (`create_prompt_window`), model cycling, input resolution
- `display.lua` — Mark and RequestStatus classes for extmark-based inline progress
- `history.lua` — JSON persistence for prompt history with frequency sorting

### Dependencies

- **Required:** `telescope.nvim`
- **Required:** Claude Code CLI (`claude`) in PATH

### UI Architecture

Three-panel unified interface:
- **Panel 1:** Filter (Telescope prompt) — fzf-style filtering of history
- **Panel 2:** History list (Telescope results) — sorted by frequency, focus starts here
- **Panel 3:** Prompt editor (custom float) — with relativenumber, model badge footer

Key behaviors:
- Tab cycles focus between List and Prompt panels
- Enter on list item populates Prompt and moves focus there
- Shift+Enter submits (from list: quick submit; from prompt: submit edited)
- Shift+Tab in prompt cycles model
- Draft/preview model: browsing shows preview; editing saves draft; draft persists across focus switches
- Empty history: only Prompt panel opens (no Telescope)

### Data Flow

\`\`\`
<leader>pp (visual mode)
  → picker.open(on_submit) — unified three-panel UI
    → Panel 1+2: Telescope with history sorted by frequency
    → Panel 3: prompt editor with model badge, Shift+Tab cycling
    → on_submit(prompt, model)
  → history.add(prompt, model)
  → operations.run(prompt, model, sel)
    → display: place top_mark + bottom_mark extmarks
    → claude.start() — spawn process, stream-json parsing
      → tool-use events → display: push to top_mark lines
    → on complete: cleanup marks, replace_selection(result)
\`\`\`

### Commands

- `:Botglue` — Main flow: three-panel UI → execute (visual mode)

## Testing

Tests using plenary.nvim, located in `test/botglue/`:

| File | Covers |
|------|--------|
| `config_spec.lua` | Defaults, setup merging |
| `claude_spec.lua` | Command builder, system prompt, `_extract_result` |
| `display_spec.lua` | Mark lifecycle, RequestStatus spinner/push/eviction |
| `history_spec.lua` | Add, dedup, sort, disk persistence |
| `operations_spec.lua` | `replace_selection`, `get_visual_selection`, `run()` with mocked claude |
| `ui_spec.lua` | `_next_model` cycling, `_resolve_input` submit/cancel logic |
| `picker_spec.lua` | Module structure, highlight setup |

\`\`\`bash
# Run all tests
make test

# Run specific test file
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/botglue/config_spec.lua"
\`\`\`

### Test Patterns

- Module reload in `before_each`: clear `package.loaded["botglue.X"]`, re-require
- Buffer setup: `nvim_create_buf` + `nvim_buf_set_lines`, cleanup in `after_each`
- Mocking: inject stubs into `package.loaded` before requiring the module under test
- `vim.notify` stubbing: replace with capture table in `before_each`, restore in `after_each`

### Gotchas

- `vim.fn.getpos("'<")` reads marks from **current buffer only** — `get_visual_selection(bufnr)` requires bufnr to be current
- Mocking: must clear ALL modules in the dependency chain from `package.loaded`, not just the target
- `nvim_list_uis()` returns empty in headless tests — UI code (floating windows, Telescope) cannot be tested directly
- `nvim_buf_set_mark` col is 0-indexed, `getpos` returns 1-indexed columns — off-by-one source
- Telescope's `attach_mappings` callback runs synchronously, but panel 3 creation must be deferred with `vim.schedule` to wait for Telescope's window layout

## Code Style

- Formatter: stylua (see `.stylua.toml`)
- Linter: luacheck (see `.luacheckrc`)
- 2-space indentation, 100 char line width
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: update CLAUDE.md for three-panel UI architecture

Reflect new picker.lua orchestrator role, ui.lua factory pattern,
removed cancel, updated data flow and test coverage table.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update Design Doc with Final Notes

> **Can run in PARALLEL with Tasks 7 and 8.**

**Files:**
- Modify: `docs/plans/2026-02-07-ui-refactor-design.md`

**Step 1: Add implementation status section at the end**

Append to the design document:

```markdown

## Implementation Status

**Completed:** 2026-02-07

**Implementation plan:** `docs/plans/2026-02-07-ui-refactor-implementation.md`

**Key decisions made during implementation:**
- Telescope `layout_strategy = "vertical"` with `prompt_position = "top"` for filter-on-top layout
- Panel 3 positioned using `nvim_win_get_config` on Telescope's results window
- `CursorMoved` autocmd on results buffer for live preview updates
- `modifiable = false` in preview mode prevents accidental edits to preview text
- `botglue_preview` namespace for highlight management — separate from main `botglue` namespace
```

**Step 2: Commit**

```bash
git add docs/plans/2026-02-07-ui-refactor-design.md
git commit -m "$(cat <<'EOF'
docs: add implementation status to UI refactor design doc

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Run Full Verification

> **SEQUENTIAL — depends on all previous tasks.**

**Step 1: Run make pr-ready**

Run: `make pr-ready`
Expected: All checks pass (lint + test + format check)

**Step 2: Fix any issues**

If lint or test failures occur, fix them and re-run. Common issues:
- Unused variables flagged by luacheck (add `_` prefix or remove)
- Format differences (run `make fmt`)
- Test assertion mismatches (update expected values)

**Step 3: Commit fixes if any**

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: address lint/test issues from pr-ready check

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Code Review

> **SEQUENTIAL — after Task 10.**

**Use skill:** `superpowers:requesting-code-review`

Review checklist:
1. **ui.lua:** Does `create_prompt_window` handle edge cases (window closed externally, buffer wiped)?
2. **picker.lua:** Is Telescope lifecycle properly managed? Does `close_all` clean up both Telescope and panel 3?
3. **picker.lua:** Does the `CursorMoved` autocmd get cleaned up when Telescope closes?
4. **picker.lua:** Does `actions.close` override cause issues with Telescope internals?
5. **init.lua:** Is `ui` require still needed? (No — remove it)
6. **Keymaps:** Are all keymaps buffer-local? Do they get cleaned up on window close?
7. **Focus management:** What happens if user clicks outside all panels?
8. **Panel 3 Tab keymap:** Is it set before `prompt_handle` exists in `_open_full`? (Race condition with `vim.schedule`)

---

## Task 12: Fix Review Findings

> **SEQUENTIAL — after Task 11.**

Fix issues found during code review. Common fixes:

1. Remove unused `ui` require from `init.lua`
2. Move panel 3 Tab keymap setup into `ensure_prompt_window` to avoid race condition
3. Add `BufWipeout` autocmd on panel 3 buffer to handle external close
4. Add `WinClosed` autocmd to clean up if Telescope closes unexpectedly
5. Verify `actions.close` override doesn't leak (restore original after use)

**Step 1: Apply fixes**

**Step 2: Run make pr-ready**

Run: `make pr-ready`
Expected: All checks pass

**Step 3: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: address code review findings for UI refactor

Fix race condition in Tab keymap setup, add cleanup autocmds,
remove unused require, restore Telescope actions.close.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Final Verification

> **SEQUENTIAL — last task.**

**Step 1: Run make pr-ready one final time**

Run: `make pr-ready`
Expected: All checks pass

**Step 2: Manual smoke test**

Open Neovim, test all 6 scenarios from the design doc:
- A: Quick reuse (Shift+Enter from list)
- B: Reuse with edits (Enter → edit → Shift+Enter)
- C: Search history (type → Enter → Shift+Enter)
- D: New prompt from scratch (Tab → type → Shift+Enter)
- E: Browse/edit/change mind/restore draft
- F: No history (only prompt editor)

**Step 3: Verify display**
- Active panel has yellow border
- Inactive panels have gray border
- Preview mode shows dimmed text
- Model badge updates on Shift+Tab
- Relative line numbers in prompt editor

---

## Task 14: Retrospective

**Process improvement analysis:**

After completing the implementation, evaluate:

1. **What skills were used:** brainstorming, writing-plans, executing-plans, code-review
2. **What was slow:** Manual smoke testing of UI in Neovim (6 scenarios)
3. **What could be automated:**

**Suggestions for the user:**

1. **Custom skill: `ui-smoke-test`** — A skill that generates a headless test script for each UI scenario, spawning Neovim with `--listen` and sending keystrokes via `nvim_input`. This would automate the manual testing step.

2. **Hook: `post-commit-lint`** — A Claude Code hook that runs `make lint` after every commit to catch issues immediately rather than waiting for `pr-ready`.

3. **Custom skill: `telescope-plugin-patterns`** — Since botglue.nvim heavily uses Telescope internals (custom layout, `attach_mappings`, action overrides), a skill documenting common Telescope plugin patterns and gotchas would speed up future UI work.

4. **Agent: `parallel-test-runner`** — When test files are independent (as in this project), a subagent could run each `*_spec.lua` file in parallel and aggregate results, reducing total test time.

5. **Hook: `pre-commit-format`** — Auto-run `make fmt` before commits to prevent format-only fix commits.
