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
