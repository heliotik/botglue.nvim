# botglue.nvim Plugin Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform prototype `prompt-optimizer.lua` into modular Neovim plugin with quality infrastructure.

**Architecture:** Split monolithic file into 5 Lua modules (config, ui, claude, operations, init) + plugin autoload. Add linting, formatting, tests, and CI.

**Tech Stack:** Lua, Neovim API, plenary.nvim (tests), luacheck, stylua, GitHub Actions

---

## Task 1: Create Directory Structure

**Files:**
- Create: `lua/botglue/` directory
- Create: `plugin/` directory
- Create: `test/botglue/` directory
- Create: `.github/workflows/` directory

**Step 1: Create all directories**

Run:
```bash
mkdir -p lua/botglue plugin test/botglue .github/workflows
```

**Step 2: Verify structure**

Run:
```bash
ls -la lua/botglue plugin test/botglue .github/workflows
```

Expected: All directories exist

**Step 3: Commit**

```bash
git add -A && git commit -m "chore: create plugin directory structure"
```

---

## Task 2: Create config.lua Module

**Files:**
- Create: `lua/botglue/config.lua`
- Test: `test/botglue/config_spec.lua`

**Step 1: Write the test file**

Create `test/botglue/config_spec.lua`:

```lua
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
end)
```

**Step 2: Write the config module**

Create `lua/botglue/config.lua`:

```lua
local M = {}

M.defaults = {
  model = "opus",
  default_keymaps = true,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
```

**Step 3: Commit**

```bash
git add lua/botglue/config.lua test/botglue/config_spec.lua
git commit -m "feat(config): add configuration module with tests"
```

---

## Task 3: Create ui.lua Module

**Files:**
- Create: `lua/botglue/ui.lua`

**Step 1: Create the UI module**

Create `lua/botglue/ui.lua`:

```lua
local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
local spinner_timer = nil

function M.start_spinner(message)
  spinner_index = 1
  spinner_timer = vim.uv.new_timer()
  spinner_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      spinner_index = (spinner_index % #spinner_frames) + 1
      vim.api.nvim_echo({ { spinner_frames[spinner_index] .. " " .. message, "Comment" } }, false, {})
    end)
  )
end

function M.stop_spinner(final_message, level)
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  vim.api.nvim_echo({ { "", "" } }, false, {})
  if final_message then
    vim.notify(final_message, level or vim.log.levels.INFO)
  end
end

function M.capture_input(title, on_submit, on_cancel)
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 2 / 3)
  local height = math.floor(ui.height / 4)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.wo[win].wrap = true

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = vim.trim(table.concat(lines, "\n"))
    close_window()
    on_submit(input)
  end

  local function newline()
    local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
    local line = vim.api.nvim_buf_get_lines(buf, cursor_row - 1, cursor_row, false)[1]
    local before = line:sub(1, cursor_col)
    local after = line:sub(cursor_col + 1)
    vim.api.nvim_buf_set_lines(buf, cursor_row - 1, cursor_row, false, { before, after })
    vim.api.nvim_win_set_cursor(win, { cursor_row + 1, 0 })
  end

  local function cancel()
    close_window()
    if on_cancel then
      on_cancel()
    end
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<S-CR>", newline, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })

  vim.cmd("startinsert")
end

function M.show_result_window(text, title)
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 2 / 3)
  local height = math.floor(ui.height / 3)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title or " botglue ",
    title_pos = "center",
  })

  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.wo[win].wrap = true
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close_window, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_window, { buffer = buf, nowait = true })
end

return M
```

**Step 2: Commit**

```bash
git add lua/botglue/ui.lua
git commit -m "feat(ui): add UI module with spinner and floating windows"
```

---

## Task 4: Create claude.lua Module

**Files:**
- Create: `lua/botglue/claude.lua`
- Test: `test/botglue/claude_spec.lua`

**Step 1: Write the test file**

Create `test/botglue/claude_spec.lua`:

```lua
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
```

**Step 2: Write the claude module**

Create `lua/botglue/claude.lua`:

```lua
local config = require("botglue.config")

local M = {}

M.PROMPTS = {
  optimize = [[
Оптимизируй промт ниже для получения лучшего результата.
Исправь ошибки. Добавь контекста к задаче.
Верни ТОЛЬКО улучшенный текст промта, без пояснений.

Контекст: Проект: %s | Файл: %s | Тип: %s

<prompt>
%s
</prompt>]],

  explain = [[
Объясни этот код на русском языке.
Опиши что он делает, зачем нужен, какие есть нюансы.
Будь кратким но информативным.

Контекст: Проект: %s | Файл: %s | Тип: %s

<code>
%s
</code>]],

  refactor = [[
Перепиши этот код чище и читаемее.
Сохрани функциональность. Улучши именование, структуру, убери дублирование.
Верни ТОЛЬКО код, без пояснений и markdown-блоков.

Контекст: Проект: %s | Файл: %s | Тип: %s

<code>
%s
</code>]],

  translate = [[
Определи язык текста и переведи на другой язык:
- Если текст на русском → переведи на английский
- Если текст на английском → переведи на русский
- Для других языков → переведи на русский

Верни ТОЛЬКО перевод, без пояснений.

<text>
%s
</text>]],
}

function M.build_prompt(operation, selected_text, user_input, context)
  local template = M.PROMPTS[operation]
  local prompt

  if operation == "translate" then
    prompt = string.format(template, selected_text)
  else
    prompt = string.format(template, context.project, context.file, context.filetype, selected_text)
  end

  if user_input and user_input ~= "" then
    prompt = prompt .. "\n\nДополнительные указания от пользователя:\n" .. user_input
  end

  return prompt
end

function M.call(prompt, callback)
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart({
    "claude",
    "-p",
    "-",
    "--output-format",
    "text",
    "--model",
    config.options.model,
  }, {
    stdin = "pipe",
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
    on_exit = function(_, code)
      if code == 0 then
        local result = table.concat(stdout_data, "\n")
        result = result:gsub("^%s+", ""):gsub("%s+$", "")
        callback(nil, result)
      else
        local err = table.concat(stderr_data, "\n")
        callback("Claude Code failed: " .. err, nil)
      end
    end,
  })

  if job_id <= 0 then
    callback("Failed to start Claude process", nil)
    return
  end

  vim.fn.chansend(job_id, prompt)
  vim.fn.chanclose(job_id, "stdin")
end

return M
```

**Step 3: Commit**

```bash
git add lua/botglue/claude.lua test/botglue/claude_spec.lua
git commit -m "feat(claude): add Claude CLI integration module with tests"
```

---

## Task 5: Create operations.lua Module

**Files:**
- Create: `lua/botglue/operations.lua`

**Step 1: Create the operations module**

Create `lua/botglue/operations.lua`:

```lua
local ui = require("botglue.ui")
local claude = require("botglue.claude")

local M = {}

M.ResultMode = {
  REPLACE = "replace",
  WINDOW = "window",
}

function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 then
    return nil
  end

  local is_linewise = end_pos[3] >= 2147483647 or start_pos[3] >= 2147483647

  local start_col, end_col

  if is_linewise then
    start_col = 0
    local end_line_content = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
    end_col = end_line_content and #end_line_content or 0
  else
    start_col = start_pos[3] - 1
    end_col = end_pos[3]

    local end_line_content = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
    if end_line_content then
      end_col = math.min(end_col, #end_line_content)
    end
  end

  local ok, lines = pcall(vim.api.nvim_buf_get_text, 0, start_line - 1, start_col, end_line - 1, end_col, {})

  if not ok then
    return nil
  end

  return {
    text = table.concat(lines, "\n"),
    bufnr = vim.api.nvim_get_current_buf(),
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
  }
end

function M.replace_selection(sel, new_text)
  local lines = vim.split(new_text, "\n")

  local ok, err =
    pcall(vim.api.nvim_buf_set_text, sel.bufnr, sel.start_line - 1, sel.start_col, sel.end_line - 1, sel.end_col, lines)

  if not ok then
    vim.notify("Failed to replace text: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.get_context()
  local cwd = vim.fn.getcwd()
  return {
    project = vim.fn.fnamemodify(cwd, ":t"),
    file = vim.fn.expand("%:."),
    filetype = vim.bo.filetype,
  }
end

function M.run(opts)
  local sel = M.get_visual_selection()
  if not sel or sel.text == "" then
    vim.notify("Нет выделенного текста", vim.log.levels.WARN)
    return
  end

  ui.capture_input(opts.input_title, function(user_input)
    ui.start_spinner(opts.spinner_msg)

    local context = M.get_context()
    local prompt = claude.build_prompt(opts.operation, sel.text, user_input, context)

    claude.call(prompt, function(err, result)
      vim.schedule(function()
        if err then
          ui.stop_spinner("✗ " .. err, vim.log.levels.ERROR)
          return
        end

        if not result or result == "" then
          ui.stop_spinner("⚠ Пустой ответ от Claude", vim.log.levels.WARN)
          return
        end

        if opts.result_mode == M.ResultMode.REPLACE then
          M.replace_selection(sel, result)
          ui.stop_spinner(opts.success_msg, vim.log.levels.INFO)
        else
          ui.stop_spinner(nil)
          ui.show_result_window(result, opts.window_title)
        end
      end)
    end)
  end)
end

return M
```

