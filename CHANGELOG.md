# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-02-07

Major rewrite: unified inline editing assistant with extmark feedback, Telescope prompt history, and Claude Code project-level context.

### Added

- Unified `:Botglue` command replacing 4 separate operations
- `:BotglueCancel` command for request cancellation
- Inline progress display via extmarks (spinner + Claude activity above/below selection)
- Telescope picker for prompt history with frequency sorting and model badges
- Model cycling in input window (`<C-s>`) with visual badge
- Prompt history with JSON persistence (`~/.local/share/nvim/botglue/history.json`)
- Claude Code stream-json parsing for real-time activity display
- Read-only tool access (`Read,Grep,Glob`) for project-level context
- Configurable timeout (default 5 min), max_turns, ai_stdout_rows
- Dynamic system prompt with file path, line range, filetype, project name

### Changed

- Single entry point `M.run()` replaces `M.optimize/explain/refactor/translate()`
- Keymaps changed: `<leader>pp` (run), `<leader>ps` (cancel)
- Input window now shows model badge in footer, supports pre-fill from history
- Claude invocation uses `-p` with `--output-format stream-json --verbose`
- Result mode is always replace (no explain/window mode in this version)

### Removed

- 4 hardcoded operations and their Russian prompt templates
- `ResultMode` enum (REPLACE/WINDOW)
- Result display window (`show_result_window`)
- Spinner via `nvim_echo` (replaced by extmark-based display)
- Old keymaps: `<leader>po`, `<leader>pe`, `<leader>pr`, `<leader>pt`
- Old commands: `BotglueOptimize`, `BotglueExplain`, `BotglueRefactor`, `BotglueTranslate`

### Dependencies

- **Added:** `telescope.nvim` (required)

---

## [0.1.0] - 2026-02-06

Initial release.

### Added

- 4 operations for visual mode: **optimize**, **explain**, **refactor**, **translate**
- Integration with Claude Code CLI (`claude -p`) via async `jobstart`
- Floating input window for additional instructions (Enter — submit, Shift+Enter — new line, q/Esc — cancel)
- Result window for the explain operation (read-only, close with q/Esc)
- Two result modes: selection replacement (`REPLACE`) and display in window (`WINDOW`)
- Animated spinner while waiting for response
- Project context (project name, file, filetype) passed to the prompt
- Model configuration via `setup({ model = "opus" })`
- Default keymaps (`<leader>po/pe/pr/pt`) with option to disable
- Vim commands: `:BotglueOptimize`, `:BotglueExplain`, `:BotglueRefactor`, `:BotglueTranslate`
- Modular architecture: `config`, `operations`, `ui`, `claude`
- CI via GitHub Actions (luacheck, stylua)
- Code quality: stylua for formatting, luacheck for linting
