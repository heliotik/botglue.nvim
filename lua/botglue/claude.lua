local config = require("botglue.config")

local M = {}

M._active_job = nil
M._timeout_timer = nil

--- Build the system prompt with file and selection context.
--- @param ctx table {filepath, start_line, end_line, filetype, project}
--- @return string
function M.build_system_prompt(ctx)
  return string.format(
    [[You are an inline code editor inside Neovim.
The user selected a region in file: %s (lines %d-%d).
Filetype: %s. Project: %s.

Read the file if you need surrounding context to understand the code.
Modify ONLY the selected region based on the user's request.
Return ONLY the replacement code — no explanations, no markdown fences, no extra text.
The output will directly replace the selection in the editor.]],
    ctx.filepath,
    ctx.start_line,
    ctx.end_line,
    ctx.filetype,
    ctx.project
  )
end

--- Build the CLI command array.
--- @param prompt string user's prompt text
--- @param ctx table {filepath, start_line, end_line, filetype, project, model}
--- @return string[]
function M.build_command(prompt, ctx)
  local system_prompt = M.build_system_prompt(ctx)
  return {
    "claude",
    "-p",
    prompt,
    "--output-format",
    "stream-json",
    "--verbose",
    "--allowedTools",
    "Read,Grep,Glob",
    "--model",
    ctx.model,
    "--max-turns",
    tostring(config.options.max_turns),
    "--append-system-prompt",
    system_prompt,
  }
end

--- Start a Claude Code request.
--- @param prompt string
--- @param ctx table
--- @param observer table {on_stdout: fn(parsed), on_complete: fn(err, result)}
function M.start(prompt, ctx, observer)
  if M._active_job and M._active_job > 0 then
    observer.on_complete("Another request is already running", nil)
    return
  end

  local cmd = M.build_command(prompt, ctx)
  local stdout_chunks = {}

  M._active_job = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if not data then
        return
      end
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(stdout_chunks, line)
          local ok, parsed = pcall(vim.json.decode, line)
          if ok and parsed then
            if observer.on_stdout then
              observer.on_stdout(parsed)
            end
          end
        end
      end
    end,
    on_stderr = function() end,
    on_exit = function(_, code)
      M._clear_timeout()
      M._active_job = nil

      if code ~= 0 then
        vim.schedule(function()
          observer.on_complete("Claude Code exited with code " .. code, nil)
        end)
        return
      end

      vim.schedule(function()
        local result = M._extract_result(stdout_chunks)
        if result and result ~= "" then
          observer.on_complete(nil, result)
        else
          observer.on_complete("Empty response from Claude", nil)
        end
      end)
    end,
  })

  if M._active_job <= 0 then
    M._active_job = nil
    observer.on_complete("Failed to start Claude process", nil)
    return
  end

  M._start_timeout(config.options.timeout)
end

--- Extract the final text result from stream-json chunks.
--- @param chunks string[]
--- @return string|nil
function M._extract_result(chunks)
  local result_parts = {}

  for _, chunk in ipairs(chunks) do
    local ok, parsed = pcall(vim.json.decode, chunk)
    if ok and parsed then
      if parsed.result then
        return parsed.result
      end
      if
        parsed.type == "stream_event"
        and parsed.event
        and parsed.event.delta
        and parsed.event.delta.type == "text_delta"
      then
        table.insert(result_parts, parsed.event.delta.text)
      end
    end
  end

  if #result_parts > 0 then
    return table.concat(result_parts, "")
  end

  for i = #chunks, 1, -1 do
    local ok, parsed = pcall(vim.json.decode, chunks[i])
    if ok and parsed and parsed.result then
      return parsed.result
    end
  end

  return nil
end

function M.cancel()
  if M._active_job and M._active_job > 0 then
    vim.fn.jobstop(M._active_job)
    M._active_job = nil
  end
  M._clear_timeout()
end

--- @param timeout_sec number
function M._start_timeout(timeout_sec)
  M._clear_timeout()
  M._timeout_timer = vim.uv.new_timer()
  M._timeout_timer:start(
    timeout_sec * 1000,
    0,
    vim.schedule_wrap(function()
      if M._active_job then
        M.cancel()
        vim.notify("botglue: request timed out", vim.log.levels.WARN)
      end
    end)
  )
end

function M._clear_timeout()
  if M._timeout_timer then
    M._timeout_timer:stop()
    M._timeout_timer:close()
    M._timeout_timer = nil
  end
end

return M