**Step 2: Commit**

```bash
git add lua/botglue/operations.lua
git commit -m "feat(operations): add operations module with run logic"
```

---

## Task 6: Create init.lua Module

**Files:**
- Create: `lua/botglue/init.lua`

**Step 1: Create the init module**

Create `lua/botglue/init.lua`:

```lua
local config = require("botglue.config")
local operations = require("botglue.operations")

local M = {}

function M.setup(opts)
  config.setup(opts)

  if config.options.default_keymaps then
    vim.keymap.set("x", "<leader>po", function()
      M.optimize()
    end, { desc = "Botglue: Optimize prompt", silent = true })
    vim.keymap.set("x", "<leader>pe", function()
      M.explain()
    end, { desc = "Botglue: Explain code", silent = true })
    vim.keymap.set("x", "<leader>pr", function()
      M.refactor()
    end, { desc = "Botglue: Refactor code", silent = true })
    vim.keymap.set("x", "<leader>pt", function()
      M.translate()
    end, { desc = "Botglue: Translate text", silent = true })
  end
end

function M.optimize()
  operations.run({
    operation = "optimize",
    result_mode = operations.ResultMode.REPLACE,
    input_title = " Оптимизация промта ",
    spinner_msg = "Оптимизирую промт...",
    success_msg = "✓ Промт оптимизирован!",
  })
end

function M.explain()
  operations.run({
    operation = "explain",
    result_mode = operations.ResultMode.WINDOW,
    input_title = " Объяснение кода ",
    spinner_msg = "Анализирую код...",
    window_title = " Объяснение ",
  })
end

function M.refactor()
  operations.run({
    operation = "refactor",
    result_mode = operations.ResultMode.REPLACE,
    input_title = " Рефакторинг ",
    spinner_msg = "Рефакторю код...",
    success_msg = "✓ Код улучшен!",
  })
end

function M.translate()
  operations.run({
    operation = "translate",
    result_mode = operations.ResultMode.REPLACE,
    input_title = " Перевод ",
    spinner_msg = "Перевожу...",
    success_msg = "✓ Переведено!",
  })
end

return M
```

**Step 2: Commit**

```bash
git add lua/botglue/init.lua
git commit -m "feat(init): add main entry point with setup and public API"
```

---

## Task 7: Create plugin/botglue.lua Autoload

**Files:**
- Create: `plugin/botglue.lua`

**Step 1: Create the plugin autoload file**

Create `plugin/botglue.lua`:

```lua
if vim.g.loaded_botglue then
  return
end
vim.g.loaded_botglue = true

vim.api.nvim_create_user_command("BotglueOptimize", function()
  require("botglue").optimize()
end, { range = true, desc = "Optimize prompt with Claude" })

vim.api.nvim_create_user_command("BotglueExplain", function()
  require("botglue").explain()
end, { range = true, desc = "Explain code with Claude" })

vim.api.nvim_create_user_command("BotglueRefactor", function()
  require("botglue").refactor()
end, { range = true, desc = "Refactor code with Claude" })

vim.api.nvim_create_user_command("BotglueTranslate", function()
  require("botglue").translate()
end, { range = true, desc = "Translate text with Claude" })
```

