return {
  name = "prompt-optimizer",
  dir = vim.fn.stdpath("config"),
  lazy = false,
  config = function()
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

    -- Спиннер для отображения прогресса (в командной строке)
    local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local spinner_index = 1
    local spinner_timer = nil

    local function start_spinner(message)
      spinner_index = 1
      spinner_timer = vim.uv.new_timer()
      spinner_timer:start(0, 100, vim.schedule_wrap(function()
        spinner_index = (spinner_index % #spinner_frames) + 1
        vim.api.nvim_echo({{ spinner_frames[spinner_index] .. " " .. message, "Comment" }}, false, {})
      end))
    end

    local function stop_spinner(final_message, level)
      if spinner_timer then
        spinner_timer:stop()
        spinner_timer:close()
        spinner_timer = nil
      end
      -- Очищаем командную строку
      vim.api.nvim_echo({{"", ""}}, false, {})
      -- Показываем финальное сообщение через notify
      if final_message then
        vim.notify(final_message, level or vim.log.levels.INFO)
      end
    end

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

    -- Получение visual selection
    local function get_visual_selection()
      local start_pos = vim.fn.getpos("'<")
      local end_pos = vim.fn.getpos("'>")

      -- getpos возвращает [bufnum, lnum, col, off] (1-indexed)
      local start_line = start_pos[2]
      local end_line = end_pos[2]

      -- Проверка что marks валидны
      if start_line == 0 or end_line == 0 then
        return nil
      end

      -- Определяем был ли это linewise selection (V mode)
      -- В V-mode колонка '> будет очень большой (v:maxcol = 2147483647)
      local is_linewise = end_pos[3] >= 2147483647 or start_pos[3] >= 2147483647

      local start_col, end_col

      if is_linewise then
        -- Для linewise берём целые строки
        start_col = 0
        local end_line_content = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
        end_col = end_line_content and #end_line_content or 0
      else
        -- Для character-wise selection
        start_col = start_pos[3] - 1 -- convert to 0-indexed
        end_col = end_pos[3] -- stay as-is for end

        -- Корректировка end_col
        local end_line_content = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
        if end_line_content then
          end_col = math.min(end_col, #end_line_content)
        end
      end

      local ok, lines = pcall(vim.api.nvim_buf_get_text, 0, start_line - 1, start_col, end_line - 1, end_col, {})

      if not ok then
        return nil
      end

      return {
        text = table.concat(lines, "\n"),
        bufnr = vim.api.nvim_get_current_buf(),
        start_line = start_line,
        start_col = start_col,
        end_line = end_line,
        end_col = end_col,
      }
    end

    -- Формирование промпта с контекстом проекта
    local function build_prompt(selected_text)
      local cwd = vim.fn.getcwd()
      local project_name = vim.fn.fnamemodify(cwd, ":t")
      local file_path = vim.fn.expand("%:.")
      local filetype = vim.bo.filetype

      return string.format(
        [[
Оптимизируй промт ниже для получения лучшего результата.
Исправь ошибки. Добавь контекста к задаче.
Верни ТОЛЬКО улучшенный текст промта, без пояснений и комментариев.

Контекст:
- Проект: %s
- Файл: %s
- Тип файла: %s

<prompt>
%s
</prompt>
]],
        project_name,
        file_path,
        filetype,
        selected_text
      )
    end

    -- Async вызов Claude Code CLI через stdin
    local function call_claude(prompt, callback)
      local stdout_data = {}
      local stderr_data = {}

      local mcp_config = vim.fn.stdpath("config") .. "/lua/plugins/prompt-optimizer-mcp.json"

      local job_id = vim.fn.jobstart({
        "claude",
        "-p",
        "-", -- читать промт из stdin
        "--output-format",
        "text",
        "--model",
        "opus",
        "--mcp-config",
        mcp_config,
        "--strict-mcp-config",
      }, {
        stdin = "pipe",
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          if data then
            vim.list_extend(stdout_data, data)
          end
        end,
        on_stderr = function(_, data)
          if data then
            vim.list_extend(stderr_data, data)
          end
        end,
        on_exit = function(_, code)
          if code == 0 then
            local result = table.concat(stdout_data, "\n")
            result = result:gsub("^%s+", ""):gsub("%s+$", "")
            callback(nil, result)
          else
            local err = table.concat(stderr_data, "\n")
            callback("Claude Code failed: " .. err, nil)
          end
        end,
      })

      if job_id <= 0 then
        callback("Failed to start Claude process", nil)
        return
      end

      -- Отправляем промт через stdin и закрываем
      vim.fn.chansend(job_id, prompt)
      vim.fn.chanclose(job_id, "stdin")
    end

    -- Замена текста в буфере
    local function replace_selection(sel, new_text)
      local lines = vim.split(new_text, "\n")

      local ok, err =
        pcall(vim.api.nvim_buf_set_text, sel.bufnr, sel.start_line - 1, sel.start_col, sel.end_line - 1, sel.end_col, lines)

      if not ok then
        vim.notify("Failed to replace text: " .. tostring(err), vim.log.levels.ERROR)
      end
    end

    -- Основная функция
    local function optimize_prompt()
      local sel = get_visual_selection()
      if not sel or sel.text == "" then
        vim.notify("No text selected", vim.log.levels.WARN)
        return
      end

      start_spinner("Optimizing prompt with Claude...")

      local prompt = build_prompt(sel.text)

      call_claude(prompt, function(err, result)
        vim.schedule(function()
          if err then
            stop_spinner("✗ " .. err, vim.log.levels.ERROR)
            return
          end

          if result and result ~= "" then
            replace_selection(sel, result)
            stop_spinner("✓ Prompt optimized!", vim.log.levels.INFO)
          else
            stop_spinner("⚠ Empty response from Claude", vim.log.levels.WARN)
          end
        end)
      end)
    end

    -- Keymap для visual mode
    -- Используем :<C-u> чтобы marks '< и '> были установлены перед вызовом функции
    vim.keymap.set("x", "<leader>po", ":<C-u>lua _G.prompt_optimizer_run()<CR>", { desc = "Optimize prompt with Claude", silent = true })

    -- Expose function globally for keymap
    _G.prompt_optimizer_run = optimize_prompt
  end,
}
