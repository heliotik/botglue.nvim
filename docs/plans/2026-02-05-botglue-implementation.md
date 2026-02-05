# botglue.nvim MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform single-operation prompt-optimizer into 4-operation plugin with input window for user instructions.

**Architecture:** Single file refactor. Add PROMPTS table, input/result windows, unified run_operation(), four operation wrappers. Keep existing utilities (spinner, selection, claude call, replace).

**Tech Stack:** Lua, Neovim API (vim.api, vim.fn, vim.keymap), vim.uv for async timers

---

## Task 1: Add PROMPTS Table and ResultMode

**Files:**
- Modify: `prompt-optimizer.lua:5-10` (add after config function start)

**Step 1: Add ResultMode enum and PROMPTS table**

Add this code right after `config = function()` line (after line 5):

```lua
    -- Result modes
    local ResultMode = {
      REPLACE = "replace",
      WINDOW = "window",
    }

    -- System prompts for each operation
    local PROMPTS = {
      optimize = [[
Оптимизируй промт ниже для получения лучшего результата.
Исправь ошибки. Добавь контекста к задаче.
Верни ТОЛЬКО улучшенный текст промта, без пояснений.

Контекст: Проект: %s | Файл: %s | Тип: %s

<prompt>
%s
</prompt>]],

      explain = [[
Объясни этот код на русском языке.
Опиши что он делает, зачем нужен, какие есть нюансы.
Будь кратким но информативным.

Контекст: Проект: %s | Файл: %s | Тип: %s

<code>
%s
</code>]],

      refactor = [[
Перепиши этот код чище и читаемее.
Сохрани функциональность. Улучши именование, структуру, убери дублирование.
Верни ТОЛЬКО код, без пояснений и markdown-блоков.

Контекст: Проект: %s | Файл: %s | Тип: %s

<code>
%s
</code>]],

      translate = [[
Определи язык текста и переведи на другой язык:
- Если текст на русском → переведи на английский
- Если текст на английском → переведи на русский
- Для других языков → переведи на русский

Верни ТОЛЬКО перевод, без пояснений.

<text>
%s
</text>]],
    }
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: add PROMPTS table and ResultMode enum"
```

---

## Task 2: Add capture_input Window

**Files:**
- Modify: `prompt-optimizer.lua` (add after stop_spinner function, around line 75)

**Step 1: Add capture_input function**

Add this code after the `stop_spinner` function:

```lua
    -- Floating window for user input
    local function capture_input(title, on_submit, on_cancel)
      local ui = vim.api.nvim_list_uis()[1]
      local width = math.floor(ui.width * 2 / 3)
      local height = math.floor(ui.height / 4)
      local row = math.floor((ui.height - height) / 2)
      local col = math.floor((ui.width - width) / 2)

      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = title,
        title_pos = "center",
      })

      vim.bo[buf].bufhidden = "wipe"
      vim.wo[win].wrap = true

      local function close_window()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end

      local function submit()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local input = vim.trim(table.concat(lines, "\n"))
        close_window()
        on_submit(input)
      end

      local function newline()
        local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
        local line = vim.api.nvim_buf_get_lines(buf, cursor_row - 1, cursor_row, false)[1]
        local before = line:sub(1, cursor_col)
        local after = line:sub(cursor_col + 1)
        vim.api.nvim_buf_set_lines(buf, cursor_row - 1, cursor_row, false, { before, after })
        vim.api.nvim_win_set_cursor(win, { cursor_row + 1, 0 })
      end

      local function cancel()
        close_window()
        if on_cancel then on_cancel() end
      end

      -- Enter = submit
      vim.keymap.set("i", "<CR>", submit, { buffer = buf, nowait = true })
      vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true })

      -- Shift+Enter = newline
      vim.keymap.set("i", "<S-CR>", newline, { buffer = buf, nowait = true })

      -- q / Esc = cancel
      vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true })
      vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })

      vim.cmd("startinsert")
    end
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: add capture_input floating window"
```

