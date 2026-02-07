local config = require("botglue.config")

local M = {}

local preview_ns = vim.api.nvim_create_namespace("botglue_preview")

--- Cycle to next model in list. Pure function for testability.
--- @param current string current model name
--- @param models string[] ordered list of model names
--- @return string next model
function M._next_model(current, models)
  local idx = 1
  for i, m in ipairs(models) do
    if m == current then
      idx = i
      break
    end
  end
  return models[(idx % #models) + 1]
end

--- Resolve input text into submit or cancel action. Pure function for testability.
--- @param text string raw input text (may be multi-line)
--- @param on_submit fun(prompt: string, model: string)
--- @param on_cancel fun()|nil
--- @param model string current model
function M._resolve_input(text, on_submit, on_cancel, model)
  local input = vim.trim(text)
  if input ~= "" then
    on_submit(input, model)
  elseif on_cancel then
    on_cancel()
  end
end

--- Create a prompt editor window (panel 3) and return a handle.
--- @param opts { width: number, row: number, col: number, model: string|nil }
--- @return table handle with buf, win, and control methods
function M.create_prompt_window(opts)
  opts = opts or {}
  local current_model = opts.model or config.options.model
  local models = config.options.models
  local enter = opts.enter ~= false
  local no_border = opts.no_border or false
  local no_footer = opts.no_footer or false

  local height = 5

  local function make_footer()
    return " [" .. current_model .. "] "
  end

  local buf = vim.api.nvim_create_buf(false, true)

  local win_opts = {
    relative = "editor",
    width = opts.width,
    height = height,
    row = opts.row,
    col = opts.col,
    style = "minimal",
  }
  if no_border then
    win_opts.border = "none"
  else
    win_opts.border = "rounded"
    win_opts.title = " prompt "
    win_opts.title_pos = "left"
  end
  if not no_border and not no_footer then
    win_opts.footer = make_footer()
    win_opts.footer_pos = "right"
  end
  if opts.zindex then
    win_opts.zindex = opts.zindex
  end

  local win = vim.api.nvim_open_win(buf, enter, win_opts)

  vim.bo[buf].bufhidden = "wipe"
  vim.wo[win].wrap = true
  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].completefunc = ""
  vim.bo[buf].omnifunc = ""
  vim.bo[buf].complete = ""
  vim.b[buf].cmp_enabled = false
  vim.b[buf].completion = false

  local handle = {}
  handle.buf = buf
  handle.win = win

  --- Check if window and buffer still exist.
  --- @return boolean
  function handle.is_valid()
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)
  end

  --- Read buffer content as a single string.
  --- @return string
  function handle.get_text()
    if not handle.is_valid() then
      return ""
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return table.concat(lines, "\n")
  end

  --- Write text into the buffer.
  --- @param text string
  function handle.set_text(text)
    if not handle.is_valid() then
      return
    end
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  --- Show text as dimmed preview (Comment highlight), set buffer to non-modifiable.
  --- @param text string
  function handle.set_preview(text)
    if not handle.is_valid() then
      return
    end
    vim.bo[buf].modifiable = true
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
    for i = 0, #lines - 1 do
      vim.api.nvim_buf_add_highlight(buf, preview_ns, "Comment", i, 0, -1)
    end
    vim.bo[buf].modifiable = false
  end

  --- Restore editable mode, clear preview highlights, optionally set text.
  --- @param text string
  function handle.set_draft(text)
    if not handle.is_valid() then
      return
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  --- Get the current model name.
  --- @return string
  function handle.get_model()
    return current_model
  end

  --- Set the current model and update the footer.
  --- @param model string
  function handle.set_model(model)
    current_model = model
    if not no_footer and handle.is_valid() then
      vim.api.nvim_win_set_config(win, {
        footer = make_footer(),
        footer_pos = "right",
      })
    end
  end

  --- Cycle to the next model and update the footer.
  function handle.cycle_model()
    current_model = M._next_model(current_model, models)
    if not no_footer and handle.is_valid() then
      vim.api.nvim_win_set_config(win, {
        footer = make_footer(),
        footer_pos = "right",
      })
    end
  end

  --- Focus this window.
  function handle.focus()
    if handle.is_valid() then
      vim.api.nvim_set_current_win(win)
    end
  end

  --- Close the window safely.
  function handle.close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  return handle
end

return M
