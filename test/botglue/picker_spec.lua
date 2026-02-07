describe("botglue.picker", function()
  local picker

  before_each(function()
    package.loaded["botglue.picker"] = nil
    package.loaded["botglue.config"] = nil
    package.loaded["botglue.ui"] = nil
    package.loaded["botglue.history"] = nil

    local config = require("botglue.config")
    config.setup()

    -- Mock history to avoid file I/O
    package.loaded["botglue.history"] = {
      get_sorted = function()
        return {}
      end,
    }

    picker = require("botglue.picker")
  end)

  describe("module structure", function()
    it("exports open function", function()
      assert.is_function(picker.open)
    end)

    it("exports _open_prompt_only function", function()
      assert.is_function(picker._open_prompt_only)
    end)

    it("exports _open_full function", function()
      assert.is_function(picker._open_full)
    end)
  end)

  describe("_make_divider", function()
    it("pads label with ─ to exact width", function()
      local line = picker._make_divider("Recent prompts", 30)
      assert.equals(30, vim.fn.strdisplaywidth(line))
      assert.truthy(vim.startswith(line, "── Recent prompts "))
      -- Remainder is only ─ characters
      local suffix = line:sub(#"── Recent prompts " + 1)
      assert.equals(string.rep("─", vim.fn.strchars(suffix)), suffix)
    end)

    it("truncates label if wider than width", function()
      local line = picker._make_divider("Very long label text here", 10)
      assert.equals(10, vim.fn.strdisplaywidth(line))
    end)

    it("works with empty label", function()
      local line = picker._make_divider("", 20)
      assert.equals(20, vim.fn.strdisplaywidth(line))
      assert.equals(string.rep("─", vim.fn.strchars(line)), line)
    end)
  end)

  describe("_truncate_prompt", function()
    it("returns text unchanged if it fits", function()
      assert.equals("hello", picker._truncate_prompt("hello", 20))
    end)

    it("truncates and adds ellipsis when too long", function()
      local result = picker._truncate_prompt("hello world", 8)
      assert.equals("hello w…", result)
      assert.equals(8, vim.fn.strdisplaywidth(result))
    end)

    it("handles UTF-8 characters correctly", function()
      local result = picker._truncate_prompt("привет мир", 8)
      assert.equals(8, vim.fn.strdisplaywidth(result))
      assert.truthy(result:match("…$"))
    end)

    it("handles CJK double-width characters", function()
      local result = picker._truncate_prompt("你好世界test", 9)
      assert.equals(9, vim.fn.strdisplaywidth(result))
    end)
  end)
end)
