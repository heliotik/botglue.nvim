local config = require("botglue.config")
local operations = require("botglue.operations")
local history = require("botglue.history")
local picker = require("botglue.picker")
local ui = require("botglue.ui")

local M = {}

function M.setup(opts)
  config.setup(opts)
  history.load()

  if config.options.default_keymaps then
    vim.keymap.set("x", "<leader>pp", function()
      M.run()
    end, { desc = "Botglue: run", silent = true })
    vim.keymap.set("x", "<leader>ps", function()
      M.cancel()
    end, { desc = "Botglue: cancel", silent = true })
  end
end

function M.run()
  -- Capture selection in original buffer before any UI changes context
  local sel = operations.get_visual_selection()
  if not sel or sel.text == "" then
    vim.notify("botglue: no text selected", vim.log.levels.WARN)
    return
  end

  picker.open(function(entry)
    if not entry then
      -- Empty selection, open blank input
      ui.capture_input({}, function(prompt, model)
        history.add(prompt, model)
        operations.run(prompt, model, sel)
      end)
      return
    end

    ui.capture_input({
      prompt = entry.prompt,
      model = entry.model,
    }, function(prompt, model)
      history.add(prompt, model)
      operations.run(prompt, model, sel)
    end)
  end)
end

function M.cancel()
  operations.cancel()
end

return M