---

## Task 3: Add show_result_window

**Files:**
- Modify: `prompt-optimizer.lua` (add after capture_input function)

**Step 1: Add show_result_window function**

Add this code after `capture_input`:

```lua
    -- Floating window for displaying results (Explain operation)
    local function show_result_window(text, title)
      local ui = vim.api.nvim_list_uis()[1]
      local width = math.floor(ui.width * 2 / 3)
      local height = math.floor(ui.height / 3)
      local row = math.floor((ui.height - height) / 2)
      local col = math.floor((ui.width - width) / 2)

      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = title or " botglue ",
        title_pos = "center",
      })

      local lines = vim.split(text, "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      vim.wo[win].wrap = true
      vim.bo[buf].modifiable = false
      vim.bo[buf].bufhidden = "wipe"

      local function close_window()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end

      vim.keymap.set("n", "q", close_window, { buffer = buf, nowait = true })
      vim.keymap.set("n", "<Esc>", close_window, { buffer = buf, nowait = true })
    end
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: add show_result_window for Explain operation"
```

---

## Task 4: Update build_prompt to Accept user_input

**Files:**
- Modify: `prompt-optimizer.lua` (replace existing build_prompt function)

**Step 1: Replace build_prompt function**

Find the existing `build_prompt` function and replace it with:

```lua
    -- Build prompt with context and optional user input
    local function build_prompt(template, selected_text, user_input)
      local cwd = vim.fn.getcwd()
      local project_name = vim.fn.fnamemodify(cwd, ":t")
      local file_path = vim.fn.expand("%:.")
      local filetype = vim.bo.filetype

      -- Translate template doesn't use context (only 1 format placeholder)
      local prompt
      if template == PROMPTS.translate then
        prompt = string.format(template, selected_text)
      else
        prompt = string.format(template, project_name, file_path, filetype, selected_text)
      end

      if user_input and user_input ~= "" then
        prompt = prompt .. "\n\nДополнительные указания от пользователя:\n" .. user_input
      end

      return prompt
    end
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: update build_prompt to accept user_input"
```

---

## Task 5: Add run_operation Unified Function

**Files:**
- Modify: `prompt-optimizer.lua` (add after replace_selection function)

**Step 1: Add run_operation function**

Add this code after `replace_selection`:

```lua
    -- Unified operation runner
    local function run_operation(opts)
      local sel = get_visual_selection()
      if not sel or sel.text == "" then
        vim.notify("Нет выделенного текста", vim.log.levels.WARN)
        return
      end

      capture_input(opts.input_title, function(user_input)
        start_spinner(opts.spinner_msg)

        local prompt = build_prompt(opts.prompt_template, sel.text, user_input)

        call_claude(prompt, function(err, result)
          vim.schedule(function()
            if err then
              stop_spinner("✗ " .. err, vim.log.levels.ERROR)
              return
            end

            if not result or result == "" then
              stop_spinner("⚠ Пустой ответ от Claude", vim.log.levels.WARN)
              return
            end

            if opts.result_mode == ResultMode.REPLACE then
              replace_selection(sel, result)
              stop_spinner(opts.success_msg, vim.log.levels.INFO)
            else
              stop_spinner(nil)
              show_result_window(result, opts.window_title)
            end
          end)
        end)
      end)
    end
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: add run_operation unified function"
```

---

## Task 6: Create Four Operation Wrappers

**Files:**
- Modify: `prompt-optimizer.lua` (replace existing optimize_prompt, add 3 new functions)

**Step 1: Replace optimize_prompt and add other operations**

Find the existing `optimize_prompt` function and replace it with these four functions:

