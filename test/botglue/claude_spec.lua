describe("botglue.claude", function()
  local claude

  before_each(function()
    package.loaded["botglue.claude"] = nil
    package.loaded["botglue.config"] = nil
    claude = require("botglue.claude")
  end)

  describe("build_prompt", function()
    it("includes context for optimize operation", function()
      local prompt = claude.build_prompt("optimize", "test text", "", {
        project = "myproject",
        file = "init.lua",
        filetype = "lua",
      })
      assert.matches("myproject", prompt)
      assert.matches("init.lua", prompt)
      assert.matches("lua", prompt)
      assert.matches("test text", prompt)
    end)

    it("includes context for refactor operation", function()
      local prompt = claude.build_prompt("refactor", "local x = 1", "", {
        project = "proj",
        file = "main.lua",
        filetype = "lua",
      })
      assert.matches("proj", prompt)
      assert.matches("local x = 1", prompt)
    end)

    it("does not include context for translate operation", function()
      local prompt = claude.build_prompt("translate", "hello world", "", {
        project = "proj",
        file = "main.lua",
        filetype = "lua",
      })
      assert.matches("hello world", prompt)
      assert.not_matches("Проект:", prompt)
    end)

    it("appends user input when provided", function()
      local prompt = claude.build_prompt("optimize", "text", "be concise", {
        project = "p",
        file = "f",
        filetype = "lua",
      })
      assert.matches("be concise", prompt)
      assert.matches("Дополнительные указания", prompt)
    end)
  end)
end)
