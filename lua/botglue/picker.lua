local history = require("botglue.history")
local config = require("botglue.config")
local ui = require("botglue.ui")

local M = {}

--- Ensure BotglueActiveBorder highlight group exists.
local function ensure_highlights()
  local ok = pcall(vim.api.nvim_get_hl_by_name, "BotglueActiveBorder", true)
  if not ok or vim.tbl_isempty(vim.api.nvim_get_hl_by_name("BotglueActiveBorder", true)) then
    vim.api.nvim_set_hl(0, "BotglueActiveBorder", { link = "DiagnosticWarn" })
  end
end

--- Compute shared layout width based on editor size.
--- @return number width, number col
local function layout_dimensions()
  local ui_width = vim.o.columns
  local width = math.min(math.floor(ui_width * 0.6), 80)
  local col = math.floor((ui_width - width) / 2)
  return width, col
end

--- Open only Panel 3 (no Telescope), used when history is empty.
--- @param on_submit fun(prompt: string, model: string)
function M._open_prompt_only(on_submit)
  ensure_highlights()

  local width, col = layout_dimensions()
  local ui_height = vim.o.lines
  local row = math.floor(ui_height * 0.3)

  local handle = ui.create_prompt_window({
    width = width,
    row = row,
    col = col,
    model = config.options.model,
  })

  handle.set_border_hl("BotglueActiveBorder")

  local closed = false
  local function close_all()
    if closed then
      return
    end
    closed = true
    handle.close()
  end

  local function submit()
    local text = vim.trim(handle.get_text())
    local model = handle.get_model()
    close_all()
    if text ~= "" then
      on_submit(text, model)
    end
  end

  local buf = handle.buf

  -- Shift+Enter: submit (insert + normal)
  vim.keymap.set("i", "<S-CR>", submit, { buffer = buf })
  vim.keymap.set("n", "<S-CR>", submit, { buffer = buf })

  -- Shift+Tab: cycle model (insert + normal)
  vim.keymap.set("i", "<S-Tab>", function()
    handle.cycle_model()
  end, { buffer = buf })
  vim.keymap.set("n", "<S-Tab>", function()
    handle.cycle_model()
  end, { buffer = buf })

  -- Esc (normal): close
  vim.keymap.set("n", "<Esc>", close_all, { buffer = buf })

  -- q (normal): close
  vim.keymap.set("n", "q", close_all, { buffer = buf })
end