```lua
    -- Operation: Optimize prompt
    local function optimize_prompt()
      run_operation({
        prompt_template = PROMPTS.optimize,
        result_mode = ResultMode.REPLACE,
        input_title = " Оптимизация промта ",
        spinner_msg = "Оптимизирую промт...",
        success_msg = "✓ Промт оптимизирован!",
      })
    end

    -- Operation: Explain code
    local function explain_code()
      run_operation({
        prompt_template = PROMPTS.explain,
        result_mode = ResultMode.WINDOW,
        input_title = " Объяснение кода ",
        spinner_msg = "Анализирую код...",
        window_title = " Объяснение ",
      })
    end

    -- Operation: Refactor code
    local function refactor_code()
      run_operation({
        prompt_template = PROMPTS.refactor,
        result_mode = ResultMode.REPLACE,
        input_title = " Рефакторинг ",
        spinner_msg = "Рефакторю код...",
        success_msg = "✓ Код улучшен!",
      })
    end

    -- Operation: Translate text
    local function translate_text()
      run_operation({
        prompt_template = PROMPTS.translate,
        result_mode = ResultMode.REPLACE,
        input_title = " Перевод ",
        spinner_msg = "Перевожу...",
        success_msg = "✓ Переведено!",
      })
    end
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: add four operation wrappers"
```

---

## Task 7: Update Keymaps Registration

**Files:**
- Modify: `prompt-optimizer.lua` (replace existing keymap section at the end)

**Step 1: Replace keymap registration**

Find the existing keymap registration (lines 211-216) and replace with:

```lua
    -- Export functions globally for keymaps
    _G.botglue_po = optimize_prompt
    _G.botglue_pe = explain_code
    _G.botglue_pr = refactor_code
    _G.botglue_pt = translate_text

    -- Keymaps for visual mode
    vim.keymap.set("x", "<leader>po", ":<C-u>lua _G.botglue_po()<CR>", { desc = "Optimize prompt", silent = true })
    vim.keymap.set("x", "<leader>pe", ":<C-u>lua _G.botglue_pe()<CR>", { desc = "Explain code", silent = true })
    vim.keymap.set("x", "<leader>pr", ":<C-u>lua _G.botglue_pr()<CR>", { desc = "Refactor code", silent = true })
    vim.keymap.set("x", "<leader>pt", ":<C-u>lua _G.botglue_pt()<CR>", { desc = "Translate text", silent = true })
```

**Step 2: Verify syntax**

Run: `nvim --headless -c "luafile prompt-optimizer.lua" -c "q" 2>&1`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add prompt-optimizer.lua
git commit -m "feat: register keymaps for all four operations"
```

---

## Task 8: Manual Testing

**Files:**
- Test in Neovim with actual Claude CLI

**Step 1: Test Optimize**

1. Open any file with text in Neovim
2. Select text in visual mode
3. Press `<leader>po`
4. Input window should appear
5. Press Enter (empty input for default)
6. Spinner should show
7. Text should be replaced with optimized version

**Step 2: Test Explain**

1. Select some code
2. Press `<leader>pe`
3. Input window should appear
4. Type: "объясни подробнее" and press Enter
5. Result window should appear with explanation
6. Press `q` to close

**Step 3: Test Refactor**

1. Select some code
2. Press `<leader>pr`
3. Press Enter
4. Code should be replaced with refactored version

**Step 4: Test Translate**

1. Select English text
2. Press `<leader>pt`
3. Press Enter
4. Text should be replaced with Russian translation

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: botglue.nvim MVP complete

Four operations: optimize, explain, refactor, translate
Input window with Enter=submit, Shift+Enter=newline
Result window for Explain operation"
```

---

## Summary

| Task | Description | Estimated Complexity |
|------|-------------|---------------------|
| 1 | PROMPTS + ResultMode | Simple |
| 2 | capture_input window | Medium |
| 3 | show_result_window | Simple |
| 4 | Update build_prompt | Simple |
| 5 | run_operation | Medium |
| 6 | Four operation wrappers | Simple |
| 7 | Keymaps registration | Simple |
| 8 | Manual testing | Manual |
