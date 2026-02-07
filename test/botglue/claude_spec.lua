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
      assert.is_truthy(vim.tbl_contains(cmd, "--strict-mcp-config"))
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

  describe("_extract_result", function()
    it("returns nil for empty chunks", function()
      assert.is_nil(claude._extract_result({}))
    end)

    it("extracts result from type=result line", function()
      local chunks = {
        vim.json.encode({ type = "system", subtype = "init" }),
        vim.json.encode({
          type = "result",
          subtype = "success",
          result = "the answer",
        }),
      }
      assert.equals("the answer", claude._extract_result(chunks))
    end)

    it("accumulates text from assistant messages", function()
      local chunks = {
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "hello " } },
          },
        }),
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "world" } },
          },
        }),
      }
      assert.equals("hello world", claude._extract_result(chunks))
    end)

    it("prefers type=result over accumulated assistant text", function()
      local chunks = {
        vim.json.encode({
          type = "assistant",
          message = {
            content = { { type = "text", text = "partial" } },
          },
        }),
        vim.json.encode({
          type = "result",
          subtype = "success",
          result = "final result",
        }),
      }
      assert.equals("final result", claude._extract_result(chunks))
    end)

    it("ignores tool_use blocks in assistant messages", function()
      local chunks = {
        vim.json.encode({
          type = "assistant",
          message = {
            content = {
              { type = "text", text = "code here" },
              { type = "tool_use", name = "Read", input = {} },
            },
          },
        }),
      }
      assert.equals("code here", claude._extract_result(chunks))
    end)

    it("ignores system and user events", function()
      local chunks = {
        vim.json.encode({ type = "system", subtype = "init" }),
        vim.json.encode({
          type = "user",
          message = { content = { { type = "tool_result" } } },
        }),
      }
      assert.is_nil(claude._extract_result(chunks))
    end)

    it("ignores invalid JSON chunks", function()
      local chunks = {
        "not json at all",
        vim.json.encode({
          type = "result",
          subtype = "success",
          result = "valid result",
        }),
        "more garbage",
      }
      assert.equals("valid result", claude._extract_result(chunks))
    end)

    it("returns nil when no result found", function()
      local chunks = {
        vim.json.encode({ type = "system", subtype = "init" }),
      }
      assert.is_nil(claude._extract_result(chunks))
    end)
  end)

end)
