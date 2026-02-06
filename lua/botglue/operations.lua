local display = require("botglue.display")
local claude = require("botglue.claude")
local config = require("botglue.config")

local M = {}

--- Get visual selection from the specified buffer.
--- Must be called while the original buffer is still current,
--- before opening any UI (picker, input window).
--- @param bufnr number|nil buffer number (defaults to current buffer)
--- @return table|nil selection data
function M.get_visual_selection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 then
    return nil
  end

  local is_linewise = end_pos[3] >= 2147483647 or start_pos[3] >= 2147483647

  local start_col, end_col

  if is_linewise then
    start_col = 0
    local end_line_content = vim.api.nvim_buf_get_lines(bufnr, end_line - 1, end_line, false)[1]
    end_col = end_line_content and #end_line_content or 0
  else
    start_col = start_pos[3] - 1
    end_col = end_pos[3]

    local end_line_content = vim.api.nvim_buf_get_lines(bufnr, end_line - 1, end_line, false)[1]
    if end_line_content then
      end_col = math.min(end_col, #end_line_content)
    end
  end

  local ok, lines =
    pcall(vim.api.nvim_buf_get_text, bufnr, start_line - 1, start_col, end_line - 1, end_col, {})

  if not ok then
    return nil
  end

  return {
    text = table.concat(lines, "\n"),
    bufnr = bufnr,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
  }
end

function M.replace_selection(sel, new_text)
  local lines = vim.split(new_text, "\n")

  local ok, err = pcall(
    vim.api.nvim_buf_set_text,
    sel.bufnr,
    sel.start_line - 1,
    sel.start_col,
    sel.end_line - 1,
    sel.end_col,
    lines
  )

  if not ok then
    vim.notify("botglue: failed to replace text: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Main entry point. Called after user submits prompt from input window.
--- @param prompt string user's prompt text
--- @param model string model to use
--- @param sel table pre-captured visual selection
function M.run(prompt, model, sel)
  if not sel or sel.text == "" then
    vim.notify("botglue: no text selected", vim.log.levels.WARN)
    return
  end

  local bufnr = sel.bufnr
  local top_mark = display.Mark.above(bufnr, sel.start_line)
  local bottom_mark = display.Mark.at(bufnr, sel.end_line)

  local top_status =
    display.RequestStatus.new(250, config.options.ai_stdout_rows, "Processing", top_mark)
  local bottom_status = display.RequestStatus.new(250, 1, "Processing", bottom_mark)

  local cleaned_up = false
  local function cleanup()
    if cleaned_up then
      return
    end
    cleaned_up = true
    top_status:stop()
    bottom_status:stop()
    top_mark:delete()
    bottom_mark:delete()
  end

  -- Store cleanup for external cancel
  M._cleanup = cleanup

  top_status:start()
  bottom_status:start()

  local ctx = {
    filepath = vim.api.nvim_buf_get_name(bufnr),
    start_line = sel.start_line,
    end_line = sel.end_line,
    filetype = vim.bo[bufnr].filetype,
    project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
    model = model,
  }
  -- Use relative path if possible
  local cwd = vim.fn.getcwd() .. "/"
  if ctx.filepath:sub(1, #cwd) == cwd then
    ctx.filepath = ctx.filepath:sub(#cwd + 1)
  end

  claude.start(prompt, ctx, {
    on_stdout = function(parsed)
      if parsed.type == "stream_event" and parsed.event then
        local delta = parsed.event.delta
        if delta and delta.type == "tool_use" then
          top_status:push("Using " .. (delta.name or "tool") .. "...")
        end
      end
    end,
    -- on_complete is already called inside vim.schedule by claude.lua
    on_complete = function(err, result)
      cleanup()
      if err then
        vim.notify("botglue: " .. err, vim.log.levels.ERROR)
        return
      end
      M.replace_selection(sel, result)
      vim.notify("botglue: done", vim.log.levels.INFO)
    end,
  })
end

function M.cancel()
  claude.cancel()
  if M._cleanup then
    M._cleanup()
    M._cleanup = nil
  end
  vim.notify("botglue: cancelled", vim.log.levels.WARN)
end

return M
