describe("botglue.operations", function()
  local operations

  before_each(function()
    package.loaded["botglue.operations"] = nil
    package.loaded["botglue.config"] = nil
    package.loaded["botglue.claude"] = nil
    package.loaded["botglue.display"] = nil

    local config = require("botglue.config")
    config.setup()

    operations = require("botglue.operations")
  end)

  describe("replace_selection", function()
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
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end)

    it("replaces single-line text", function()
      local sel = {
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 2,
        end_col = 8,
      }
      operations.replace_selection(sel, "replaced")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("replaced", lines[2])
      assert.equals(4, #lines)
    end)

    it("replaces with multi-line text", function()
      local sel = {
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 2,
        end_col = 8,
      }
      operations.replace_selection(sel, "new line A\nnew line B\nnew line C")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(6, #lines)
      assert.equals("new line A", lines[2])
      assert.equals("new line B", lines[3])
      assert.equals("new line C", lines[4])
    end)

    it("shrinks buffer when replacing multi-line with single-line", function()
      local sel = {
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 3,
        end_col = 10,
      }
      operations.replace_selection(sel, "merged")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(3, #lines)
      assert.equals("merged", lines[2])
    end)

    it("does not crash on invalid buffer", function()
      local dead_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_delete(dead_buf, { force = true })
      local sel = {
        bufnr = dead_buf,
        start_line = 1,
        start_col = 0,
        end_line = 1,
        end_col = 5,
      }
      assert.has_no.errors(function()
        operations.replace_selection(sel, "nope")
      end)
    end)
  end)

  describe("get_visual_selection", function()
    local bufnr

    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "line one",
        "line two",
        "line three",
        "line four",
      })
      -- Make it the current buffer so getpos("'<") works
      vim.api.nvim_set_current_buf(bufnr)
    end)

    after_each(function()
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end)

    it("returns nil when no marks set", function()
      assert.is_nil(operations.get_visual_selection(bufnr))
    end)

    it("extracts charwise single-line selection", function()
      vim.api.nvim_buf_set_mark(bufnr, "<", 2, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, ">", 2, 3, {})
      local sel = operations.get_visual_selection(bufnr)
      assert.is_truthy(sel)
      assert.equals("line", sel.text)
      assert.equals(bufnr, sel.bufnr)
      assert.equals(2, sel.start_line)
      assert.equals(2, sel.end_line)
    end)

    it("extracts charwise multi-line selection", function()
      vim.api.nvim_buf_set_mark(bufnr, "<", 2, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, ">", 3, 9, {})
      local sel = operations.get_visual_selection(bufnr)
      assert.is_truthy(sel)
      assert.equals("line two\nline three", sel.text)
      assert.equals(2, sel.start_line)
      assert.equals(3, sel.end_line)
    end)

    it("handles linewise selection via maxcol", function()
      vim.api.nvim_buf_set_mark(bufnr, "<", 2, 2147483646, {})
      vim.api.nvim_buf_set_mark(bufnr, ">", 3, 2147483646, {})
      local sel = operations.get_visual_selection(bufnr)
      assert.is_truthy(sel)
      assert.equals(0, sel.start_col)
      assert.equals(2, sel.start_line)
      assert.equals(3, sel.end_line)
    end)

    it("uses explicit bufnr parameter", function()
      -- bufnr is already the current buffer (set in before_each).
      -- Set marks on it, then pass bufnr explicitly to verify
      -- the returned selection references the correct buffer.
      vim.api.nvim_buf_set_mark(bufnr, "<", 1, 0, {})
      vim.api.nvim_buf_set_mark(bufnr, ">", 1, 7, {})
      local sel = operations.get_visual_selection(bufnr)
      assert.is_truthy(sel)
      assert.equals(bufnr, sel.bufnr)
      assert.equals("line one", sel.text)
      assert.equals(1, sel.start_line)
      assert.equals(1, sel.end_line)
    end)
  end)

  describe("run", function()
    local bufnr
    local mock_claude
    local mock_marks_deleted

    before_each(function()
      -- Reset all modules for clean mock injection
      package.loaded["botglue.operations"] = nil
      package.loaded["botglue.config"] = nil
      package.loaded["botglue.claude"] = nil
      package.loaded["botglue.display"] = nil

      local config = require("botglue.config")
      config.setup()

      -- Mock claude
      mock_claude = {
        start = function(prompt, ctx, observer)
          mock_claude._last_prompt = prompt
          mock_claude._last_ctx = ctx
          mock_claude._last_observer = observer
        end,
        cancel = function()
          mock_claude._cancelled = true
        end,
        _cancelled = false,
      }
      package.loaded["botglue.claude"] = mock_claude

      -- Mock display — minimal stubs that track deletion
      mock_marks_deleted = 0
      local mock_mark = {
        set_virtual_text = function() end,
        delete = function()
          mock_marks_deleted = mock_marks_deleted + 1
        end,
        is_valid = function()
          return true
        end,
      }
      package.loaded["botglue.display"] = {
        Mark = {
          above = function()
            return mock_mark
          end,
          at = function()
            return mock_mark
          end,
        },
        RequestStatus = {
          new = function(_, _, _, _)
            return {
              start = function() end,
              stop = function() end,
              push = function() end,
              get = function()
                return {}
              end,
            }
          end,
        },
      }

      operations = require("botglue.operations")

      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "line one",
        "line two",
        "line three",
      })
    end)

    after_each(function()
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end)

    it("returns early on nil selection", function()
      operations.run("test prompt", "opus", nil)
      assert.is_nil(mock_claude._last_observer)
    end)

    it("returns early on empty text", function()
      operations.run("test prompt", "opus", { text = "", bufnr = bufnr })
      assert.is_nil(mock_claude._last_observer)
    end)

    it("passes correct context to claude.start", function()
      local sel = {
        text = "line two",
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 2,
        end_col = 8,
      }
      operations.run("simplify", "sonnet", sel)
      assert.is_truthy(mock_claude._last_ctx)
      assert.equals(2, mock_claude._last_ctx.start_line)
      assert.equals(2, mock_claude._last_ctx.end_line)
      assert.equals("sonnet", mock_claude._last_ctx.model)
      assert.equals("simplify", mock_claude._last_prompt)
    end)

    it("replaces selection on successful completion", function()
      local sel = {
        text = "line two",
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 2,
        end_col = 8,
      }
      operations.run("test", "opus", sel)
      -- Simulate successful completion
      mock_claude._last_observer.on_complete(nil, "replaced text")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("replaced text", lines[2])
    end)

    it("does not replace selection on error", function()
      local sel = {
        text = "line two",
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 2,
        end_col = 8,
      }
      operations.run("test", "opus", sel)
      mock_claude._last_observer.on_complete("timeout", nil)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("line two", lines[2])
    end)

    it("cleans up marks on completion", function()
      local sel = {
        text = "line two",
        bufnr = bufnr,
        start_line = 2,
        start_col = 0,
        end_line = 2,
        end_col = 8,
      }
      operations.run("test", "opus", sel)
      mock_claude._last_observer.on_complete(nil, "done")
      assert.equals(2, mock_marks_deleted)
    end)
  end)
end)
