local history = require("botglue.history")
local config = require("botglue.config")
local ui = require("botglue.ui")

local M = {}

--- Build a horizontal divider line: "── Label ────────" padded to width.
--- @param label string section label (e.g. "Recent prompts")
--- @param width number target display width
--- @return string
function M._make_divider(label, width)
  if label == "" then
    return string.rep("─", width)
  end
  local prefix = "── " .. label .. " "
  local prefix_w = vim.fn.strdisplaywidth(prefix)
  if prefix_w >= width then
    return vim.fn.strcharpart(prefix, 0, width)
  end
  return prefix .. string.rep("─", width - prefix_w)
end

--- Truncate prompt text to fit within max_width display columns.
--- Uses strdisplaywidth for correct UTF-8/CJK handling.
--- @param text string prompt text
--- @param max_width number max display columns
--- @return string truncated text (with "…" suffix if truncated)
function M._truncate_prompt(text, max_width)
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  local chars = vim.fn.strchars(text)
  for i = chars, 1, -1 do
    local candidate = vim.fn.strcharpart(text, 0, i) .. "…"
    if vim.fn.strdisplaywidth(candidate) <= max_width then
      return candidate
    end
  end
  return "…"
end

local ACTIVE_HL = "BotglueActiveBorder"

local function setup_highlights()
  local hl = vim.api.nvim_get_hl(0, { name = ACTIVE_HL })
  if vim.tbl_isempty(hl) then
    vim.api.nvim_set_hl(0, ACTIVE_HL, { link = "DiagnosticWarn" })
  end
end

local function layout_dimensions()
  local width = math.min(math.floor(vim.o.columns * 0.6), 80)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor(vim.o.lines * 0.3)
  return width, col, row
end

--- Open only Panel 3 (no history to show).
--- @param on_submit fun(prompt: string, model: string)
function M._open_prompt_only(on_submit)
  setup_highlights()
  local width, col, row = layout_dimensions()

  local current_model = config.options.model
  local models = config.options.models

  local prompt_height = 5
  local container_height = prompt_height

  -- Container (background frame)
  local container_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[container_buf].bufhidden = "wipe"
  local container_lines = {}
  for _ = 1, container_height do
    table.insert(container_lines, string.rep(" ", width))
  end
  vim.api.nvim_buf_set_lines(container_buf, 0, -1, false, container_lines)

  local function make_footer()
    return " [" .. current_model .. "] "
  end

  local container_win = vim.api.nvim_open_win(container_buf, false, {
    relative = "editor",
    width = width,
    height = container_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " BotGlue ",
    title_pos = "center",
    footer = make_footer(),
    footer_pos = "right",
    focusable = false,
    zindex = 40,
  })
  vim.api.nvim_set_option_value("winhl", "FloatBorder:" .. ACTIVE_HL, { win = container_win })

  -- Prompt panel (inside container, no border)
  local handle = ui.create_prompt_window({
    width = width,
    row = row + 1,
    col = col + 1,
    model = current_model,
    no_border = true,
    no_footer = true,
    zindex = 50,
  })

  -- Prompt placeholder
  local placeholder_ns = vim.api.nvim_create_namespace("botglue_prompt_placeholder")
  local function update_prompt_placeholder()
    if not handle.is_valid() then
      return
    end
    vim.api.nvim_buf_clear_namespace(handle.buf, placeholder_ns, 0, -1)
    local text = vim.api.nvim_buf_get_lines(handle.buf, 0, 1, false)[1] or ""
    if text == "" then
      vim.api.nvim_buf_set_extmark(handle.buf, placeholder_ns, 0, 0, {
        virt_text = { { "Type your prompt here...", "Comment" } },
        virt_text_pos = "overlay",
      })
    end
  end
  update_prompt_placeholder()

  local closed = false
  local autocmd_ids = {}

  local function close_all()
    if closed then
      return
    end
    closed = true
    for _, id in ipairs(autocmd_ids) do
      pcall(vim.api.nvim_del_autocmd, id)
    end
    handle.close()
    if vim.api.nvim_win_is_valid(container_win) then
      vim.api.nvim_win_close(container_win, true)
    end
  end

  local function update_container_footer()
    if vim.api.nvim_win_is_valid(container_win) then
      vim.api.nvim_win_set_config(container_win, {
        footer = make_footer(),
        footer_pos = "right",
      })
    end
  end

  local function submit()
    local text = vim.trim(handle.get_text())
    close_all()
    if text ~= "" then
      on_submit(text, current_model)
    end
  end

  local buf = handle.buf
  vim.keymap.set("n", "<CR>", submit, { buffer = buf })
  vim.keymap.set({ "i", "n" }, "<C-s>", submit, { buffer = buf })
  vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
    current_model = ui._next_model(current_model, models)
    handle.set_model(current_model)
    update_container_footer()
  end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = buf })
  vim.keymap.set("n", "q", close_all, { buffer = buf })

  -- Prompt placeholder autocmd
  table.insert(
    autocmd_ids,
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      buffer = buf,
      callback = function()
        if closed then
          return
        end
        update_prompt_placeholder()
      end,
    })
  )

  -- Close on focus loss
  table.insert(
    autocmd_ids,
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer = buf,
      callback = function()
        if closed then
          return
        end
        vim.schedule(function()
          if closed then
            return
          end
          local cur = vim.api.nvim_get_current_win()
          if cur ~= handle.win and cur ~= container_win then
            close_all()
          end
        end)
      end,
    })
  )
