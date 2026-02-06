local M = {}

M._entries = {}
M._path = nil

--- Get the history file path.
--- @return string
function M._get_path()
  if M._path then
    return M._path
  end
  local data_dir = vim.fn.stdpath("data")
  return data_dir .. "/botglue/history.json"
end

function M.load()
  local path = M._get_path()
  local f = io.open(path, "r")
  if not f then
    M._entries = {}
    return
  end
  local content = f:read("*a")
  f:close()
  local ok, parsed = pcall(vim.json.decode, content)
  if ok and type(parsed) == "table" then
    M._entries = parsed
  else
    M._entries = {}
  end
end

function M.save()
  local path = M._get_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  local f = io.open(path, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(M._entries))
  f:close()
end

--- Add or update a history entry.
--- @param prompt string
--- @param model string
function M.add(prompt, model)
  for _, entry in ipairs(M._entries) do
    if entry.prompt == prompt then
      entry.count = entry.count + 1
      entry.model = model
      entry.last_used = os.time()
      M.save()
      return
    end
  end
  table.insert(M._entries, {
    prompt = prompt,
    model = model,
    count = 1,
    last_used = os.time(),
  })
  M.save()
end

--- Return entries sorted by count descending.
--- @return table[]
function M.get_sorted()
  local sorted = vim.deepcopy(M._entries)
  table.sort(sorted, function(a, b)
    return a.count > b.count
  end)
  return sorted
end

return M
