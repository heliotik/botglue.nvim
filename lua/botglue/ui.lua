local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
local spinner_timer = nil

function M.start_spinner(message)
  spinner_index = 1
  spinner_timer = vim.uv.new_timer()
  spinner_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      spinner_index = (spinner_index % #spinner_frames) + 1
      vim.api.nvim_echo(
        { { spinner_frames[spinner_index] .. " " .. message, "Comment" } },
        false,
        {}
      )
    end)
  )
end

function M.stop_spinner(final_message, level)
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  vim.api.nvim_echo({ { "", "" } }, false, {})
  if final_message then
    vim.notify(final_message, level or vim.log.levels.INFO)
  end
end

function M.capture_input(title, on_submit, on_cancel)
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
    if on_cancel then
      on_cancel()
    end
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<S-CR>", newline, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })

  vim.cmd("startinsert")
end

function M.show_result_window(text, title)
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

return M
