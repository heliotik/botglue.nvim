local config = require("botglue.config")
local operations = require("botglue.operations")

local M = {}

function M.setup(opts)
  config.setup(opts)

  if config.options.default_keymaps then
    vim.keymap.set("x", "<leader>po", function()
      M.optimize()
    end, { desc = "Botglue: Optimize prompt", silent = true })
    vim.keymap.set("x", "<leader>pe", function()
      M.explain()
    end, { desc = "Botglue: Explain code", silent = true })
    vim.keymap.set("x", "<leader>pr", function()
      M.refactor()
    end, { desc = "Botglue: Refactor code", silent = true })
    vim.keymap.set("x", "<leader>pt", function()
      M.translate()
    end, { desc = "Botglue: Translate text", silent = true })
  end
end

function M.optimize()
  operations.run({
    operation = "optimize",
    result_mode = operations.ResultMode.REPLACE,
    input_title = " Оптимизация промта ",
    spinner_msg = "Оптимизирую промт...",
    success_msg = "✓ Промт оптимизирован!",
  })
end

function M.explain()
  operations.run({
    operation = "explain",
    result_mode = operations.ResultMode.WINDOW,
    input_title = " Объяснение кода ",
    spinner_msg = "Анализирую код...",
    window_title = " Объяснение ",
  })
end

function M.refactor()
  operations.run({
    operation = "refactor",
    result_mode = operations.ResultMode.REPLACE,
    input_title = " Рефакторинг ",
    spinner_msg = "Рефакторю код...",
    success_msg = "✓ Код улучшен!",
  })
end

function M.translate()
  operations.run({
    operation = "translate",
    result_mode = operations.ResultMode.REPLACE,
    input_title = " Перевод ",
    spinner_msg = "Перевожу...",
    success_msg = "✓ Переведено!",
  })
end

return M
