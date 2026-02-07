# botglue.nvim

Neovim plugin for AI-assisted inline code editing via Claude Code CLI. Select text, describe what you want, get results — all without leaving your code flow.

## Requirements

- Neovim 0.10+
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
  model = "opus",                        -- default model
  models = { "opus", "sonnet", "haiku" }, -- available for cycling
  default_keymaps = true,               -- register <leader>pp
  timeout = 300,                         -- seconds (5 min), auto-cancel
  max_turns = 3,                         -- Claude tool-use turns limit
  ai_stdout_rows = 5,                   -- lines of Claude activity in top extmark
})
```

## Usage

### Keymaps (visual mode)

| Keymap | Command | Action |
|--------|---------|--------|
| `<leader>pp` | `:Botglue` | Open three-panel UI: history + prompt editor |

### Workflow

1. Select code in visual mode (`v`, `V`, or `<C-v>`)
2. Press `<leader>pp`
3. Three-panel UI opens: filter, history list (sorted by frequency), prompt editor
4. Browse history with `j`/`k`, press `/` to filter, or `Tab` to prompt editor
5. `Enter` on a history item populates the prompt editor for editing
6. `Ctrl+S` submits — from history list (quick submit) or from prompt editor. `Enter` in normal mode also submits from prompt editor
7. Inline progress extmarks appear around selection, result replaces it

### Controls

**History list (Panel 2):**
- `j`/`k` — navigate, preview shown in prompt editor
- `Enter` — select and move to prompt editor
- `Ctrl+S` — quick submit without editing
- `/` — open filter
- `Tab` — move to prompt editor
- `Esc`/`q` — close

**Filter (Panel 1):**
- Type — fuzzy filter history list
- `Ctrl+J`/`Ctrl+K` — navigate list without leaving filter
- `Enter` — select top match, move to prompt editor
- `Esc` — clear filter, return to list
- `Tab` — move to prompt editor

**Prompt editor (Panel 3):**
- `Enter` — new line (insert mode) / submit (normal mode)
- `Ctrl+S` — submit prompt (any mode)
- `Shift+Tab` — cycle model (opus → sonnet → haiku)
- `Tab` — return to history list
- `q` / `Esc` — close (normal mode)

### Inline Progress Display

While processing, extmarks appear above and below your selection showing a spinner and Claude's activity (tool calls). The selection remains untouched until the result arrives.

## Custom Keymaps

If you disable default keymaps:

```lua
require("botglue").setup({ default_keymaps = false })

vim.keymap.set("x", "<leader>pp", require("botglue").run, { desc = "Botglue: run" })
```

## Philosophy

AI as a tool for precise inline editing, not an autonomous agent. Inspired by [ThePrimeagen/99](https://github.com/ThePrimeagen/99).

## License

MIT
