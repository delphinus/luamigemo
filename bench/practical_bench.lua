-- Practical benchmark: diverse queries against a real document
-- Usage: Run in bench-migemo environment with usr_21.jax open
-- :luafile ~/.local/share/nvim/lazy/luamigemo/bench/practical_bench.lua
-- Output: /tmp/luamigemo_practical.txt

local outpath = "/tmp/luamigemo_practical.txt"
local outfile = io.open(outpath, "w")
local function P(s) outfile:write(s .. "\n") end

local luamigemo = require "luamigemo"
local kdict = vim.env.HOME .. "/.cache/kensaku.vim/migemo-compact-dict"
local dict_path = vim.uv.fs_stat(kdict) and kdict or nil
local inst = luamigemo.get(dict_path)
local rxop = luamigemo.RXOP_VIM

-- Diverse romaji inputs simulating real search queries
local queries = {
  -- Short (2 chars) - common first inputs in flash.nvim
  "ka", "sa", "ta", "na", "ha", "ma", "ya", "ra", "wa",
  "ki", "si", "ti", "ni", "hi", "mi", "ri",
  "ku", "su", "tu", "nu", "hu", "mu", "yu", "ru",
  "ko", "so", "to", "no", "ho", "mo", "yo", "ro", "wo",
  "ke", "se", "te", "ne", "he", "me", "re",
  "ga", "za", "da", "ba", "pa", "jo", "fu",
  -- Medium (3-4 chars) - typical search depth
  "sag", "sak", "hen", "kai", "kom", "set", "jou", "hoz",
  "fai", "moj", "bun", "kin", "gen", "kan", "shi", "sen",
  "kok", "hyo", "nam", "rei", "iti", "san", "yon", "goj",
  "roku", "nana", "hati", "kyuu", "zyuu",
  -- Longer (5+ chars) - narrowed search
  "sagyo", "sakuj", "henko", "fairu", "koman", "sette",
  "jouta", "hozon", "mojir", "hensu", "kinou", "jouho",
  -- Full words
  "sagyou", "sakujo", "henkou", "settei", "joutai",
  "komando", "hozon", "moji", "kensaku", "migemo",
}

-- Warm up all caches
P("Warming up caches...")
for _, q in ipairs(queries) do
  inst:query(q, rxop)
end

local sep = string.rep("-", 90)

----------------------------------------------------------------------
-- Test 1: Pattern generation time (unique queries, no memoization benefit)
----------------------------------------------------------------------
P("")
P("## Test 1: Pattern generation (first call, no memo cache)")
P("   Each query is fresh - measures actual computation time")
P(sep)

-- Force fresh instance to clear query cache
package.loaded["luamigemo"] = nil
local fresh_mod = require("luamigemo")
local fresh_inst = fresh_mod.get(dict_path)

-- But warm the dictionary caches (mapping, reverse_lookup, search_result)
-- by running all queries once
for _, q in ipairs(queries) do
  fresh_inst:query(q, rxop)
end

-- Now create another fresh instance - dict caches are per-CompactDictionary,
-- so we need yet another instance... Actually, the dict is shared.
-- Let's just clear the query_cache on the instance.
fresh_inst._query_cache = {}

P(string.format("%-12s | %10s | %10s | %8s", "query", "lua (ms)", "ken (ms)", "lua len"))
P(sep)

local lua_total = 0
local ken_total = 0
for _, q in ipairs(queries) do
  local t0 = vim.uv.hrtime()
  local pat = fresh_inst:query(q, rxop)
  local lua_ms = (vim.uv.hrtime() - t0) / 1e6
  lua_total = lua_total + lua_ms

  local t1 = vim.uv.hrtime()
  pcall(vim.fn["kensaku#query"], q)
  local ken_ms = (vim.uv.hrtime() - t1) / 1e6
  ken_total = ken_total + ken_ms

  P(string.format("%-12s | %8.3f ms | %8.3f ms | %8d", q, lua_ms, ken_ms, #pat))
end
P(sep)
P(string.format("%-12s | %8.3f ms | %8.3f ms", "TOTAL", lua_total, ken_total))
P(string.format("%-12s | %8.3f ms | %8.3f ms", "AVG", lua_total / #queries, ken_total / #queries))

----------------------------------------------------------------------
-- Test 2: Flash.nvim simulation - incremental typing of various words
----------------------------------------------------------------------
P("")
P("## Test 2: Flash.nvim incremental typing simulation (cold query cache)")
P("   Simulates typing different words one after another")
P(sep)

-- Words to "type" incrementally
local words = {
  "sagyou", "henkou", "komando", "settei", "joutai",
  "hozon", "fairu", "kensaku", "migemo", "mojiretu",
}

-- Clear query cache
fresh_inst._query_cache = {}

lua_total = 0
ken_total = 0
local saved = vim.fn.getpos "."

for _, word in ipairs(words) do
  P("  Typing: " .. word)
  local word_lua = 0
  local word_ken = 0
  -- Type each character incrementally
  for i = 2, #word do  -- start from 2 chars (like fuzzy-motion.vim)
    local partial = word:sub(1, i)

    local t0 = vim.uv.hrtime()
    local pat = fresh_inst:query(partial, rxop)
    vim.fn.cursor(1, 1)
    vim.fn.searchpos(pat, "cW")
    local lua_ms = (vim.uv.hrtime() - t0) / 1e6
    word_lua = word_lua + lua_ms

    local t1 = vim.uv.hrtime()
    local kpat = vim.fn["kensaku#query"](partial)
    vim.fn.cursor(1, 1)
    vim.fn.searchpos(kpat, "cW")
    local ken_ms = (vim.uv.hrtime() - t1) / 1e6
    word_ken = word_ken + ken_ms

    vim.fn.setpos(".", saved)
  end
  lua_total = lua_total + word_lua
  ken_total = ken_total + word_ken
  P(string.format("    total: lua=%8.3f ms  ken=%8.3f ms", word_lua, word_ken))
end
P(sep)
P(string.format("%-12s | %8.3f ms | %8.3f ms", "TOTAL", lua_total, ken_total))
P(string.format("%-12s | %8.3f ms | %8.3f ms", "AVG/word", lua_total / #words, ken_total / #words))

----------------------------------------------------------------------
-- Test 3: Repeated queries (memoization benefit)
----------------------------------------------------------------------
P("")
P("## Test 3: Repeated queries (memoization effect)")
P("   Same queries as Test 1, but now cached from Test 1")
P(sep)

lua_total = 0
ken_total = 0
for _, q in ipairs(queries) do
  local t0 = vim.uv.hrtime()
  fresh_inst:query(q, rxop)
  local lua_ms = (vim.uv.hrtime() - t0) / 1e6
  lua_total = lua_total + lua_ms

  local t1 = vim.uv.hrtime()
  pcall(vim.fn["kensaku#query"], q)
  local ken_ms = (vim.uv.hrtime() - t1) / 1e6
  ken_total = ken_total + ken_ms
end
P(string.format("%-12s | %8.3f ms | %8.3f ms", "TOTAL", lua_total, ken_total))
P(string.format("%-12s | %8.3f ms | %8.3f ms", "AVG", lua_total / #queries, ken_total / #queries))

----------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------
P("")
P("## Summary")
P(sep)
P(string.format("Queries tested:       %d unique, %d incremental steps", #queries, 0))
P(string.format("Dictionary:           %s", dict_path or "bundled"))

outfile:close()
print("Output written to " .. outpath)
