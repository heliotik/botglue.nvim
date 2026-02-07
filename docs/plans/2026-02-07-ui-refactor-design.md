# UI/UX Refactor Design: Three-Panel Unified Interface

**Goal:** Replace the current two-step flow (Telescope picker -> separate input window) with a single three-panel UI where history browsing and prompt editing happen in one unified interface.

## Current State

Two sequential steps:
1. **Picker** (`picker.lua`) — Telescope picker with history list. Closes after selection.
2. **Input** (`ui.lua`) — Separate floating window opens after Telescope closes. User edits prompt and submits.

Flow: `init.lua:M.run()` -> `picker.open(callback)` -> `ui.capture_input(opts, on_submit)` -> `operations.run()`

## Problems

1. Focus starts on Telescope filter, not on the results list
2. Telescope results area stretches to half-screen even with 2-3 items
3. List navigation only via arrow keys from filter (no Ctrl+j/Ctrl+k)
4. No visual indication of active panel (no highlighted border)
5. Prompt input is a separate step — not visible alongside history
6. No preview of multi-line prompts while browsing history
7. No line numbers in prompt editor (can't use vim motions efficiently)
8. Enter/Shift+Enter behavior is inverted (Enter submits instead of newline)
9. Ctrl+S for model cycling conflicts with terminal conventions

## New Design

### Layout

```
+-- Botglue --------------------------+
| > _                                 |  <- Panel 1: Filter (Telescope prompt)
+-----------+-------------------------+
|   translate to english         [ha] |  <- Panel 2: History list
| > fix errors                   [so] |     Focus starts here
|   add comments                 [op] |     Height: min(#items, 10)
+-----------+-------------------------+
|  3|                                 |  <- Panel 3: Prompt editor
|  2|                                 |     Height: 5 lines fixed
|  1|                                 |     relativenumber = true, number = true
|  1|                                 |     Footer: [haiku]
|  2|                                 |
+-----------+-------------------------+
```

**Sizing:**
- Width: 60% of editor width (capped at 80 cols)
- Panel 1 (filter): 1 line (Telescope default)
- Panel 2 (list): `min(#history_items, 10)` rows
- Panel 3 (prompt): 5 lines fixed, `relativenumber = true`, `number = true`
- Centered horizontally, vertically offset ~30% from top
- When history is empty: only Panel 3 opens (standalone float, same width, 5 lines)

**Visual distinction:**
- Active panel border: `BotglueActiveBorder` highlight (yellow/gold, linked to `DiagnosticWarn`)
- Inactive panel borders: `FloatBorder` (default gray)
- Panel 3 footer: `[model_name]`, updated on Shift+Tab cycle
- Panel 2 entries: `[model_short]` right-aligned per entry
- Panel 3 in preview mode: text displayed with `Comment` highlight (dimmed)

### Focus Model

Tab cycles forward between List and Prompt: `List -> Prompt -> List` (Filter is accessed by typing from List — Telescope's natural behavior).

| From | Action | To | Effect |
|------|--------|----|--------|
| List | `Tab` | Prompt | Save preview, enter normal mode |
| List | `Enter` | Prompt | Populate prompt with selected item, enter normal mode |
| List | `Shift+Enter` | -- | Quick submit: send highlighted prompt immediately |
| List | start typing | Filter | Telescope's default behavior |
| Filter | `Ctrl+j`/`Ctrl+k` | (stay) | Navigate list without leaving filter |
| Filter | `Enter` | Prompt | Select highlighted item, populate prompt |
| Filter | `Tab` | Prompt | Move to prompt without selecting |
| Filter | `Esc` | List | Return to list, clear filter |
| Prompt | `Tab` | List | Save draft, show previews in Panel 3 |
| Prompt | `Shift+Tab` | (stay) | Cycle model |
| Prompt | `Shift+Enter` | -- | Submit prompt |
| Prompt (insert) | `Esc` | Prompt (normal) | Standard vim behavior |
| Prompt (normal) | `Esc` or `q` | -- | Close everything |
| List (normal) | `Esc` or `q` | -- | Close everything |

### Draft/Preview Model

Panel 3 has two internal modes: **preview** and **draft**.

- **Preview mode:** When user navigates the history list (j/k), Panel 3 shows the highlighted prompt. Text is dimmed (`Comment` highlight group).
- **Draft mode:** When focus moves to Panel 3 (via Enter or Tab), the current content becomes an editable draft.
- **Returning to list:** Panel 3 content is saved as draft, previews resume.
- **Returning to prompt without selecting:** Draft is restored.
- **Selecting a new item (Enter on list):** Draft is replaced with selected prompt.

### User Scenarios

**A: Quick reuse (no edits)**
1. `<leader>pp` in visual mode
2. UI opens, focus on List
3. `Shift+Enter` on highlighted prompt — sent immediately
4. UI closes, spinner appears at selection

**B: Reuse with edits**
1. `<leader>pp`, focus on List
2. `j`/`k` to browse — Panel 3 previews each item
3. `Enter` — prompt populates Panel 3, focus moves there (normal mode)
4. `i` — insert mode, edit prompt
5. `Shift+Tab` — cycle model
6. `Shift+Enter` — submit

**C: Search history, then edit**
1. `<leader>pp`, focus on List
2. Type `com` — focus moves to Filter, list filters
3. `Enter` — populates Panel 3, focus moves there
4. Edit, `Shift+Enter` — submit

**D: New prompt from scratch**
1. `<leader>pp`, focus on List
2. `Tab` — focus moves to Panel 3 (empty, normal mode)
3. `i` — insert mode, write prompt
4. `Shift+Enter` — submit

**E: Browse, edit, change mind, browse again**
1. `<leader>pp`, focus on List
2. `Enter` on "fix errors" — populates Panel 3
3. Edit to "fix errors and add types"
4. `Tab` — back to List. Draft saved. Panel 3 shows previews again
5. Browse more items
6. `Tab` — back to Prompt. Draft "fix errors and add types" restored
7. `Shift+Enter` — submit

**F: No history (first use)**
1. `<leader>pp` in visual mode
2. Only Panel 3 opens (no Telescope)
3. `i`, write prompt, `Shift+Enter` — submit

## Implementation Approach

**Keep Telescope** for Panels 1+2 (filter + results). Custom float window for Panel 3 (prompt editor). Coordinate lifecycle.

### Module Changes

| Module | Change |
|--------|--------|
| `picker.lua` | Rewrite: custom Telescope layout, create Panel 3 alongside, manage focus/draft/preview, lifecycle |
| `ui.lua` | Simplify: becomes Panel 3 factory only (create float, keymaps, model cycling). Remove `capture_input` orchestration |
| `init.lua` | Simplify: `M.run()` calls single `picker.open(on_submit)` instead of picker -> ui chain |
| `plugin/botglue.lua` | Remove `BotglueCancel` command (cancel was removed in v0.2.0) |
| `config.lua` | No change |
| `history.lua` | No change |
| `display.lua` | No change |
| `operations.lua` | No change |
| `claude.lua` | No change |

### New Public API

```lua
-- picker.lua (new signature)
M.open(on_submit)
-- on_submit(prompt, model) called when user submits from Panel 3 or quick-submits from List
-- replaces the current picker.open(on_select) -> ui.capture_input() chain

-- ui.lua (new role: Panel 3 factory)
M.create_prompt_window(opts) -> { buf, win, set_text, get_text, set_model, close }
-- opts: { width, row, col, model }
-- Returns handle for picker.lua to control

M._next_model(current, models) -- unchanged, still pure
M._resolve_input(text, on_submit, on_cancel, model) -- unchanged, still pure
```

### init.lua Simplifies To

```lua
function M.run()
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)

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
```

### Key Implementation Details

1. **Telescope stays open after selection** — `select_default` override populates Panel 3 instead of closing
2. **Panel 3 positioned below Telescope** — calculate position using Telescope's window position + height
3. **Border highlight switching** — `nvim_win_set_config` to update border highlight on focus change
4. **Draft storage** — local variable in picker's closure: `local draft = { text = "", model = default_model }`
5. **Preview rendering** — on `cursor_moved` autocmd in list buffer, populate Panel 3 with highlighted entry text + `Comment` highlight
6. **Lifecycle** — single `close_all()` that closes Telescope + Panel 3
7. **Empty history** — if `history.get_sorted()` returns empty table, skip Telescope entirely, open only Panel 3

## Implementation Status

**Completed:** 2026-02-07

**Implementation plan:** `docs/plans/2026-02-07-ui-refactor-implementation.md`

**Key decisions made during implementation:**
- Telescope `layout_strategy = "vertical"` with `prompt_position = "top"` for filter-on-top layout
- Panel 3 positioned using `nvim_win_get_config` on Telescope's results window
- `CursorMoved` autocmd on results buffer for live preview updates
- `modifiable = false` in preview mode prevents accidental edits to preview text
- `botglue_preview` namespace for highlight management — separate from main `botglue` namespace
- `winhl` option used for border highlight switching (cleaner than individual border chars)
- `actions.close` saved and restored before use to prevent infinite recursion
