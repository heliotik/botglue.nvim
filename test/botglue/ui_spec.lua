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

  describe("_resolve_input", function()
    it("calls on_submit with trimmed text and model", function()
      local submitted_prompt, submitted_model
      ui._resolve_input("  hello world  ", function(p, m)
        submitted_prompt = p
        submitted_model = m
      end, nil, "opus")
      assert.equals("hello world", submitted_prompt)
      assert.equals("opus", submitted_model)
    end)

    it("calls on_cancel for whitespace-only input", function()
      local cancelled = false
      ui._resolve_input("  \n  ", function() end, function()
        cancelled = true
      end, "opus")
      assert.is_true(cancelled)
    end)

    it("does not crash when on_cancel is nil and input is empty", function()
      assert.has_no.errors(function()
        ui._resolve_input("", function() end, nil, "opus")
      end)
    end)

    it("preserves newlines in non-empty multi-line text", function()
      local submitted_prompt
      ui._resolve_input("line1\nline2", function(p)
        submitted_prompt = p
      end, nil, "opus")
      assert.equals("line1\nline2", submitted_prompt)
    end)
  end)

  describe("create_prompt_window", function()
    it("is a function", function()
      assert.equals("function", type(ui.create_prompt_window))
    end)
  end)
end)
