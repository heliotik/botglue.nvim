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

  describe("RequestStatus", function()
    local bufnr

    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "line one",
        "line two",
      })
    end)

    after_each(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("creates a RequestStatus with title", function()
      local mark = display.Mark.at(bufnr, 1)
      local status = display.RequestStatus.new(250, 3, "Processing", mark)
      assert.is_truthy(status)
      assert.equals(false, status.running)
    end)

    it("returns spinner + title from get()", function()
      local mark = display.Mark.at(bufnr, 1)
      local status = display.RequestStatus.new(250, 3, "Processing", mark)
      local lines = status:get()
      assert.equals(1, #lines)
      assert.matches("Processing", lines[1])
    end)

    it("push adds lines and evicts oldest when over max", function()
      local mark = display.Mark.at(bufnr, 1)
      local status = display.RequestStatus.new(250, 3, "Processing", mark)
      status:push("line A")
      status:push("line B")
      status:push("line C")
      local lines = status:get()
      -- spinner + 2 lines (oldest evicted since max_lines=3 total, 1 for spinner leaves 2)
      assert.equals(3, #lines)
      assert.matches("line B", lines[2])
      assert.matches("line C", lines[3])
    end)

    it("start and stop control running state", function()
      local mark = display.Mark.at(bufnr, 1)
      local status = display.RequestStatus.new(250, 1, "Processing", mark)
      status:start()
      assert.is_true(status.running)
      status:stop()
      assert.is_false(status.running)
    end)
  end)
end)