end

--- Open the full three-panel UI with custom float windows.
--- @param entries table[] history entries sorted by frequency
--- @param on_submit fun(prompt: string, model: string)
function M._open_full(entries, on_submit)
  setup_highlights()
  local width, col, top_row = layout_dimensions()

  -- State
  local all_entries = entries
  local filtered_entries = entries
  local selected_idx = 1
  local draft = { text = "", model = config.options.model }
  local closed = false
  local autocmd_ids = {}
  local match_positions = {}
  local list_ns = vim.api.nvim_create_namespace("botglue_list")
  local filter_hl_ns = vim.api.nvim_create_namespace("botglue_filter_hl")

  -- Layout: container interior rows
  local filter_height = 1
  local list_height = math.min(#entries, 10)
  local prompt_height = 5
  local divider_height = 1
  local container_height = filter_height
    + divider_height
    + list_height
    + divider_height
    + prompt_height

  -- Container (background frame)
  local container_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[container_buf].bufhidden = "wipe"

  -- Build container buffer: empty rows + divider lines
  local container_lines = {}
  -- Row 0: filter area (covered by filter_win)
  table.insert(container_lines, string.rep(" ", width))
  -- Row 1: divider "── Recent prompts ──────"
  table.insert(container_lines, M._make_divider("Recent prompts", width))
  -- Rows 2..1+list_height: list area (covered by list_win)
  for _ = 1, list_height do
    table.insert(container_lines, string.rep(" ", width))
  end
  -- Row 2+list_height: divider "── Prompt ──────"
  table.insert(container_lines, M._make_divider("Prompt", width))
  -- Rows 3+list_height..end: prompt area (covered by prompt_win)
  for _ = 1, prompt_height do
    table.insert(container_lines, string.rep(" ", width))
  end
  vim.api.nvim_buf_set_lines(container_buf, 0, -1, false, container_lines)

  -- Highlight divider lines
  local divider_ns = vim.api.nvim_create_namespace("botglue_divider")
  vim.api.nvim_buf_add_highlight(container_buf, divider_ns, "FloatBorder", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(container_buf, divider_ns, "FloatBorder", 2 + list_height, 0, -1)

  local function make_footer()
    return " [" .. draft.model .. "] "
  end

  local container_win = vim.api.nvim_open_win(container_buf, false, {
    relative = "editor",
    width = width,
    height = container_height,
    row = top_row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " BotGlue ",
    title_pos = "center",
    footer = make_footer(),
    footer_pos = "right",
    focusable = false,
    zindex = 40,
  })
  vim.api.nvim_set_option_value("winhl", "FloatBorder:" .. ACTIVE_HL, { win = container_win })

  -- Inner panel positions (offset by container border)
  local inner_col = col + 1
  local inner_width = width

  -- Panel 1: Filter (row 0 inside container)
  local filter_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[filter_buf].bufhidden = "wipe"
  vim.bo[filter_buf].buftype = "nofile"
  vim.bo[filter_buf].completefunc = ""
  vim.bo[filter_buf].omnifunc = ""
  vim.bo[filter_buf].complete = ""
  vim.b[filter_buf].cmp = false
  local filter_win = vim.api.nvim_open_win(filter_buf, false, {
    relative = "editor",
    width = inner_width,
    height = filter_height,
    row = top_row + 1,
    col = inner_col,
    style = "minimal",
    border = "none",
    zindex = 50,
  })

  -- Panel 2: List (row 2 inside container = after filter + divider)
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[list_buf].bufhidden = "wipe"
  vim.bo[list_buf].buftype = "nofile"
  vim.bo[list_buf].modifiable = false
  vim.bo[list_buf].completefunc = ""
  vim.bo[list_buf].omnifunc = ""
  vim.bo[list_buf].complete = ""
  vim.b[list_buf].cmp = false
  local list_win = vim.api.nvim_open_win(list_buf, false, {
    relative = "editor",
    width = inner_width,
    height = list_height,
    row = top_row + 1 + filter_height + divider_height,
    col = inner_col,
    style = "minimal",
    border = "none",
    zindex = 50,
  })
  vim.wo[list_win].cursorline = true

  -- Panel 3: Prompt (after list + second divider)
  local prompt_handle = ui.create_prompt_window({
    width = inner_width,
    row = top_row + 1 + filter_height + divider_height + list_height + divider_height,
    col = inner_col,
    model = draft.model,
    enter = false,
    no_border = true,
    no_footer = true,
    zindex = 50,
  })

  -- === Core functions ===

  local function render_list()
    local lines = {}
    local available = inner_width - 2
    for _, entry in ipairs(filtered_entries) do
      local prompt_text = M._truncate_prompt(entry.prompt, available)
      table.insert(lines, "  " .. prompt_text)
    end
    if #lines == 0 then
      lines = { "  (no matches)" }
    end
    vim.bo[list_buf].modifiable = true
    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
    -- Model tags as right-aligned extmarks
    vim.api.nvim_buf_clear_namespace(list_buf, list_ns, 0, -1)
    for i, entry in ipairs(filtered_entries) do
      vim.api.nvim_buf_set_extmark(list_buf, list_ns, i - 1, 0, {
        virt_text = { { "[" .. entry.model .. "]", "Comment" } },
        virt_text_pos = "right_align",
      })
    end
    -- Highlight fuzzy match positions
    vim.api.nvim_buf_clear_namespace(list_buf, filter_hl_ns, 0, -1)
    for i, entry in ipairs(filtered_entries) do
      local positions = match_positions[entry.prompt]
      if positions then
        for _, pos in ipairs(positions) do
          local byte_pos = pos + 2
          pcall(
            vim.api.nvim_buf_add_highlight,
            list_buf,
            filter_hl_ns,
            "Search",
            i - 1,
            byte_pos,
            byte_pos + 1
          )
        end
      end
    end
    vim.bo[list_buf].modifiable = false
    selected_idx = math.max(1, math.min(selected_idx, #filtered_entries))
    if vim.api.nvim_win_is_valid(list_win) and #filtered_entries > 0 then
      vim.api.nvim_win_set_cursor(list_win, { selected_idx, 0 })
    end
  end

  local function update_preview()
    if not prompt_handle or not prompt_handle.is_valid() then
      return
    end
    if #filtered_entries == 0 then
      return
    end
    local entry = filtered_entries[selected_idx]
    if entry then
      prompt_handle.set_preview(entry.prompt)
      prompt_handle.set_model(entry.model)
    end
  end

  -- Filter placeholder
  local placeholder_ns = vim.api.nvim_create_namespace("botglue_filter_placeholder")
  local function update_filter_placeholder()
    vim.api.nvim_buf_clear_namespace(filter_buf, placeholder_ns, 0, -1)
    local text = vim.api.nvim_buf_get_lines(filter_buf, 0, 1, false)[1] or ""
    if text == "" then
      vim.api.nvim_buf_set_extmark(filter_buf, placeholder_ns, 0, 0, {
        virt_text = { { "Filter recent prompts - press / to focus", "Comment" } },
        virt_text_pos = "overlay",
      })
    end
  end

  local function apply_filter()
    local text = vim.trim(vim.api.nvim_buf_get_lines(filter_buf, 0, 1, false)[1] or "")
    match_positions = {}
    if text == "" then
      filtered_entries = all_entries
    else
      local prompts = vim.tbl_map(function(e)
        return e.prompt
      end, all_entries)
      local result = vim.fn.matchfuzzypos(prompts, text)
      local matched = result[1]
      local positions = result[2]
      local matched_map = {}
      for i, m in ipairs(matched) do
        matched_map[m] = positions[i]
      end
      filtered_entries = vim.tbl_filter(function(e)
        return matched_map[e.prompt] ~= nil
      end, all_entries)
      for _, e in ipairs(filtered_entries) do
        match_positions[e.prompt] = matched_map[e.prompt]
      end
    end
    selected_idx = 1
    render_list()
    update_preview()
    update_filter_placeholder()
  end

  -- === Focus management ===

  local function focus_list()
    if vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_set_current_win(list_win)
    end
  end

  local function focus_filter()
    if vim.api.nvim_win_is_valid(filter_win) then
      vim.api.nvim_set_current_win(filter_win)
      vim.cmd("startinsert!")
    end
  end

  local function focus_prompt(selected_text)
    if selected_text then
      draft.text = selected_text
    end
    prompt_handle.set_draft(draft.text)
    prompt_handle.focus()
  end

  -- === Actions ===

  local function close_all()
    if closed then
      return
    end
    closed = true
    for _, id in ipairs(autocmd_ids) do
      pcall(vim.api.nvim_del_autocmd, id)
    end
    prompt_handle.close()
    if vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_win_close(list_win, true)
    end
    if vim.api.nvim_win_is_valid(filter_win) then
      vim.api.nvim_win_close(filter_win, true)
    end
    if vim.api.nvim_win_is_valid(container_win) then
      vim.api.nvim_win_close(container_win, true)
    end
  end

  local function update_container_footer()
    if vim.api.nvim_win_is_valid(container_win) then
      vim.api.nvim_win_set_config(container_win, {
        footer = make_footer(),
        footer_pos = "right",
      })
    end
  end

  local function quick_submit()
    if #filtered_entries == 0 then
      return
    end
    local entry = filtered_entries[selected_idx]
    if entry then
      close_all()
      on_submit(entry.prompt, entry.model)
    end
  end

  local function submit_prompt()
    if not prompt_handle or not prompt_handle.is_valid() then
      return
    end
    local text = vim.trim(prompt_handle.get_text())
    local model = prompt_handle.get_model()
    close_all()
    if text ~= "" then
      on_submit(text, model)
    end
  end

  local function select_entry()
    if #filtered_entries == 0 then
      return
    end
    local entry = filtered_entries[selected_idx]
    if entry then
      focus_prompt(entry.prompt)
      prompt_handle.set_model(entry.model)
    end
  end

  local function navigate_from_filter(direction)
    if direction == "down" then
      selected_idx = math.min(selected_idx + 1, #filtered_entries)
    else
      selected_idx = math.max(selected_idx - 1, 1)
    end
    if vim.api.nvim_win_is_valid(list_win) and #filtered_entries > 0 then
      vim.api.nvim_win_set_cursor(list_win, { selected_idx, 0 })
    end
    update_preview()
  end

  -- === Keymaps: List (Panel 2) ===

  vim.keymap.set("n", "/", focus_filter, { buffer = list_buf })
  vim.keymap.set("n", "<CR>", select_entry, { buffer = list_buf })
  vim.keymap.set("n", "<C-s>", quick_submit, { buffer = list_buf })
  vim.keymap.set("n", "<Tab>", function()
    focus_prompt(nil)
  end, { buffer = list_buf })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = list_buf })
  vim.keymap.set("n", "q", close_all, { buffer = list_buf })

  -- === Keymaps: Filter (Panel 1) ===

  vim.keymap.set("i", "<CR>", select_entry, { buffer = filter_buf })
  vim.keymap.set("i", "<C-j>", function()
    navigate_from_filter("down")
  end, { buffer = filter_buf })
  vim.keymap.set("i", "<C-k>", function()
    navigate_from_filter("up")
  end, { buffer = filter_buf })
  vim.keymap.set("i", "<C-s>", quick_submit, { buffer = filter_buf })
  vim.keymap.set("i", "<Esc>", function()
    vim.api.nvim_buf_set_lines(filter_buf, 0, -1, false, { "" })
    apply_filter()
    focus_list()
  end, { buffer = filter_buf })
  vim.keymap.set("i", "<Tab>", function()
    focus_prompt(nil)
  end, { buffer = filter_buf })

  -- === Keymaps: Prompt (Panel 3) ===

  local pbuf = prompt_handle.buf
  vim.keymap.set("n", "<CR>", submit_prompt, { buffer = pbuf })
  vim.keymap.set({ "i", "n" }, "<C-s>", submit_prompt, { buffer = pbuf })
  vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
    prompt_handle.cycle_model()
    draft.model = prompt_handle.get_model()
    update_container_footer()
  end, { buffer = pbuf })
  vim.keymap.set("n", "<Tab>", function()
    draft.text = prompt_handle.get_text()
    draft.model = prompt_handle.get_model()
    update_preview()
    focus_list()
  end, { buffer = pbuf })
  vim.keymap.set("i", "<Tab>", function()
    draft.text = prompt_handle.get_text()
    draft.model = prompt_handle.get_model()
    vim.cmd("stopinsert")
    update_preview()
    focus_list()
  end, { buffer = pbuf })
  vim.keymap.set("n", "<Esc>", close_all, { buffer = pbuf })
  vim.keymap.set("n", "q", close_all, { buffer = pbuf })

  -- === Autocmds ===

  table.insert(
    autocmd_ids,
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = list_buf,
      callback = function()
        if closed then
          return
        end
        local ok, cursor = pcall(vim.api.nvim_win_get_cursor, list_win)
        if ok then
          selected_idx = cursor[1]
          update_preview()
        end
      end,
    })
  )

  table.insert(
    autocmd_ids,
    vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = filter_buf,
      callback = function()
        if closed then
          return
        end
        apply_filter()
      end,
    })
  )

  -- Close on focus loss
  local our_wins = { filter_win, list_win, prompt_handle.win, container_win }
  for _, buf in ipairs({ filter_buf, list_buf, prompt_handle.buf }) do
    table.insert(
      autocmd_ids,
      vim.api.nvim_create_autocmd("WinLeave", {
        buffer = buf,
        callback = function()
          if closed then
            return
          end
          vim.schedule(function()
            if closed then
              return
            end
            local cur = vim.api.nvim_get_current_win()
            for _, w in ipairs(our_wins) do
              if cur == w then
                return
              end
            end
            close_all()
          end)
        end,
      })
    )
  end

  -- === Initial state ===

  render_list()
  update_preview()
  update_filter_placeholder()
  focus_list()
end

--- Open the picker UI.
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
