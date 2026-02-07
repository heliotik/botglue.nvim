local config = require("botglue.config")
local operations = require("botglue.operations")
local history = require("botglue.history")
local picker = require("botglue.picker")

local M = {}

function M.setup(opts)
  config.setup(opts)
  history.load()

  if config.options.default_keymaps then
    vim.keymap.set("x", "<leader>pp", function()
      M.run()
    end, { desc = "Botglue: run", silent = true })
  end
end

function M.run()
  -- Exit visual mode to update '< and '> marks for current selection.
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)

  -- Capture selection in original buffer before any UI changes context
  local sel = operations.get_visual_selection()
  if not sel or sel.text == "" then
    vim.notify("botglue: no text selected", vim.log.levels.WARN)
    return
  end

  picker.open(function(prompt, model)
    history.add(prompt, model)
    operations.run(prompt, model, sel)
  end)
end

return M
