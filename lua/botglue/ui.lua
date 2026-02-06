local config = require("botglue.config")

local M = {}

--- Open input window with model badge and cycling.
--- @param opts {prompt: string|nil, model: string|nil}
--- @param on_submit fun(prompt: string, model: string)
--- @param on_cancel fun()|nil
function M.capture_input(opts, on_submit, on_cancel)
  opts = opts or {}
  local current_model = opts.model or config.options.model
  local models = config.options.models

  local ui_info = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui_info.width * 2 / 3)
  local height = 3
  local row = math.floor((ui_info.height - height) / 2)
  local col = math.floor((ui_info.width - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)

  local function make_title()
    return " botglue "
  end

  local function make_footer()
    return " [" .. current_model .. "] "
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = make_title(),
    title_pos = "left",
    footer = make_footer(),
    footer_pos = "right",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.wo[win].wrap = true

  -- Pre-fill prompt if provided
  if opts.prompt and opts.prompt ~= "" then
    local lines = vim.split(opts.prompt, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = vim.trim(table.concat(lines, "\n"))
    close_window()
    if input ~= "" then
      on_submit(input, current_model)
    elseif on_cancel then
      on_cancel()
    end
  end

  local function newline()
    local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
    local line = vim.api.nvim_buf_get_lines(buf, cursor_row - 1, cursor_row, false)[1]
    local before = line:sub(1, cursor_col)
    local after = line:sub(cursor_col + 1)
    vim.api.nvim_buf_set_lines(buf, cursor_row - 1, cursor_row, false, { before, after })
    vim.api.nvim_win_set_cursor(win, { cursor_row + 1, 0 })
  end

  local function cycle_model()
    local idx = 1
    for i, m in ipairs(models) do
      if m == current_model then
        idx = i
        break
      end
    end
    idx = (idx % #models) + 1
    current_model = models[idx]
    vim.api.nvim_win_set_config(win, {
      footer = make_footer(),
      footer_pos = "right",
    })
  end

  local function cancel()
    close_window()
    if on_cancel then
      on_cancel()
    end
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<S-CR>", newline, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<C-s>", cycle_model, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<C-s>", cycle_model, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })

  vim.cmd("startinsert")
end

return M
