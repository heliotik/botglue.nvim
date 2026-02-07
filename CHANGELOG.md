# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.1] - 2026-02-07

Custom three-panel float UI replacing Telescope, 5 UI bugfixes, improved Claude interaction.

### Added

- Custom three-panel float UI: container frame ("BotGlue" title), filter, history list, prompt editor
- Labeled horizontal dividers ("Recent prompts", "Prompt") between panels
- Active panel indication via yellow divider highlight (`BotglueActiveBorder`)
- Fuzzy filter with `matchfuzzypos` match highlighting (correct UTF-8/CJK support)
- Filter placeholder: "Filter recent prompts - press / to focus"
- Prompt placeholder: "Type your prompt here..."
- Auto-close UI on focus loss (`WinLeave` + `vim.schedule`)
- Testable helpers: `_format_list_line`, `_char_to_byte_positions`, `_make_divider`, `_truncate_prompt`
- 9 new tests (80 total): line formatting, UTF-8 byte position conversion

### Changed

- Model tags rendered inline with space-padding (was: right-aligned extmarks)
- `apply_filter()` matches against display-ready strings (newlines replaced)
- `_char_to_byte_positions` uses `vim.fn.byteidx()` for correct multi-byte highlights
- Autocomplete suppression: `cmp_enabled`/`completion` buffer vars (was: `cmp` only)
- System prompt now includes selected text in context
- `_extract_result` returns `(result, error)` tuple with better error reporting
- `create_prompt_window` accepts `no_border`, `no_footer`, `zindex` options

### Removed

- `telescope.nvim` dependency (replaced with custom float windows)
- `handle.set_border_hl()` from ui.lua (dead code after container refactor)
- Yellow container border highlight (replaced by per-panel divider highlights)

### Fixed

- Fuzzy match highlighting incorrect for multi-byte UTF-8 characters
- `cursorline` not covering right-aligned model tag extmarks
- Asymmetric padding in history list (2-space left, 0 right)
- Autocomplete triggering in filter and prompt panels despite suppression flags
- Multi-line prompts causing `nvim_buf_set_lines` error in history list

---

## [0.2.0] - 2026-02-07

Major rewrite: unified inline editing assistant with extmark feedback, prompt history, and Claude Code project-level context.

### Added

- Unified `:Botglue` command replacing 4 separate operations
- `:BotglueCancel` command for request cancellation
- Inline progress display via extmarks (spinner + Claude activity above/below selection)
- Prompt history picker with frequency sorting and model badges
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
