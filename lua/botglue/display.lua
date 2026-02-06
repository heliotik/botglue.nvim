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

return {
  Mark = Mark,
  nsid = nsid,
}