--- Open the full three-panel UI (Telescope + prompt editor).
--- @param entries table[] sorted history entries from history.get_sorted()
--- @param on_submit fun(prompt: string, model: string)
function M._open_full(entries, on_submit)
  ensure_highlights()

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("botglue: telescope.nvim is required", vim.log.levels.ERROR)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local width = layout_dimensions()
  local telescope_height = math.min(#entries, 10) + 3

  local prompt_handle = nil
  local closed = false
  local draft = { text = "" }
  local cursor_autocmd_id = nil
  local original_telescope_close = actions.close

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { remaining = true },
      { width = 10 },
    },
  })

  local function make_display(entry)
    return displayer({
      entry.value.prompt,
      { "[" .. entry.value.model .. "]", "Comment" },
    })
  end

  --- Close all panels idempotently.
  local function close_all(prompt_bufnr)
    if closed then
      return
    end
    closed = true

    -- Restore original actions.close before using it
    actions.close = original_telescope_close

    if cursor_autocmd_id then
      pcall(vim.api.nvim_del_autocmd, cursor_autocmd_id)
      cursor_autocmd_id = nil
    end

    if prompt_handle then
      prompt_handle.close()
    end

    if prompt_bufnr then
      pcall(actions.close, prompt_bufnr)
    end
  end

  --- Submit from Panel 3.
  local function submit_from_prompt(prompt_bufnr)
    if not prompt_handle then
      return
    end
    local text = vim.trim(prompt_handle.get_text())
    local model = prompt_handle.get_model()
    close_all(prompt_bufnr)
    if text ~= "" then
      on_submit(text, model)
    end
  end

  --- Quick submit from Telescope list (Shift+Enter).
  local function quick_submit(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if not selection then
      return
    end
    local prompt_text = selection.value.prompt
    local model = selection.value.model
    close_all(prompt_bufnr)
    on_submit(prompt_text, model)
  end

  --- Focus Panel 3 (prompt editor), making it active.
  local function focus_prompt()
    if prompt_handle and prompt_handle.is_valid() then
      prompt_handle.set_border_hl("BotglueActiveBorder")
      prompt_handle.focus()
    end
  end

  --- Focus Telescope results, making it active.
  local function focus_telescope(prompt_bufnr)
    if prompt_handle and prompt_handle.is_valid() then
      prompt_handle.set_border_hl("FloatBorder")
    end
    -- Return focus to Telescope prompt buffer's associated results window
    local picker_obj = action_state.get_current_picker(prompt_bufnr)
    if
      picker_obj
      and picker_obj.results_win
      and vim.api.nvim_win_is_valid(picker_obj.results_win)
    then
      vim.api.nvim_set_current_win(picker_obj.results_win)
    end
  end

  --- Get the currently highlighted entry's prompt and model.
  --- @return string|nil prompt, string|nil model
  local function get_highlighted_entry()
    local selection = action_state.get_selected_entry()
    if selection and selection.value then
      return selection.value.prompt, selection.value.model
    end
    return nil, nil
  end

  --- Create Panel 3 positioned below Telescope results window.
  --- Sets keymaps that need prompt_bufnr.
  --- @param prompt_bufnr number Telescope prompt buffer number
  local function ensure_prompt_window(prompt_bufnr)
    if prompt_handle and prompt_handle.is_valid() then
      return
    end

    local picker_obj = action_state.get_current_picker(prompt_bufnr)
    if not picker_obj or not picker_obj.results_win then
      return
    end

    local results_win = picker_obj.results_win
    local win_config = vim.api.nvim_win_get_config(results_win)

    -- Position Panel 3 directly below the Telescope results window
    local prompt_row = (win_config.row[false] or win_config.row)
      + (win_config.height or telescope_height)
      + 2
    local prompt_col = win_config.col[false] or win_config.col

    -- Get the model from the currently highlighted entry, or use default
    local _, highlighted_model = get_highlighted_entry()
    local initial_model = highlighted_model or config.options.model

    prompt_handle = ui.create_prompt_window({
      width = width,
      row = prompt_row,
      col = prompt_col,
      model = initial_model,
    })

    prompt_handle.set_border_hl("FloatBorder")

    -- Show preview of the first highlighted entry
    local highlighted_prompt = get_highlighted_entry()
    if highlighted_prompt then
      prompt_handle.set_preview(highlighted_prompt)
    end

    local pbuf = prompt_handle.buf

    -- Panel 3 keymaps

    -- Shift+Enter: submit (insert + normal)
    vim.keymap.set("i", "<S-CR>", function()
      submit_from_prompt(prompt_bufnr)
    end, { buffer = pbuf })
    vim.keymap.set("n", "<S-CR>", function()
      submit_from_prompt(prompt_bufnr)
    end, { buffer = pbuf })

    -- Shift+Tab: cycle model (insert + normal)
    vim.keymap.set("i", "<S-Tab>", function()
      prompt_handle.cycle_model()
    end, { buffer = pbuf })
    vim.keymap.set("n", "<S-Tab>", function()
      prompt_handle.cycle_model()
    end, { buffer = pbuf })

    -- Tab: save draft and return to Telescope (insert + normal)
    vim.keymap.set("i", "<Tab>", function()
      draft.text = prompt_handle.get_text()
      focus_telescope(prompt_bufnr)
    end, { buffer = pbuf })
    vim.keymap.set("n", "<Tab>", function()
      draft.text = prompt_handle.get_text()
      focus_telescope(prompt_bufnr)
    end, { buffer = pbuf })

    -- Esc (normal): close everything
    vim.keymap.set("n", "<Esc>", function()
      close_all(prompt_bufnr)
    end, { buffer = pbuf })

    -- q (normal): close everything
    vim.keymap.set("n", "q", function()
      close_all(prompt_bufnr)
    end, { buffer = pbuf })

    -- Set up CursorMoved autocmd on Telescope results buffer to update preview
    local results_buf = vim.api.nvim_win_get_buf(results_win)
    cursor_autocmd_id = vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = results_buf,
      callback = function()
        if closed then
          return
        end
        if not prompt_handle or not prompt_handle.is_valid() then
          return
        end
        -- Only update preview if Panel 3 is not focused (i.e., user is browsing the list)
        local current_win = vim.api.nvim_get_current_win()
        if current_win == prompt_handle.win then
          return
        end
        local sel_prompt, sel_model = get_highlighted_entry()
        if sel_prompt then
          prompt_handle.set_preview(sel_prompt)
        end
        if sel_model then
          prompt_handle.set_model(sel_model)
        end
      end,
    })

    -- Return focus to Telescope results after creating the window
    focus_telescope(prompt_bufnr)
  end

  pickers
    .new({}, {
      prompt_title = "Botglue",
      layout_strategy = "vertical",
      layout_config = {
        prompt_position = "top",
        width = width,
        height = telescope_height,
      },
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.prompt,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        -- Create Panel 3 after Telescope has rendered
        vim.schedule(function()
          if not closed then
            ensure_prompt_window(prompt_bufnr)
          end
        end)

        -- Override close to also close Panel 3 when Telescope closes itself
        actions.close = function(bufnr)
          close_all(bufnr)
        end

        -- Enter: populate Panel 3 with selected entry, focus Panel 3
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if selection and prompt_handle and prompt_handle.is_valid() then
            draft.text = selection.value.prompt
            prompt_handle.set_draft(draft.text)
            prompt_handle.set_model(selection.value.model)
            prompt_handle.set_border_hl("BotglueActiveBorder")
            prompt_handle.focus()
          elseif prompt_handle and prompt_handle.is_valid() then
            -- No selection, just focus Panel 3 with current draft
            prompt_handle.set_draft(draft.text)
            prompt_handle.set_border_hl("BotglueActiveBorder")
            prompt_handle.focus()
          end
        end)

        -- Shift+Enter: quick submit from Telescope
        vim.keymap.set("i", "<S-CR>", function()
          quick_submit(prompt_bufnr)
        end, { buffer = prompt_bufnr })
        vim.keymap.set("n", "<S-CR>", function()
          quick_submit(prompt_bufnr)
        end, { buffer = prompt_bufnr })

        -- Tab: focus Panel 3 with current draft (no new selection)
        vim.keymap.set("i", "<Tab>", function()
          if prompt_handle and prompt_handle.is_valid() then
            prompt_handle.set_draft(draft.text)
            focus_prompt()
          end
        end, { buffer = prompt_bufnr })
        vim.keymap.set("n", "<Tab>", function()
          if prompt_handle and prompt_handle.is_valid() then
            prompt_handle.set_draft(draft.text)
            focus_prompt()
          end
        end, { buffer = prompt_bufnr })

        return true
      end,
    })
    :find()
end

--- Open the picker UI.
--- When history is empty, opens only the prompt editor (Panel 3).
--- When history exists, opens the full three-panel UI (Telescope + prompt editor).
--- @param on_submit fun(prompt: string, model: string)
function M.open(on_submit)
  local entries = history.get_sorted()
  if #entries == 0 then
    M._open_prompt_only(on_submit)
  else
    M._open_full(entries, on_submit)
  end
end

return M
