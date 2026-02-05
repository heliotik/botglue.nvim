local config = require("botglue.config")

local M = {}

M.PROMPTS = {
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

function M.build_prompt(operation, selected_text, user_input, context)
  local template = M.PROMPTS[operation]
  local prompt

  if operation == "translate" then
    prompt = string.format(template, selected_text)
  else
    prompt = string.format(template, context.project, context.file, context.filetype, selected_text)
  end

  if user_input and user_input ~= "" then
    prompt = prompt .. "\n\nДополнительные указания от пользователя:\n" .. user_input
  end

  return prompt
end

function M.call(prompt, callback)
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart({
    "claude",
    "-p",
    "-",
    "--output-format",
    "text",
    "--model",
    config.options.model,
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

  vim.fn.chansend(job_id, prompt)
  vim.fn.chanclose(job_id, "stdin")
end

return M
