# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

botglue.nvim is a Neovim plugin for AI-assisted inline code editing via Claude Code CLI. Users select text in visual mode, pick or type a prompt via Telescope, and the AI replaces the selection with the result. Progress is shown inline via extmarks.

## Development Commands

```bash
make fmt        # Format code with stylua
make lint       # Run luacheck
make test       # Run tests with plenary
make pr-ready   # Run all checks (lint + test + format check)
```

## Architecture

Modular structure in `lua/botglue/`:

- `init.lua` — Entry point, `setup()`, `M.run()`, `M.cancel()`, keymap registration
- `config.lua` — Configuration defaults (models, timeout, max_turns, ai_stdout_rows)
- `operations.lua` — Visual selection handling, `run(prompt, model)` orchestration
- `claude.lua` — CLI command builder, process management, stream-json parser, cancel, timeout
- `ui.lua` — Input window with model badge and `<C-s>` cycling
- `display.lua` — Mark and RequestStatus classes for extmark-based inline progress
- `history.lua` — JSON persistence for prompt history with frequency sorting
- `picker.lua` — Telescope integration for prompt selection

### Dependencies

- **Required:** `telescope.nvim`
- **Required:** Claude Code CLI (`claude`) in PATH

### Data Flow

```
<leader>pp (visual mode)
  → picker.open() — Telescope with history sorted by frequency
  → ui.capture_input() — input window, model badge, <C-s> cycling
  → history.add(prompt, model)
  → operations.run(prompt, model)
    → get_visual_selection()
    → display: place top_mark + bottom_mark extmarks
    → claude.start() — spawn process, stream-json parsing
      → tool-use events → display: push to top_mark lines
      → text_delta events → collect into result
    → on complete: display.clear(), replace_selection(result)
```

### Commands

- `:Botglue` — Main flow: picker → input → execute (visual mode)
- `:BotglueCancel` — Cancel running request

## Testing

60 tests using plenary.nvim, located in `test/botglue/`:

| File | Tests | Covers |
|------|-------|--------|
| `config_spec.lua` | 9 | Defaults, setup merging, v0.2.0 fields |
| `claude_spec.lua` | 11 | Command builder, system prompt, `_extract_result`, cancel |
| `display_spec.lua` | 8 | Mark lifecycle, RequestStatus spinner/push/eviction |
| `history_spec.lua` | 6 | Add, dedup, sort, disk persistence |
| `operations_spec.lua` | 18 | `replace_selection`, `get_visual_selection`, `run()` with mocked claude, `cancel()` |
| `ui_spec.lua` | 8 | `_next_model` cycling, `_resolve_input` submit/cancel logic |

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

## Code Style

- Formatter: stylua (see `.stylua.toml`)
- Linter: luacheck (see `.luacheckrc`)
- 2-space indentation, 100 char line width