**Step 2: Commit**

```bash
git add plugin/botglue.lua
git commit -m "feat(plugin): add vim commands autoload"
```

---

## Task 8: Add Quality Infrastructure

**Files:**
- Create: `.stylua.toml`
- Create: `.luacheckrc`
- Create: `Makefile`
- Create: `test/minimal_init.lua`

**Step 1: Create .stylua.toml**

Create `.stylua.toml`:

```toml
column_width = 100
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
```

**Step 2: Create .luacheckrc**

Create `.luacheckrc`:

```lua
std = luajit
cache = true
codes = true
ignore = {
  "211", -- Unused local variable
}
read_globals = { "vim", "describe", "it", "assert", "before_each", "after_each" }
```

**Step 3: Create test/minimal_init.lua**

Create `test/minimal_init.lua`:

```lua
vim.opt.rtp:append(".")
vim.opt.rtp:append("../plenary.nvim")

vim.cmd("runtime plugin/plenary.vim")

vim.o.swapfile = false
vim.bo.swapfile = false
```

**Step 4: Create Makefile**

Create `Makefile`:

```makefile
.PHONY: fmt fmt-check lint test pr-ready

fmt:
	@echo "===> Formatting"
	stylua lua/ plugin/ --config-path=.stylua.toml

fmt-check:
	@echo "===> Checking format"
	stylua lua/ plugin/ --config-path=.stylua.toml --check

lint:
	@echo "===> Linting"
	luacheck lua/ plugin/ --globals vim

test:
	@echo "===> Testing"
	nvim --headless --noplugin -u test/minimal_init.lua \
		-c "PlenaryBustedDirectory test/botglue {minimal_init = 'test/minimal_init.lua'}"

pr-ready: lint test fmt-check
	@echo "===> All checks passed!"
```

**Step 5: Commit**

```bash
git add .stylua.toml .luacheckrc Makefile test/minimal_init.lua
git commit -m "chore: add quality infrastructure (stylua, luacheck, makefile)"
```

---

## Task 9: Add GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

**Step 1: Create CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest

    env:
      NVIM_VERSION: v0.10.0

    steps:
      - uses: actions/checkout@v4

      - name: Install Neovim
        run: |
          wget -q https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz
          tar xzf nvim-linux64.tar.gz
          sudo mv nvim-linux64 /opt/nvim
          sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim

      - name: Install luarocks and luacheck
        run: |
          sudo apt-get update
          sudo apt-get install -y luarocks
          sudo luarocks install luacheck

      - name: Install stylua
        run: |
          wget -qO stylua.zip https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip
          unzip stylua.zip
          chmod +x stylua
          sudo mv stylua /usr/local/bin/

      - name: Install plenary.nvim
        run: |
          git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git ../plenary.nvim

      - name: Run checks
        run: make pr-ready
```

**Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow"
```

---

## Task 10: Run Quality Checks and Fix Issues

**Step 1: Format code**

Run:
```bash
make fmt
```

**Step 2: Run linter**

Run:
```bash
make lint
```

Expected: No errors. If errors, fix them in the respective files.

**Step 3: Run tests**

Run:
```bash
make test
```

Expected: All tests pass.

**Step 4: Run full check**

Run:
```bash
make pr-ready
```

Expected: All checks pass.

**Step 5: Commit any fixes**

```bash
git add -A && git commit -m "style: fix linting and formatting issues"
```

---

## Task 11: Update Documentation

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Step 1: Update README.md**

Replace content of `README.md` with:

