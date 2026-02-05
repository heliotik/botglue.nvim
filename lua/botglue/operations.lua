local ui = require("botglue.ui")
local claude = require("botglue.claude")

local M = {}

M.ResultMode = {
  REPLACE = "replace",
  WINDOW = "window",
}

function M.get_visual_selection()
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
    local end_line_content = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
    end_col = end_line_content and #end_line_content or 0
  else
    start_col = start_pos[3] - 1
    end_col = end_pos[3]

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

function M.replace_selection(sel, new_text)
  local lines = vim.split(new_text, "\n")

  local ok, err =
    pcall(vim.api.nvim_buf_set_text, sel.bufnr, sel.start_line - 1, sel.start_col, sel.end_line - 1, sel.end_col, lines)

  if not ok then
    vim.notify("Failed to replace text: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.get_context()
  local cwd = vim.fn.getcwd()
  return {
    project = vim.fn.fnamemodify(cwd, ":t"),
    file = vim.fn.expand("%:."),
    filetype = vim.bo.filetype,
  }
end

function M.run(opts)
  local sel = M.get_visual_selection()
  if not sel or sel.text == "" then
    vim.notify("Нет выделенного текста", vim.log.levels.WARN)
    return
  end

  ui.capture_input(opts.input_title, function(user_input)
    ui.start_spinner(opts.spinner_msg)

    local context = M.get_context()
    local prompt = claude.build_prompt(opts.operation, sel.text, user_input, context)

    claude.call(prompt, function(err, result)
      vim.schedule(function()
        if err then
          ui.stop_spinner("✗ " .. err, vim.log.levels.ERROR)
          return
        end

        if not result or result == "" then
          ui.stop_spinner("⚠ Пустой ответ от Claude", vim.log.levels.WARN)
          return
        end

        if opts.result_mode == M.ResultMode.REPLACE then
          M.replace_selection(sel, result)
          ui.stop_spinner(opts.success_msg, vim.log.levels.INFO)
        else
          ui.stop_spinner(nil)
          ui.show_result_window(result, opts.window_title)
        end
      end)
    end)
  end)
end

return M
