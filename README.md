# botglue.nvim

Neovim plugin for AI-assisted inline code editing via Claude Code CLI. Select text, describe what you want, get results — all without leaving your code flow.

## Requirements

- Neovim 0.10+
- [Claude Code CLI](https://claude.ai/code) installed and available in PATH
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

### lazy.nvim

```lua
{
  "heliotik/botglue.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("botglue").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "heliotik/botglue.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
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
  default_keymaps = true,               -- register <leader>pp and <leader>ps
  timeout = 300,                         -- seconds (5 min), auto-cancel
  max_turns = 3,                         -- Claude tool-use turns limit
  ai_stdout_rows = 5,                   -- lines of Claude activity in top extmark
})
```

## Usage

### Keymaps (visual mode)

| Keymap | Command | Action |
|--------|---------|--------|
| `<leader>pp` | `:Botglue` | Main flow: picker → input → execute |
| `<leader>ps` | `:BotglueCancel` | Cancel running request |

### Workflow

1. Select code in visual mode (`v`, `V`, or `<C-v>`)
2. Press `<leader>pp`
3. Telescope picker opens with prompt history (sorted by frequency)
4. Pick an existing prompt or type a new one, press `<CR>`
5. Input window opens with model badge — edit prompt if needed
6. `<CR>` submits, inline progress extmarks appear around selection
7. Result replaces the selection

### Input Window Controls

- `<CR>` — submit
- `<S-CR>` — new line (multi-line prompt)
- `<C-s>` — cycle model (opus → sonnet → haiku)
- `q` / `<Esc>` — cancel

### Inline Progress Display

While processing, extmarks appear above and below your selection showing a spinner and Claude's activity (tool calls). The selection remains untouched until the result arrives.

## Custom Keymaps

If you disable default keymaps:

```lua
require("botglue").setup({ default_keymaps = false })

vim.keymap.set("x", "<leader>pp", require("botglue").run, { desc = "Botglue: run" })
vim.keymap.set("x", "<leader>ps", require("botglue").cancel, { desc = "Botglue: cancel" })
```

## Philosophy

AI as a tool for precise inline editing, not an autonomous agent. Inspired by [ThePrimeagen/99](https://github.com/ThePrimeagen/99).

## License

MIT
