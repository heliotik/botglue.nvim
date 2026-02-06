describe("botglue.claude", function()
  local claude

  before_each(function()
    package.loaded["botglue.claude"] = nil
    package.loaded["botglue.config"] = nil
    local config = require("botglue.config")
    config.setup()
    claude = require("botglue.claude")
  end)

  describe("build_command", function()
    it("builds command with all required flags", function()
      local cmd = claude.build_command("simplify this", {
        filepath = "lua/botglue/config.lua",
        start_line = 5,
        end_line = 10,
        filetype = "lua",
        project = "botglue.nvim",
        model = "opus",
      })
      assert.equals("claude", cmd[1])
      assert.is_truthy(vim.tbl_contains(cmd, "-p"))
      assert.is_truthy(vim.tbl_contains(cmd, "--output-format"))
      assert.is_truthy(vim.tbl_contains(cmd, "--verbose"))
      assert.is_truthy(vim.tbl_contains(cmd, "--allowedTools"))
    end)

    it("includes model flag", function()
      local cmd = claude.build_command("test", {
        filepath = "f.lua",
        start_line = 1,
        end_line = 2,
        filetype = "lua",
        project = "p",
        model = "sonnet",
      })
      local model_idx = nil
      for i, v in ipairs(cmd) do
        if v == "--model" then
          model_idx = i
        end
      end
      assert.is_truthy(model_idx)
      assert.equals("sonnet", cmd[model_idx + 1])
    end)

    it("includes max-turns flag from config", function()
      local cmd = claude.build_command("test", {
        filepath = "f.lua",
        start_line = 1,
        end_line = 2,
        filetype = "lua",
        project = "p",
        model = "opus",
      })
      assert.is_truthy(vim.tbl_contains(cmd, "--max-turns"))
    end)
  end)

  describe("build_system_prompt", function()
    it("includes file path and line range", function()
      local prompt = claude.build_system_prompt({
        filepath = "lua/botglue/config.lua",
        start_line = 5,
        end_line = 10,
        filetype = "lua",
        project = "botglue.nvim",
      })
      assert.matches("lua/botglue/config.lua", prompt)
      assert.matches("5", prompt)
      assert.matches("10", prompt)
      assert.matches("lua", prompt)
      assert.matches("botglue.nvim", prompt)
    end)
  end)

  describe("cancel", function()
    it("does not error when no active job", function()
      assert.has_no.errors(function()
        claude.cancel()
      end)
    end)
  end)
end)
