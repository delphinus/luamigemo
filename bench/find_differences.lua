-- Find all pattern differences between luamigemo and kensaku (jsmigemo)
-- Usage: source this in bench-migemo environment after denops is ready
-- :luafile ~/.local/share/nvim/lazy/luamigemo/bench/find_differences.lua
-- Output: /tmp/luamigemo_diff.txt

local luamigemo = require "luamigemo"
local kensaku_dict = vim.env.HOME .. "/.cache/kensaku.vim/migemo-compact-dict"
local dict_path = vim.uv.fs_stat(kensaku_dict) and kensaku_dict or nil
local instance = luamigemo.get(dict_path)
local rxop = luamigemo.RXOP_VIM

local outpath = "/tmp/luamigemo_diff.txt"
local outfile = io.open(outpath, "w")

-- Test inputs: single chars, common 2-3 char romaji combinations,
-- and inputs that might trigger っ/suffix differences
local inputs = {}

-- All single letters
for c = string.byte("a"), string.byte("z") do
  inputs[#inputs + 1] = string.char(c)
end

-- Common 2-char combinations
local two_chars = {
  "ka", "ki", "ku", "ke", "ko", "sa", "si", "su", "se", "so",
  "ta", "ti", "tu", "te", "to", "na", "ni", "nu", "ne", "no",
  "ha", "hi", "hu", "he", "ho", "ma", "mi", "mu", "me", "mo",
  "ya", "yu", "yo", "ra", "ri", "ru", "re", "ro", "wa", "wo",
  "ga", "gi", "gu", "ge", "go", "za", "zi", "zu", "ze", "zo",
  "da", "di", "du", "de", "do", "ba", "bi", "bu", "be", "bo",
  "pa", "pi", "pu", "pe", "po", "ja", "ji", "ju", "je", "jo",
  "fa", "fi", "fu", "fe", "fo", "sh", "ch", "ts",
}
for _, s in ipairs(two_chars) do
  inputs[#inputs + 1] = s
end

-- Inputs ending in consonant (triggers predictive suffix)
local consonant_endings = {
  "ak", "at", "as", "an", "jout", "kat", "kit", "kut", "kok",
  "sat", "set", "sot", "tak", "tok", "hat", "hot", "mat", "mot",
  "nat", "not", "rat", "rot", "kas", "kos", "tas", "tos",
  "jok", "jos", "jon", "jot", "jour", "jous",
}
for _, s in ipairs(consonant_endings) do
  inputs[#inputs + 1] = s
end

-- Deduplicate
local seen = {}
local unique = {}
for _, s in ipairs(inputs) do
  if not seen[s] then
    seen[s] = true
    unique[#unique + 1] = s
  end
end

outfile:write("## Pattern differences between luamigemo and kensaku (same dictionary)\n")
outfile:write("## Differences of exactly 2 bytes are from \\m prefix (ignored)\n\n")

local diff_count = 0
local m_only_count = 0

for _, input in ipairs(unique) do
  local lua_pat = instance:query(input, rxop)
  local ok, ken_pat = pcall(vim.fn["kensaku#query"], input)
  if not ok then
    ken_pat = "(error)"
  end

  local len_diff = #lua_pat - #ken_pat

  -- Check if the difference is just \m prefix
  if len_diff == -2 and ken_pat:sub(1, 2) == "\\m" and lua_pat == ken_pat:sub(3) then
    m_only_count = m_only_count + 1
    -- Skip: only \m difference
  elseif lua_pat == ken_pat then
    -- Identical (shouldn't happen since kensaku adds \m)
  else
    diff_count = diff_count + 1
    outfile:write(string.rep("=", 80) .. "\n")
    outfile:write(("Input: %q  (lua=%d, ken=%d, diff=%+d)\n"):format(input, #lua_pat, #ken_pat, len_diff))
    outfile:write(string.rep("-", 80) .. "\n")
    outfile:write("luamigemo: " .. lua_pat .. "\n")
    outfile:write("kensaku:   " .. ken_pat .. "\n")
    outfile:write("\n")
  end
end

outfile:write(string.rep("=", 80) .. "\n")
outfile:write(("Summary: %d inputs tested, %d identical (\\m only), %d with real differences\n"):format(
  #unique, m_only_count, diff_count))
outfile:close()

print(("Output written to %s (%d differences found)"):format(outpath, diff_count))
