local config = require("botglue.config")

local M = {}

--- Build the system prompt with file and selection context.
--- @param ctx table {filepath, start_line, end_line, filetype, project}
--- @return string
function M.build_system_prompt(ctx)
  return string.format(
    [[You are an inline code editor inside Neovim.
File: %s (lines %d-%d). Filetype: %s. Project: %s.

Selected text:
```
%s
```

You may use Read, Grep, Glob tools to understand surrounding context.
DO NOT use Write or Edit tools. DO NOT modify files directly.
Output ONLY the replacement text as your response — nothing else.
No explanations, no markdown fences, no commentary.
Your entire response will directly replace the selection in the editor.]],
    ctx.filepath,
    ctx.start_line,
    ctx.end_line,
    ctx.filetype,
    ctx.project,
    ctx.selected_text or ""
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
    "--strict-mcp-config",
    "--append-system-prompt",
    system_prompt,
  }
end

--- Start a Claude Code request.
--- @param prompt string
--- @param ctx table
--- @param observer table {on_stdout: fn(parsed), on_complete: fn(err, result)}
--- @return table handle {job_id: number}
function M.start(prompt, ctx, observer)
  local cmd = M.build_command(prompt, ctx)
  local stdout_chunks = {}
  local partial = ""
  local handle = {}

  local function clear_timeout()
    if handle.timeout_timer then
      handle.timeout_timer:stop()
      handle.timeout_timer:close()
      handle.timeout_timer = nil
    end
  end

  handle.job_id = vim.fn.jobstart(cmd, {
    stdin = "null",
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if not data then
        return
      end
      data[1] = partial .. data[1]
      partial = data[#data]
      for i = 1, #data - 1 do
        local line = data[i]
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
      clear_timeout()
      handle.job_id = nil

      if code ~= 0 then
        vim.schedule(function()
          observer.on_complete("Claude Code exited with code " .. code, nil)
        end)
        return
      end

      vim.schedule(function()
        local result, err = M._extract_result(stdout_chunks)
        if result then
          observer.on_complete(nil, result)
        else
          observer.on_complete(err or "Empty response from Claude", nil)
        end
      end)
    end,
  })

  if handle.job_id <= 0 then
    handle.job_id = nil
    observer.on_complete("Failed to start Claude process", nil)
    return handle
  end

  handle.timeout_timer = vim.uv.new_timer()
  handle.timeout_timer:start(
    config.options.timeout * 1000,
    0,
    vim.schedule_wrap(function()
      if handle.job_id then
        vim.fn.jobstop(handle.job_id)
      end
      clear_timeout()
    end)
  )

  return handle
end

--- Extract the final text result from stream-json chunks.
--- Returns (result, error): exactly one is non-nil.
--- @param chunks string[]
--- @return string|nil result
--- @return string|nil error
function M._extract_result(chunks)
  local last_assistant_text = nil

  for _, chunk in ipairs(chunks) do
    local ok, parsed = pcall(vim.json.decode, chunk)
    if ok and parsed then
      -- Result chunk is authoritative — use it and stop.
      if parsed.type == "result" then
        if parsed.result and parsed.result ~= "" then
          return parsed.result, nil
        end
        -- Result chunk exists but no result text — report the subtype as error.
        local reason = parsed.subtype or "unknown"
        return nil, "Claude finished with: " .. reason
      end
      -- Track text from assistant messages (only the last one matters).
      if parsed.type == "assistant" and parsed.message and parsed.message.content then
        local texts = {}
        for _, block in ipairs(parsed.message.content) do
          if block.type == "text" and block.text then
            table.insert(texts, block.text)
          end
        end
        if #texts > 0 then
          last_assistant_text = table.concat(texts, "")
        end
      end
    end
  end

  -- No result chunk at all (process killed mid-stream) — best-effort fallback.
  if last_assistant_text and last_assistant_text ~= "" then
    return last_assistant_text, nil
  end

  return nil, "Empty response from Claude"
end

return M
