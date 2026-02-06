describe("botglue.display", function()
  local display

  before_each(function()
    package.loaded["botglue.display"] = nil
    display = require("botglue.display")
  end)

  describe("Mark", function()
    local bufnr

    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "line one",
        "line two",
        "line three",
        "line four",
      })
    end)

    after_each(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("creates a mark above a line", function()
      local mark = display.Mark.above(bufnr, 2)
      assert.is_truthy(mark)
      assert.is_true(mark:is_valid())
    end)

    it("creates a mark at a line", function()
      local mark = display.Mark.at(bufnr, 3)
      assert.is_truthy(mark)
      assert.is_true(mark:is_valid())
    end)

    it("sets virtual text on mark", function()
      local mark = display.Mark.at(bufnr, 2)
      mark:set_virtual_text({ "spinner line", "status line" })
      assert.is_true(mark:is_valid())
    end)

    it("deletes a mark", function()
      local mark = display.Mark.at(bufnr, 2)
      assert.is_true(mark:is_valid())
      mark:delete()
      assert.is_false(mark:is_valid())
    end)
  end)
end)
