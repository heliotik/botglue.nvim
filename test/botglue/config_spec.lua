describe("botglue.config", function()
  local config

  before_each(function()
    package.loaded["botglue.config"] = nil
    config = require("botglue.config")
  end)

  describe("defaults", function()
    it("has model set to opus", function()
      assert.equals("opus", config.defaults.model)
    end)

    it("has default_keymaps set to true", function()
      assert.is_true(config.defaults.default_keymaps)
    end)
  end)

  describe("setup", function()
    it("uses defaults when no options provided", function()
      config.setup()
      assert.equals("opus", config.options.model)
      assert.is_true(config.options.default_keymaps)
    end)

    it("merges user options with defaults", function()
      config.setup({ model = "sonnet" })
      assert.equals("sonnet", config.options.model)
      assert.is_true(config.options.default_keymaps)
    end)

    it("can disable default keymaps", function()
      config.setup({ default_keymaps = false })
      assert.is_false(config.options.default_keymaps)
    end)
  end)

  describe("new v0.2.0 defaults", function()
    it("has models list with opus first", function()
      assert.same({ "opus", "sonnet", "haiku" }, config.defaults.models)
    end)

    it("has timeout set to 300", function()
      assert.equals(300, config.defaults.timeout)
    end)

    it("has max_turns set to 3", function()
      assert.equals(3, config.defaults.max_turns)
    end)

    it("has ai_stdout_rows set to 5", function()
      assert.equals(5, config.defaults.ai_stdout_rows)
    end)
  end)
end)
