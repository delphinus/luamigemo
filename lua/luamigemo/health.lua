local M = {}

function M.check()
  vim.health.start "luamigemo"

  if jit then
    vim.health.ok("LuaJIT: " .. jit.version)
  else
    vim.health.error "LuaJIT not found. luamigemo requires LuaJIT (ffi and bit modules)."
  end

  local luamigemo = require "luamigemo"

  local bundled = luamigemo.bundled_dict_path()
  if bundled then
    local f = io.open(bundled, "rb")
    if f then
      local size = f:seek "end"
      f:close()
      vim.health.ok(("Bundled dict: %s (%d bytes)"):format(bundled, size))
    else
      vim.health.warn("Bundled dict path resolved but file not readable: " .. bundled)
    end
  else
    vim.health.warn "Bundled dict not found. Provide an explicit dict_path to M.get() or M.query()."
  end

  local active = luamigemo.active_dict_path()
  if active then
    vim.health.ok("Active dict: " .. active)
  else
    vim.health.info "No dict loaded yet (will load on first query)."
  end

  local ok, err = pcall(require, "luamigemo.compact_dictionary")
  if ok then
    vim.health.ok "Core modules loaded successfully."
  else
    vim.health.error("Failed to load compact_dictionary: " .. tostring(err))
  end
end

return M
