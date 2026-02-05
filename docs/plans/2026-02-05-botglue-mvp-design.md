# botglue.nvim MVP Design

## Overview

Neovim plugin for text processing via Claude Code CLI. One-shot operations: select text → input window for instructions → Claude processes → result displayed.

## Core Flow

1. User selects text in visual mode
2. Presses shortcut (e.g., `<leader>pr`)
3. Input window appears with operation title
4. User types additional instructions (optional, can leave empty)
5. Press Enter to submit (Shift+Enter for newline)
6. Spinner shows progress
7. Result: replaces selection OR shows in floating window (for Explain)

## Operations

| Shortcut | Operation | Result Mode | Description |
|----------|-----------|-------------|-------------|
| `<leader>po` | Optimize | Replace | Improve prompt text |
| `<leader>pe` | Explain | Window | Explain code in Russian |
| `<leader>pr` | Refactor | Replace | Rewrite code cleaner |
| `<leader>pt` | Translate | Replace | Auto-detect language, translate to other |

## Architecture

Single file `prompt-optimizer.lua` (~350 lines):

```
prompt-optimizer.lua
├── Constants & State
│   ├── spinner_frames, spinner_timer
│   ├── ResultMode enum (REPLACE, WINDOW)
│   └── PROMPTS table (4 templates)
│
├── Utilities
│   ├── start_spinner(message)
│   ├── stop_spinner(message, level)
│   ├── get_visual_selection() -> {text, bufnr, start_line, start_col, end_line, end_col}
│   └── call_claude(prompt, callback)
│
├── Windows
│   ├── capture_input(title, on_submit, on_cancel)
│   │   - Enter = submit
│   │   - Shift+Enter = newline
│   │   - q / Esc = cancel
│   │
│   └── show_result_window(text, title)
│       - q / Esc = close
│       - Read-only, word wrap
│
├── Core Logic
│   ├── build_prompt(template, selected_text, user_input)
│   ├── replace_selection(sel, new_text)
│   └── run_operation(opts)
│       - opts: prompt_template, result_mode, input_title, spinner_msg, success_msg, window_title
│
├── Operations (wrappers)
│   ├── optimize_prompt()
│   ├── explain_code()
│   ├── refactor_code()
│   └── translate_text()
│
└── Setup
    └── config() -> registers keymaps, exposes global functions
```

## System Prompts

### Optimize
```
Оптимизируй промт ниже для получения лучшего результата.
Исправь ошибки. Добавь контекста к задаче.
Верни ТОЛЬКО улучшенный текст промта, без пояснений.

Контекст: Проект: {project} | Файл: {file} | Тип: {filetype}

<prompt>
{selected_text}
</prompt>

[Дополнительные указания: {user_input}]
```

### Explain
```
Объясни этот код на русском языке.
Опиши что он делает, зачем нужен, какие есть нюансы.
Будь кратким но информативным.

Контекст: Проект: {project} | Файл: {file} | Тип: {filetype}

<code>
{selected_text}
</code>

[Дополнительные указания: {user_input}]
```

### Refactor
```
Перепиши этот код чище и читаемее.
Сохрани функциональность. Улучши именование, структуру, убери дублирование.
Верни ТОЛЬКО код, без пояснений и markdown-блоков.

Контекст: Проект: {project} | Файл: {file} | Тип: {filetype}

<code>
{selected_text}
</code>

[Дополнительные указания: {user_input}]
```

### Translate
```
Определи язык текста и переведи на другой язык:
- Если текст на русском → переведи на английский
- Если текст на английском → переведи на русский
- Для других языков → переведи на русский

Верни ТОЛЬКО перевод, без пояснений.

<text>
{selected_text}
</text>

[Дополнительные указания: {user_input}]
```

## Window Specifications

### Input Window (capture_input)
- Size: 2/3 width, 1/4 height, centered
- Border: rounded
- Title: operation name (e.g., " Refactor ")
- Start in insert mode
- Keymaps:
  - `<CR>` (insert/normal): submit and close
  - `<S-CR>` (insert): insert newline
  - `q` (normal): cancel and close
  - `<Esc>` (normal): cancel and close

### Result Window (show_result_window)
- Size: 2/3 width, 1/3 height, centered
- Border: rounded
- Title: " Объяснение " (for Explain)
- Read-only buffer
- Word wrap enabled
- Keymaps:
  - `q` (normal): close
  - `<Esc>` (normal): close

## Claude CLI Integration

Command:
```bash
claude -p - --output-format text --model opus
```

- `-p -`: read prompt from stdin
- `--output-format text`: plain text output
- `--model opus`: use Opus model (configurable later)

Prompt sent via stdin, result from stdout.

## What Stays from Current Code

- Spinner implementation (start_spinner, stop_spinner)
- get_visual_selection() logic
- call_claude() async job handling
- replace_selection() buffer manipulation

## What Changes

- build_prompt() now accepts user_input parameter
- New capture_input() window
- New show_result_window() window
- run_operation() unifies all operations
- 3 new operations added (explain, refactor, translate)

## Implementation Order

1. Add PROMPTS table
2. Add ResultMode enum
3. Implement capture_input()
4. Implement show_result_window()
5. Modify build_prompt() to accept user_input
6. Implement run_operation()
7. Create 4 operation wrappers
8. Update keymaps registration

## Future Considerations (out of scope for MVP)

- User-configurable prompts via setup()
- User-configurable keymaps
- MCP server integration
- AGENT.md rules support
- Model selection
- History of operations
