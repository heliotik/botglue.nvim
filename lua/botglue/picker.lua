local history = require("botglue.history")

local M = {}

--- Open Telescope picker with prompt history.
--- @param on_select fun(entry: {prompt: string, model: string}|nil)
function M.open(on_select)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("botglue: telescope.nvim is required", vim.log.levels.ERROR)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local entries = history.get_sorted()

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { remaining = true },
      { width = 10 },
    },
  })

  local function make_display(entry)
    return displayer({
      entry.value.prompt,
      { "[" .. entry.value.model .. "]", "Comment" },
    })
  end

  pickers
    .new({}, {
      prompt_title = "Botglue",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.prompt,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          local current_line = action_state.get_current_line()
          actions.close(prompt_bufnr)

          if selection then
            on_select({ prompt = selection.value.prompt, model = selection.value.model })
          elseif current_line and current_line ~= "" then
            on_select({ prompt = current_line, model = nil })
          else
            on_select(nil)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
