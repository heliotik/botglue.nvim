describe("botglue.ui", function()
  local ui

  before_each(function()
    package.loaded["botglue.ui"] = nil
    package.loaded["botglue.config"] = nil
    local config = require("botglue.config")
    config.setup()
    ui = require("botglue.ui")
  end)

  describe("_next_model", function()
    it("cycles opus to sonnet", function()
      assert.equals("sonnet", ui._next_model("opus", { "opus", "sonnet", "haiku" }))
    end)

    it("cycles haiku to opus (wraps around)", function()
      assert.equals("opus", ui._next_model("haiku", { "opus", "sonnet", "haiku" }))
    end)

    it("returns same model for single-element list", function()
      assert.equals("opus", ui._next_model("opus", { "opus" }))
    end)

    it("defaults to second element when model not in list", function()
      assert.equals("sonnet", ui._next_model("unknown", { "opus", "sonnet", "haiku" }))
    end)
  end)
end)
