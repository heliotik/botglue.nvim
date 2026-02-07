# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

botglue.nvim is a Neovim plugin for AI-assisted inline code editing via Claude Code CLI. Users select text in visual mode, pick or type a prompt via a custom three-panel float UI, and the AI replaces the selection with the result. Progress is shown inline via extmarks.

## Development Commands

```bash
make fmt        # Format code with stylua
make lint       # Run luacheck
make test       # Run tests with plenary
make pr-ready   # Run all checks (lint + test + format check)
```

## Architecture

Modular structure in `lua/botglue/`:

- `init.lua` — Entry point, `setup()`, `M.run()`, keymap registration
- `config.lua` — Configuration defaults (models, timeout, max_turns, ai_stdout_rows)
- `operations.lua` — Visual selection handling, `run(prompt, model)` orchestration
- `claude.lua` — CLI command builder, process management, stream-json parser, timeout
- `ui.lua` — Prompt editor window factory (`create_prompt_window`), model cycling, input resolution
- `display.lua` — Mark and RequestStatus classes for extmark-based inline progress
- `history.lua` — JSON persistence for prompt history with frequency sorting
- `picker.lua` — Three-panel UI orchestrator: container frame with filter, history list, prompt editor

### Dependencies

- **Required:** Claude Code CLI (`claude`) in PATH

### UI Architecture

Unified container frame ("BotGlue" title, model badge footer) with three borderless inner panels:
- **Panel 1:** Filter — single-line fuzzy filter with placeholder hint, `matchfuzzypos` for match highlighting
- **Panel 2:** History list — sorted by frequency, model tags inline with space-padding to full width
- **Panel 3:** Prompt editor — with relativenumber, wrap, placeholder text

Panels separated by labeled horizontal dividers ("Recent prompts", "Prompt") in the container buffer, highlighted with `FloatBorder`. Container uses `zindex = 40`, inner panels `zindex = 50`.
Active panel indicated by yellow (`BotglueActiveBorder`) highlight on its divider label; container border uses default `FloatBorder`.

Key behaviors:
- Tab cycles focus between List and Prompt panels
- `/` focuses filter from list
- Enter on list item populates Prompt and moves focus there
- Ctrl+S submits (from list: quick submit; from prompt: submit edited)
- Shift+Tab in prompt cycles model (updates container footer)
- Draft/preview model: browsing shows preview; editing saves draft; draft persists across focus switches
- Empty history: only Prompt panel opens (container + prompt, with placeholder)
- UI auto-closes on focus loss (WinLeave + vim.schedule)

### Data Flow

```
<leader>pp (visual mode)
  → picker.open(on_submit) — container frame + three inner panels
    → Container: "BotGlue" title, model footer, divider lines
    → Panel 1: filter (matchfuzzypos), Panel 2: history list, Panel 3: prompt editor
    → on_submit(prompt, model)
  → history.add(prompt, model)
  → operations.run(prompt, model, sel)
    → display: place top_mark + bottom_mark extmarks
    → claude.start() — spawn process, stream-json parsing
      → tool-use events → display: push to top_mark lines
    → on complete: cleanup marks, replace_selection(result)
```

### Commands

- `:Botglue` — Main flow: picker → input → execute (visual mode)

## Testing

80 tests using plenary.nvim, located in `test/botglue/`:

| File | Tests | Covers |
|------|-------|--------|
| `config_spec.lua` | 9 | Defaults, setup merging, v0.2.0 fields |
| `claude_spec.lua` | 11 | Command builder, system prompt, `_extract_result` |
| `display_spec.lua` | 8 | Mark lifecycle, RequestStatus spinner/push/eviction |
| `history_spec.lua` | 6 | Add, dedup, sort, disk persistence |
| `operations_spec.lua` | 16 | `replace_selection`, `get_visual_selection`, `run()` with mocked claude |
| `ui_spec.lua` | 9 | `_next_model` cycling, `_resolve_input` submit/cancel, `create_prompt_window` |
| `picker_spec.lua` | 19 | Module exports, `_make_divider`, `_truncate_prompt`, `_format_list_line`, `_char_to_byte_positions` |

```bash
# Run all tests
make test

# Run specific test file
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/botglue/config_spec.lua"
```

### Test Patterns

- Module reload in `before_each`: clear `package.loaded["botglue.X"]`, re-require
- Buffer setup: `nvim_create_buf` + `nvim_buf_set_lines`, cleanup in `after_each`
- Mocking: inject stubs into `package.loaded` before requiring the module under test
- `vim.notify` stubbing: replace with capture table in `before_each`, restore in `after_each`

### Gotchas

- `vim.fn.getpos("'<")` reads marks from **current buffer only** — `get_visual_selection(bufnr)` requires bufnr to be current
- Mocking: must clear ALL modules in the dependency chain from `package.loaded`, not just the target
- `nvim_list_uis()` returns empty in headless tests — UI code (floating windows) cannot be tested directly
- `nvim_buf_set_mark` col is 0-indexed, `getpos` returns 1-indexed columns — off-by-one source
- Container float uses `zindex = 40`, inner panels `zindex = 50` — incorrect zindex causes panels to render behind the container
- `WinLeave` autocmd must use `vim.schedule` before checking `nvim_get_current_win` — at `WinLeave` time the current window hasn't updated yet
- `matchfuzzypos` returns 0-indexed **character** positions — use `vim.fn.byteidx()` to convert to byte offsets for `nvim_buf_add_highlight`; see `_char_to_byte_positions` helper
- Autocomplete suppression: set `vim.b[buf].cmp_enabled = false` (nvim-cmp) and `vim.b[buf].completion = false` (blink.cmp) — `vim.b[buf].cmp = false` alone is insufficient

## Code Style

- Formatter: stylua (see `.stylua.toml`)
- Linter: luacheck (see `.luacheckrc`)
- 2-space indentation, 100 char line width
