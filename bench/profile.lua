#!/usr/bin/env -S nvim --headless -l
-- Profile luamigemo query_a_word to identify bottlenecks.
-- Usage: nvim --headless -l bench/profile.lua

-- Resolve repo root from script source or cwd
local source = debug.getinfo(1, "S").source:sub(2)
local script_dir = source:match("^(.*)/[^/]+$") or "."
local repo_root
if script_dir:match("^/") then
  repo_root = script_dir:match("^(.*)/[^/]+$") or script_dir
else
  local cwd = vim.fn.getcwd()
  repo_root = cwd
end
package.path = repo_root .. "/lua/?.lua;" .. repo_root .. "/lua/?/init.lua;" .. package.path

local ffi = require "ffi"
ffi.cdef [[
  typedef struct timeval {
    long tv_sec;
    int tv_usec;
  } timeval;
  int gettimeofday(struct timeval *tv, void *tz);
]]
local tv = ffi.new("timeval")
local function now_us()
  ffi.C.gettimeofday(tv, nil)
  return tonumber(tv.tv_sec) * 1e6 + tonumber(tv.tv_usec)
end

local CompactDictionary = require "luamigemo.compact_dictionary"
local RomajiProcessor = require "luamigemo.romaji_processor"
local TernaryRegexGenerator = require "luamigemo.ternary_regex_generator"
local cc = require "luamigemo.character_converter"
local luamigemo = require "luamigemo"

local dict_path = luamigemo.bundled_dict_path()
assert(dict_path, "dictionary not found")
local dict = CompactDictionary.load(dict_path)
local processor = RomajiProcessor.build()
local rxop = luamigemo.RXOP_VIM

local inputs = { "a", "jo", "jou", "jout", "jouta", "joutai" }

