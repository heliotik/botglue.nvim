# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

botglue.nvim is a Neovim plugin for AI-assisted text processing via Claude Code CLI. Users select text in visual mode, invoke a command, optionally provide instructions in a floating input window, and receive processed results.

## Development Commands

```bash
make fmt        # Format code with stylua
make lint       # Run luacheck
make test       # Run tests with plenary
make pr-ready   # Run all checks (lint + test + format check)
```

## Architecture

Modular structure in `lua/botglue/`:

- `init.lua` — Entry point, `setup()`, public API
- `config.lua` — Configuration defaults and merge logic
- `operations.lua` — Visual selection handling, `run()` orchestration
- `ui.lua` — Floating windows (input, result), spinner
- `claude.lua` — CLI invocation, prompt templates

### Data Flow

```
Visual selection → operations.run() → ui.capture_input()
    → claude.build_prompt() → claude.call() async
    → Result: operations.replace_selection() OR ui.show_result_window()
```

## Testing

Tests use plenary.nvim and are located in `test/botglue/`:

```bash
# Run all tests
make test

# Run specific test file
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/botglue/config_spec.lua"
```

## Code Style

- Formatter: stylua (see `.stylua.toml`)
- Linter: luacheck (see `.luacheckrc`)
- 2-space indentation, 100 char line width
