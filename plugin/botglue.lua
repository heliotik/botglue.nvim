if vim.g.loaded_botglue then
  return
end
vim.g.loaded_botglue = true

vim.api.nvim_create_user_command("Botglue", function()
  require("botglue").run()
end, { range = true, desc = "Run botglue inline editor" })

vim.api.nvim_create_user_command("BotglueCancel", function()
  require("botglue").cancel()
end, { desc = "Cancel botglue request" })
