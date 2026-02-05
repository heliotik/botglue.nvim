# botglue.nvim Plugin Restructure Design

## Overview

Transform the prototype `prompt-optimizer.lua` (~425 lines) into a proper Neovim plugin with modular structure, quality infrastructure, and tests.

## Decisions

- **Structure**: 6 modules (init, config, operations, ui, claude, plugin/autoload)
- **Prompts**: Keep hardcoded inside plugin for now
- **Keymaps**: Register by default, disable via `setup({ default_keymaps = false })`
- **Tests**: Basic unit tests for config and build_prompt (~3-5 tests)
- **Documentation**: README.md in English only, vimdoc later
- **Model**: Configurable via `setup({ model = "sonnet" })`
- **MCP**: Remove prompt-optimizer-mcp.json entirely

## File Structure

```
botglue.nvim/
├── lua/
│   └── botglue/
│       ├── init.lua        # setup(), public API export
│       ├── config.lua      # defaults, merge with user options
│       ├── operations.lua  # optimize, explain, refactor, translate
│       ├── ui.lua          # capture_input, show_result_window, spinner
│       └── claude.lua      # call_claude, build_prompt, PROMPTS table
├── plugin/
│   └── botglue.lua         # vim commands :Botglue*
├── test/
│   ├── minimal_init.lua    # minimal config for tests
│   └── botglue/
│       ├── config_spec.lua
│       └── claude_spec.lua
├── docs/                   # keep existing
│   ├── plans/
│   └── promt/
├── .github/
│   └── workflows/
│       └── ci.yml
├── Makefile
├── .stylua.toml
├── .luacheckrc
├── README.md
├── LICENSE
└── CLAUDE.md
```

Files to delete:
- `prompt-optimizer.lua`
- `prompt-optimizer-mcp.json`

## Module Responsibilities

### lua/botglue/init.lua
Entry point and public API.

```lua
local M = {}

M.setup = function(opts)
  -- merge opts with defaults
  -- register keymaps if not disabled
end

M.optimize = function() ... end
M.explain = function() ... end
M.refactor = function() ... end
M.translate = function() ... end

return M
```

### lua/botglue/config.lua
Configuration management.

```lua
local M = {}

M.defaults = {
  model = "opus",
  default_keymaps = true,
}

M.options = {}

M.setup = function(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
```

### lua/botglue/operations.lua
Business logic: `run_operation`, `get_visual_selection`, `replace_selection`

### lua/botglue/ui.lua
UI components: `capture_input`, `show_result_window`, `start_spinner`, `stop_spinner`

### lua/botglue/claude.lua
CLI integration: `call_claude`, `build_prompt`, `PROMPTS` table

### plugin/botglue.lua
Vim commands registration.

```lua
vim.api.nvim_create_user_command("BotglueOptimize", ...)
vim.api.nvim_create_user_command("BotglueExplain", ...)
vim.api.nvim_create_user_command("BotglueRefactor", ...)
vim.api.nvim_create_user_command("BotglueTranslate", ...)
```

## Quality Infrastructure

### Makefile

```makefile
fmt:
	stylua lua/ --config-path=.stylua.toml

fmt-check:
	stylua lua/ --config-path=.stylua.toml --check

lint:
	luacheck lua/ --globals vim

test:
	nvim --headless --noplugin -u test/minimal_init.lua \
		-c "PlenaryBustedDirectory test/botglue {minimal_init = 'test/minimal_init.lua'}"

pr-ready: lint test fmt-check
```

### .stylua.toml

```toml
column_width = 100
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
```

### .luacheckrc

```lua
std = luajit
cache = true
codes = true
ignore = { "211" }
read_globals = { "vim", "describe", "it", "assert", "before_each", "after_each" }
```

### CI (.github/workflows/ci.yml)

- Trigger: push/PR to main
- Steps: install nvim + luacheck + stylua + plenary → `make pr-ready`

## Tests

### test/minimal_init.lua

```lua
vim.opt.rtp:append(".")
vim.opt.rtp:append("../plenary.nvim")
vim.cmd("runtime plugin/plenary.vim")
```

### test/botglue/config_spec.lua

- Test default model is "opus"
- Test user options merge
- Test default_keymaps is true by default

### test/botglue/claude_spec.lua

- Test build_prompt includes context
- Test translate prompt has no context

## Implementation Order

1. Create directory structure
2. Split prompt-optimizer.lua into modules
3. Add plugin/botglue.lua with vim commands
4. Set up quality infrastructure (.stylua.toml, .luacheckrc, Makefile)
5. Add tests
6. Set up CI
7. Update documentation (README.md, CLAUDE.md)
8. Delete old files (prompt-optimizer.lua, prompt-optimizer-mcp.json)
9. Commit and tag v0.1.0
