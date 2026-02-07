# Picker Rewrite: Drop Telescope, Custom Float Windows

**Goal:** Replace Telescope-based picker with three custom float windows to get full control over focus, keymaps, and borders.

**Why:** Telescope's results window has `focusable=false`, which breaks: focus on list, j/k navigation, CursorMoved preview updates, border highlights, keymaps on results buffer. Every bug in the current implementation stems from this constraint.

## Layout

```
+── Botglue ──────────────────────────+
| > _                                 |  Panel 1: Filter (1-line input)
+─────────────────────────────────────+
| ▸ переведи на английский     [opus] |  Panel 2: List (focusable)
|   поправь ошибки в тексте    [opus] |  Height: min(#items, 10)
|   переделай в булет лист     [opus] |  cursorline = true
+─────────────────────────────────────+
| 1   _                               |  Panel 3: Prompt editor
| ~                                    |  Height: 5, number+relativenumber
| ~                                    |  Footer: [opus]
+─────────────────────────────────────+
```

- Width: 60% of editor, capped at 80
- Centered horizontally, ~30% from top
- Empty history: only Panel 3 opens

## Focus Model

Focus starts on **Panel 2 (List)**. Tab cycles `List ↔ Prompt`. Filter accessed via `/` from List.

Active panel: `BotglueActiveBorder` (yellow). Inactive: `FloatBorder` (gray).

## Keymaps

| From | Key | Effect |
|------|-----|--------|
| **List** | `j`/`k` | Navigate, preview updates in Panel 3 |
| **List** | `/` | Focus Filter |
| **List** | `Enter` | Select → Panel 3 (draft mode) |
| **List** | `Ctrl+S` | Quick submit selected item |
| **List** | `Tab` | Focus Prompt (with current draft) |
| **List** | `Esc`/`q` | Close all |
| **Filter** | type | Fuzzy filter list (`matchfuzzy`) |
| **Filter** | `Ctrl+J`/`Ctrl+K` | Navigate list without leaving |
| **Filter** | `Enter` | Select top match → Panel 3 |
| **Filter** | `Esc` | Clear filter, back to List |
| **Filter** | `Tab` | Focus Prompt |
| **Prompt** | `Enter` (insert) | Newline |
| **Prompt** | `Enter` (normal) | Submit |
| **Prompt** | `Ctrl+S` | Submit (any mode) |
| **Prompt** | `Shift+Tab` | Cycle model |
| **Prompt** | `Tab` | Focus List (save draft) |
| **Prompt** | `Esc`/`q` (normal) | Close all |

## Draft/Preview

- Navigating List → Panel 3 shows dimmed preview (Comment highlight, non-modifiable)
- Entering Panel 3 (Enter/Tab) → restores editable draft
- Leaving Panel 3 (Tab) → saves draft, resumes preview
- Selecting item (Enter on List) → replaces draft with selected prompt

## Filter Mechanism

- `vim.fn.matchfuzzy()` for fuzzy matching
- `TextChangedI` autocmd on filter buffer triggers re-filter
- Filtered results update Panel 2 buffer in real-time
- `Ctrl+J`/`Ctrl+K` from filter navigate selection in Panel 2

## Module Changes

| Module | Change |
|--------|--------|
| `picker.lua` | Full rewrite: three custom floats, no Telescope |
| `ui.lua` | No change (Panel 3 factory) |
| `init.lua` | No change |
| `config.lua` | No change |
| `history.lua` | No change |
| Dependencies | Remove `telescope.nvim` requirement |

## User Scenarios

**A: Quick reuse** — open → j/k to find → Ctrl+S → submitted
**B: Reuse with edits** — open → j/k → Enter → edit in Panel 3 → Enter (normal) → submitted
**C: Search history** — open → / → type filter → Enter → edit → submit
**D: New prompt** — open → Tab → type prompt → Enter (normal) → submitted
**E: Browse/edit/change mind** — Enter on item → edit → Tab back to list → browse → Tab to prompt → draft restored → submit
**F: No history** — open → only Panel 3 → type → submit
