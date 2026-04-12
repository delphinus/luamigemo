cache = true
std = luajit
codes = true
self = false

ignore = {
  "212", -- Unused argument
  "122", -- Indirectly setting a readonly global
  "631", -- Line too long
}