```markdown
# botglue.nvim

Neovim plugin for AI-assisted text processing via Claude Code CLI. Select text → enter instructions → get results.

## Requirements

- Neovim 0.7+
- [Claude Code CLI](https://claude.ai/code) installed and available in PATH

## Installation

### lazy.nvim

```lua
{
  "heliotik/botglue.nvim",
  config = function()
    require("botglue").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "heliotik/botglue.nvim",
  config = function()
    require("botglue").setup()
  end,
}
```

## Configuration

```lua
require("botglue").setup({
  model = "opus",           -- Claude model to use
  default_keymaps = true,   -- Set to false to disable default keymaps
})
```

## Usage

All commands work in visual mode:

| Keymap | Command | Result |
|--------|---------|--------|
| `<leader>po` | `:BotglueOptimize` | Replaces selection |
| `<leader>pe` | `:BotglueExplain` | Shows in window |
| `<leader>pr` | `:BotglueRefactor` | Replaces selection |
| `<leader>pt` | `:BotglueTranslate` | Replaces selection |

### Workflow

1. Select text in visual mode (`v`, `V`, or `<C-v>`)
2. Press the keymap or run the command
3. Enter additional instructions in the popup (optional)
4. Press `Enter` to submit or `q`/`Esc` to cancel
5. Result either replaces selection or opens in a window

### Input Window Controls

- `Enter` — submit
- `Shift+Enter` — new line
- `q` or `Esc` — cancel

## Custom Keymaps

If you disable default keymaps, set your own:

```lua
require("botglue").setup({ default_keymaps = false })

vim.keymap.set("x", "<leader>bo", require("botglue").optimize, { desc = "Optimize prompt" })
vim.keymap.set("x", "<leader>be", require("botglue").explain, { desc = "Explain code" })
vim.keymap.set("x", "<leader>br", require("botglue").refactor, { desc = "Refactor code" })
vim.keymap.set("x", "<leader>bt", require("botglue").translate, { desc = "Translate text" })
```

## Philosophy

AI as a tool for precise operations, not an autonomous agent. Inspired by [ThePrimeagen/99](https://github.com/ThePrimeagen/99).

## License

MIT
```

**Step 2: Update CLAUDE.md**

Replace content of `CLAUDE.md` with:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

botglue.nvim is a Neovim plugin for AI-assisted text processing via Claude Code CLI. Users select text in visual mode, invoke a command, optionally provide instructions in a floating input window, and receive processed results.

## Development Commands

```bash
make fmt        # Format code with stylua
make lint       # Run luacheck
make test       # Run tests with plenary
make pr-ready   # Run all checks (lint + test + format check)
```

## Architecture

Modular structure in `lua/botglue/`:

- `init.lua` — Entry point, `setup()`, public API
- `config.lua` — Configuration defaults and merge logic
- `operations.lua` — Visual selection handling, `run()` orchestration
- `ui.lua` — Floating windows (input, result), spinner
- `claude.lua` — CLI invocation, prompt templates

### Data Flow

```
Visual selection → operations.run() → ui.capture_input()
    → claude.build_prompt() → claude.call() async
    → Result: operations.replace_selection() OR ui.show_result_window()
```

## Testing

Tests use plenary.nvim and are located in `test/botglue/`:

```bash
# Run all tests
make test

# Run specific test file
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/botglue/config_spec.lua"
```

## Code Style

- Formatter: stylua (see `.stylua.toml`)
- Linter: luacheck (see `.luacheckrc`)
- 2-space indentation, 100 char line width
```

**Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: update README and CLAUDE.md for new structure"
```

---

## Task 12: Delete Old Files and Tag Release

**Files:**
- Delete: `prompt-optimizer.lua`
- Delete: `prompt-optimizer-mcp.json`

**Step 1: Delete old files**

Run:
```bash
rm prompt-optimizer.lua prompt-optimizer-mcp.json
```

**Step 2: Verify plugin loads correctly**

Run:
```bash
nvim --headless -u test/minimal_init.lua -c "lua require('botglue').setup()" -c "q"
```

Expected: No errors.

**Step 3: Run final checks**

Run:
```bash
make pr-ready
```

Expected: All checks pass.

**Step 4: Commit deletion**

```bash
git add -A
git commit -m "chore: remove old prototype files"
```

**Step 5: Tag release**

```bash
git tag v0.1.0
```

---

## Summary

Total: 12 tasks

1. Create directory structure
2. Create config.lua module (with tests)
3. Create ui.lua module
4. Create claude.lua module (with tests)
5. Create operations.lua module
6. Create init.lua module
7. Create plugin/botglue.lua autoload
8. Add quality infrastructure
9. Add GitHub Actions CI
10. Run quality checks and fix issues
11. Update documentation
12. Delete old files and tag release
