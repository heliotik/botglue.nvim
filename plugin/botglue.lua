if vim.g.loaded_botglue then
  return
end
vim.g.loaded_botglue = true

vim.api.nvim_create_user_command("BotglueOptimize", function()
  require("botglue").optimize()
end, { range = true, desc = "Optimize prompt with Claude" })

vim.api.nvim_create_user_command("BotglueExplain", function()
  require("botglue").explain()
end, { range = true, desc = "Explain code with Claude" })

vim.api.nvim_create_user_command("BotglueRefactor", function()
  require("botglue").refactor()
end, { range = true, desc = "Refactor code with Claude" })

vim.api.nvim_create_user_command("BotglueTranslate", function()
  require("botglue").translate()
end, { range = true, desc = "Translate text with Claude" })
