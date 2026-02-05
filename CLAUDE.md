# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

botglue.nvim is a Neovim plugin for AI-assisted text processing via Claude Code CLI. Users select text in visual mode, invoke a command, optionally provide instructions in a floating input window, and receive processed results that either replace the selection or display in a read-only window.

**Philosophy:** AI as a precise tool for specific operations, not an autonomous agent. Inspired by ThePrimeagen/99.

## Development Commands

```bash
# No build process - Lua is interpreted
# Reload plugin in Neovim:
:source prompt-optimizer.lua

# Test manually by selecting text and using keymaps:
# <leader>po - Optimize prompt (replace)
# <leader>pe - Explain code (window)
# <leader>pr - Refactor code (replace)
# <leader>pt - Translate text (replace)
```

## Architecture

**Single-file monolithic design:** All logic in `prompt-optimizer.lua` (~425 lines), wrapped in lazy.nvim compatible module format.

### Core Flow

```
Visual selection → run_operation() → capture_input() floating window
    → build_prompt() with context injection → call_claude() async via jobstart
    → Result: replace_selection() OR show_result_window()
```

### Key Abstractions

- **ResultMode**: `REPLACE` (modify buffer) or `WINDOW` (read-only display)
- **PROMPTS table**: Russian-language system prompts with placeholders `{project_name}`, `{file_path}`, `{filetype}`, `{selected_text}`
- **Global exports**: `_G.botglue_po`, `_G.botglue_pe`, `_G.botglue_pr`, `_G.botglue_pt` for keymap invocation

### Claude CLI Invocation

```bash
claude -p - --output-format text --model opus
```
Prompt sent via stdin using `vim.fn.jobstart()` + `vim.fn.chansend()`.

## Code Patterns

- **Async-first**: Uses `vim.fn.jobstart()` for non-blocking CLI calls, `vim.uv.new_timer()` for spinners
- **Result callbacks**: All operations use `vim.schedule()` for safe UI updates
- **Context injection**: Every prompt includes project name, file path, and filetype (except translate which only uses text)

## Language

All system prompts and UI text are in Russian. This is intentional for the target user base.
