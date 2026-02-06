describe("botglue.history", function()
  local history
  local test_path

  before_each(function()
    package.loaded["botglue.history"] = nil
    history = require("botglue.history")
    test_path = vim.fn.tempname() .. "/botglue-test/history.json"
    history._path = test_path
  end)

  after_each(function()
    pcall(os.remove, test_path)
  end)

  it("starts with empty history", function()
    assert.same({}, history.get_sorted())
  end)

  it("adds a new entry", function()
    history.add("simplify this", "opus")
    local entries = history.get_sorted()
    assert.equals(1, #entries)
    assert.equals("simplify this", entries[1].prompt)
    assert.equals("opus", entries[1].model)
    assert.equals(1, entries[1].count)
  end)

  it("increments count for duplicate prompt", function()
    history.add("simplify this", "opus")
    history.add("simplify this", "opus")
    local entries = history.get_sorted()
    assert.equals(1, #entries)
    assert.equals(2, entries[1].count)
  end)

  it("updates model when reusing prompt with different model", function()
    history.add("simplify this", "opus")
    history.add("simplify this", "sonnet")
    local entries = history.get_sorted()
    assert.equals(1, #entries)
    assert.equals("sonnet", entries[1].model)
  end)

  it("sorts by count descending", function()
    history.add("rare prompt", "opus")
    history.add("frequent prompt", "opus")
    history.add("frequent prompt", "opus")
    history.add("frequent prompt", "opus")
    local entries = history.get_sorted()
    assert.equals("frequent prompt", entries[1].prompt)
    assert.equals("rare prompt", entries[2].prompt)
  end)

  it("saves and loads from disk", function()
    history.add("test prompt", "haiku")
    history.save()

    -- Reset in-memory state
    package.loaded["botglue.history"] = nil
    history = require("botglue.history")
    history._path = test_path
    history.load()

    local entries = history.get_sorted()
    assert.equals(1, #entries)
    assert.equals("test prompt", entries[1].prompt)
  end)
end)
