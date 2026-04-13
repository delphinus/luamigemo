-- Compare luamigemo vs kensaku.vim (jsmigemo) pattern output
-- Usage: source this in bench-migemo environment after denops is ready
-- :luafile <this_file>
-- Output: /tmp/luamigemo_compare.txt

local migemo = require "luamigemo"
local outpath = "/tmp/luamigemo_compare.txt"
local outfile = io.open(outpath, "w")

local function get_kensaku(input)
  local ok, result = pcall(vim.fn["kensaku#query"], input)
  if ok then
    return result
  end
  return "(kensaku not available)"
end

-- Parse a vim regex alternation group into a sorted list of alternatives
local function parse_alternatives(pattern)
  -- Strip outer \%( ... \)
  local inner = pattern:match "^\\%%%((.+)\\%)$"
  if not inner then
    return { pattern }
  end
  -- Split by \|
  local parts = {}
  local depth = 0
  local start = 1
  local i = 1
  while i <= #inner do
    if inner:sub(i, i + 2) == "\\%(" then
      depth = depth + 1
      i = i + 3
    elseif inner:sub(i, i + 1) == "\\)" then
      depth = depth - 1
      i = i + 2
    elseif inner:sub(i, i + 1) == "\\|" and depth == 0 then
      parts[#parts + 1] = inner:sub(start, i - 1)
      start = i + 2
      i = i + 2
    else
      i = i + 1
    end
  end
  parts[#parts + 1] = inner:sub(start)
  table.sort(parts)
  return parts
end

local inputs = { "a", "jo", "jou", "jout", "jouta", "joutai" }

for _, input in ipairs(inputs) do
  local lua_pat = migemo.query(input, migemo.RXOP_VIM)
  local ken_pat = get_kensaku(input)

  outfile:write(string.rep("=", 80) .. "\n")
  outfile:write(("Input: %q  (lua len=%d, ken len=%d)\n"):format(input, #lua_pat, #ken_pat))
  outfile:write(string.rep("=", 80) .. "\n")

  local lua_parts = parse_alternatives(lua_pat)
  local ken_parts = parse_alternatives(ken_pat)

  -- Build sets
  local lua_set = {}
  for _, p in ipairs(lua_parts) do
    lua_set[p] = true
  end
  local ken_set = {}
  for _, p in ipairs(ken_parts) do
    ken_set[p] = true
  end

  -- Only in luamigemo
  local lua_only = {}
  for _, p in ipairs(lua_parts) do
    if not ken_set[p] then
      lua_only[#lua_only + 1] = p
    end
  end

  -- Only in kensaku
  local ken_only = {}
  for _, p in ipairs(ken_parts) do
    if not lua_set[p] then
      ken_only[#ken_only + 1] = p
    end
  end

  -- Common
  local common = {}
  for _, p in ipairs(lua_parts) do
    if ken_set[p] then
      common[#common + 1] = p
    end
  end

  outfile:write(("  Common alternatives: %d\n"):format(#common))

  if #lua_only > 0 then
    outfile:write(("  Only in luamigemo (%d):\n"):format(#lua_only))
    for _, p in ipairs(lua_only) do
      outfile:write("    + " .. p .. "\n")
    end
  end

  if #ken_only > 0 then
    outfile:write(("  Only in kensaku (%d):\n"):format(#ken_only))
    for _, p in ipairs(ken_only) do
      outfile:write("    + " .. p .. "\n")
    end
  end

  outfile:write("\n")
end

outfile:close()
print("Output written to " .. outpath)
