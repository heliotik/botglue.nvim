std = luajit
cache = true
codes = true
ignore = {
  "211", -- Unused local variable
}
read_globals = { "vim", "describe", "it", "assert", "before_each", "after_each" }
