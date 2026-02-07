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
end)
