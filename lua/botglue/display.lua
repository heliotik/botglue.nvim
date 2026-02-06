local nsid = vim.api.nvim_create_namespace("botglue")

--- @class botglue.Mark
--- @field id number
--- @field buffer number
local Mark = {}
Mark.__index = Mark

--- Create extmark above a line (1-indexed).
--- @param buffer number
--- @param line number 1-indexed line number
--- @return botglue.Mark
function Mark.above(buffer, line)
  local row = line - 1
  local above = row == 0 and 0 or row - 1
  local col = 0

  if above ~= row then
    local text = vim.api.nvim_buf_get_lines(buffer, above, above + 1, false)[1]
    col = text and #text or 0
  end

  local id = vim.api.nvim_buf_set_extmark(buffer, nsid, above, col, {})
  return setmetatable({ id = id, buffer = buffer }, Mark)
end

--- Create extmark at a line (1-indexed).
--- @param buffer number
--- @param line number 1-indexed line number
--- @return botglue.Mark
function Mark.at(buffer, line)
  local row = line - 1
  local id = vim.api.nvim_buf_set_extmark(buffer, nsid, row, 0, {})
  return setmetatable({ id = id, buffer = buffer }, Mark)
end

--- @return boolean
function Mark:is_valid()
  local pos = vim.api.nvim_buf_get_extmark_by_id(self.buffer, nsid, self.id, {})
  return #pos > 0
end

--- Update virtual text lines on this mark.
--- @param lines string[]
function Mark:set_virtual_text(lines)
  local pos = vim.api.nvim_buf_get_extmark_by_id(self.buffer, nsid, self.id, {})
  if #pos == 0 then
    return
  end
  local row, col = pos[1], pos[2]

  local formatted = {}
  for _, line in ipairs(lines) do
    table.insert(formatted, { { line, "Comment" } })
  end

  vim.api.nvim_buf_set_extmark(self.buffer, nsid, row, col, {
    id = self.id,
    virt_lines = formatted,
  })
end

function Mark:delete()
  pcall(vim.api.nvim_buf_del_extmark, self.buffer, nsid, self.id)
end

local braille_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- @class botglue.StatusLine
--- @field index number
--- @field title string
local StatusLine = {}
StatusLine.__index = StatusLine

function StatusLine.new(title)
  return setmetatable({ index = 1, title = title }, StatusLine)
end

function StatusLine:update()
  self.index = self.index + 1
end

--- @return string
function StatusLine:to_string()
  return braille_chars[self.index % #braille_chars + 1] .. " " .. self.title
end

--- @class botglue.RequestStatus
--- @field update_time number
--- @field max_lines number
--- @field status_line botglue.StatusLine
--- @field lines string[]
--- @field running boolean
--- @field mark botglue.Mark
local RequestStatus = {}
RequestStatus.__index = RequestStatus

--- @param update_time number milliseconds between spinner updates
--- @param max_lines number max total lines (spinner + stdout lines)
--- @param title string title shown next to spinner
--- @param mark botglue.Mark
--- @return botglue.RequestStatus
function RequestStatus.new(update_time, max_lines, title, mark)
  return setmetatable({
    update_time = update_time,
    max_lines = max_lines,
    status_line = StatusLine.new(title),
    lines = {},
    running = false,
    mark = mark,
  }, RequestStatus)
end

--- @return string[]
function RequestStatus:get()
  local result = { self.status_line:to_string() }
  for _, line in ipairs(self.lines) do
    table.insert(result, line)
  end
  return result
end

--- @param line string
function RequestStatus:push(line)
  table.insert(self.lines, line)
  if #self.lines > self.max_lines - 1 then
    table.remove(self.lines, 1)
  end
end

function RequestStatus:start()
  self.running = true

  local function update_spinner()
    if not self.running then
      return
    end
    self.status_line:update()
    self.mark:set_virtual_text(self:get())
    vim.defer_fn(update_spinner, self.update_time)
  end

  vim.defer_fn(update_spinner, self.update_time)
end

function RequestStatus:stop()
  self.running = false
end

return {
  Mark = Mark,
  RequestStatus = RequestStatus,
  nsid = nsid,
}
