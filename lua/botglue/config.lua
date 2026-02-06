local M = {}

M.defaults = {
  model = "opus",
  models = { "opus", "sonnet", "haiku" },
  default_keymaps = true,
  timeout = 300,
  max_turns = 3,
  ai_stdout_rows = 5,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