-- Profile each phase of query_a_word
local function profile_query(word)
  local t = {}

  -- Phase 1: romaji_to_hiragana_predictively
  local t0 = now_us()
  local result = processor:romaji_to_hiragana_predictively(word:lower())
  t.romaji = now_us() - t0

  -- Phase 2: dictionary predictive_search for the raw word
  local t1 = now_us()
  local dict_results_raw = {}
  for w in dict:predictive_search(word:lower()) do
    dict_results_raw[#dict_results_raw + 1] = w
  end
  t.dict_raw = now_us() - t1
  t.dict_raw_count = #dict_results_raw

  -- Phase 3: dictionary predictive_search for each hiragana suffix
  local t2 = now_us()
  local dict_results_hira = {}
  for _, suffix in ipairs(result.suffixes) do
    local hira = result.prefix .. suffix
    for w in dict:predictive_search(hira) do
      dict_results_hira[#dict_results_hira + 1] = w
    end
  end
  t.dict_hira = now_us() - t2
  t.dict_hira_count = #dict_results_hira

  -- Phase 4: character conversions
  local t3 = now_us()
  local _ = cc.han2zen(word)
  _ = cc.zen2han(word)
  for _, suffix in ipairs(result.suffixes) do
    local hira = result.prefix .. suffix
    local kata = cc.hira2kata(hira)
    _ = cc.zen2han(kata)
  end
  t.charconv = now_us() - t3

  -- Phase 5: TernaryRegexGenerator add (simulating the full flow)
  local t4 = now_us()
  local generator = TernaryRegexGenerator.new(rxop)
  generator:add(word)
  for _, w in ipairs(dict_results_raw) do
    generator:add(w)
  end
  generator:add(cc.han2zen(word))
  generator:add(cc.zen2han(word))
  for _, suffix in ipairs(result.suffixes) do
    local hira = result.prefix .. suffix
    generator:add(hira)
    for _, w in ipairs(dict_results_hira) do
      generator:add(w)
    end
    generator:add(cc.hira2kata(hira))
    generator:add(cc.zen2han(cc.hira2kata(hira)))
  end
  t.tree_add = now_us() - t4

  -- Phase 6: generate regex
  local t5 = now_us()
  local pattern = generator:generate()
  t.generate = now_us() - t5
  t.pattern_len = #pattern

  -- Total
  t.total = t.romaji + t.dict_raw + t.dict_hira + t.charconv + t.tree_add + t.generate
  return t
end

-- Sub-profile: break down dictionary predictive_search
local function profile_dict_search(key)
  local LOUDSTrie = require "luamigemo.louds_trie"
  local t = {}

  -- lookup
  local t0 = now_us()
  local key_index = dict.key_trie:lookup(key)
  t.lookup = now_us() - t0

  if key_index <= 1 then
    t.trie_search = 0
    t.mapping = 0
    t.reverse_lookup = 0
    t.node_count = 0
    t.result_count = 0
    return t
  end

  -- trie predictive_search (just enumerate nodes)
  local t1 = now_us()
  local node_count = 0
  for _ in dict.key_trie:predictive_search(key_index) do
    node_count = node_count + 1
  end
  t.trie_search = now_us() - t1
  t.node_count = node_count

  -- mapping + reverse_lookup
  local t2 = now_us()
  local result_count = 0
  for i in dict.key_trie:predictive_search(key_index) do
    if dict.has_mapping:get(i) then
      local vs = dict.mapping_bv:select(i, false)
      local ve = dict.mapping_bv:next_clear_bit(vs + 1)
      local size = ve - vs - 1
      local off = dict.mapping_bv:rank(vs, false)
      for j = 0, size - 1 do
        local _ = dict.value_trie:reverse_lookup(dict.mapping[vs - off + j])
        result_count = result_count + 1
      end
    end
  end
  t.mapping_and_rlookup = now_us() - t2
  t.result_count = result_count

  return t
end

-- Run profiling
print("=" .. string.rep("=", 79))
print("luamigemo profiling: breakdown of query_a_word")
print("=" .. string.rep("=", 79))

-- Warm up
for _, input in ipairs(inputs) do
  luamigemo.query(input, rxop)
end

print ""
print(string.format(
  "%-8s | %8s | %8s | %8s | %8s | %8s | %8s | %8s | %s",
  "input", "romaji", "dict_raw", "dict_hir", "charconv", "tree_add", "generate", "TOTAL", "counts"
))
print(string.rep("-", 110))

for _, input in ipairs(inputs) do
  local t = profile_query(input)
  print(string.format(
    "%-8s | %6.1f us | %6.0f us | %6.0f us | %6.1f us | %6.0f us | %6.0f us | %6.0f us | raw=%d hira=%d",
    input,
    t.romaji, t.dict_raw, t.dict_hira, t.charconv, t.tree_add, t.generate, t.total,
    t.dict_raw_count, t.dict_hira_count
  ))
end

print ""
print("=" .. string.rep("=", 79))
print("Dictionary predictive_search breakdown")
print("=" .. string.rep("=", 79))

local search_keys = {}
for _, input in ipairs(inputs) do
  search_keys[#search_keys + 1] = { key = input:lower(), label = input .. "(raw)" }
  local result = processor:romaji_to_hiragana_predictively(input:lower())
  for _, suffix in ipairs(result.suffixes) do
    local hira = result.prefix .. suffix
    if hira ~= "" then
      search_keys[#search_keys + 1] = { key = hira, label = input .. "(hira:" .. hira .. ")" }
    end
  end
end

-- Deduplicate
local seen = {}
local unique_keys = {}
for _, sk in ipairs(search_keys) do
  if not seen[sk.key] then
    seen[sk.key] = true
    unique_keys[#unique_keys + 1] = sk
  end
end

print ""
print(string.format(
  "%-20s | %8s | %10s | %12s | %6s | %6s",
  "key", "lookup", "trie_iter", "map+rlookup", "nodes", "results"
))
print(string.rep("-", 80))

for _, sk in ipairs(unique_keys) do
  local t = profile_dict_search(sk.key)
  print(string.format(
    "%-20s | %6.1f us | %8.0f us | %10.0f us | %6d | %6d",
    sk.label,
    t.lookup, t.trie_search, t.mapping_and_rlookup or 0, t.node_count, t.result_count or 0
  ))
end

print ""
print("=" .. string.rep("=", 79))
print("Overall query() timing (averaged over 5 runs)")
print("=" .. string.rep("=", 79))
print ""
print(string.format("%-10s | %14s | %8s", "input", "time", "len"))
print(string.rep("-", 40))

for _, input in ipairs(inputs) do
  local N = 5
  local total = 0
  local pattern
  for _ = 1, N do
    local t0 = now_us()
    pattern = luamigemo.query(input, rxop)
    total = total + (now_us() - t0)
  end
  print(string.format("%-10s | %11.3f ms | %8d", input, total / N / 1000, #pattern))
end

vim.cmd "qa!"
