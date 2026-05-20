-- NFD flag benchmark: measure overhead of FLAG_NFD vs default path.
-- Usage:
--   nvim --headless +'luafile ~/.local/share/nvim/lazy/luamigemo/bench/nfd_bench.lua' +qa
--   (run inside a bench-migemo or any nvim env with luamigemo loaded)
-- Output: /tmp/luamigemo_nfd_bench.txt
--
-- Methodology:
--   - One Migemo instance is reused across the benchmark (avoid dict reload cost).
--   - For cold-cache measurements we drop only _query_cache / _query_cache_nfd.
--   - Each measurement averages over N inner iterations; JIT is warmed first.

local outpath = "/tmp/luamigemo_nfd_bench.txt"
local outfile = io.open(outpath, "w")
local function P(s)
  outfile:write(s .. "\n")
end

local luamigemo = require "luamigemo"
local kdict = vim.env.HOME .. "/.cache/kensaku.vim/migemo-compact-dict"
local dict_path = vim.uv.fs_stat(kdict) and kdict or nil
local rxop = luamigemo.RXOP_VIM
local FLAG_NFD = luamigemo.FLAG_NFD

local m = luamigemo.get(dict_path)

local queries = {
  -- short
  "ka",
  "sa",
  "ta",
  "na",
  "ha",
  "ma",
  "ya",
  "ra",
  "wa",
  "ga",
  "za",
  "da",
  "ba",
  "pa",
  "jo",
  "fu",
  -- medium
  "sag",
  "sak",
  "hen",
  "kai",
  "kom",
  "set",
  "jou",
  "hoz",
  "fai",
  "moj",
  "bun",
  "kin",
  "gen",
  "kan",
  "shi",
  "sen",
  -- typical full words
  "sagyou",
  "sakujo",
  "henkou",
  "settei",
  "joutai",
  "komando",
  "hozon",
  "moji",
  "kensaku",
  "migemo",
}

local sep = string.rep("-", 88)

local function clear_query_caches()
  m._query_cache = {}
  m._query_cache_nfd = {}
end

local function bench_one(q, flags, n_outer)
  -- Each outer iteration starts cold (caches dropped). Inner work = 1 query call.
  -- Returns average ms per call.
  local total_ns = 0
  for _ = 1, n_outer do
    clear_query_caches()
    local t0 = vim.uv.hrtime()
    m:query(q, rxop, flags)
    total_ns = total_ns + (vim.uv.hrtime() - t0)
  end
  return total_ns / n_outer / 1e6
end

----------------------------------------------------------------------
-- JIT warm-up: run a wide mix of queries to compile hot paths
----------------------------------------------------------------------
P "## JIT warm-up"
for _ = 1, 3 do
  for _, q in ipairs(queries) do
    clear_query_caches()
    m:query(q, rxop)
    clear_query_caches()
    m:query(q, rxop, FLAG_NFD)
  end
end
P "  done"

----------------------------------------------------------------------
-- Test 1: cold-cache pattern generation, default vs FLAG_NFD
----------------------------------------------------------------------
P ""
P "## Test 1: Cold-cache pattern generation (each call rebuilds from dict)"
P "   Average of N outer iterations per query; per-query inner work = 1 call"
P(sep)
P(
  string.format(
    "%-12s | %12s | %12s | %8s | %8s | %5s | %5s",
    "query",
    "off (ms)",
    "on (ms)",
    "len off",
    "len on",
    "lenΔ",
    "regr"
  )
)
P(sep)

local N = 50
local off_total, on_total = 0, 0
local len_off_total, len_on_total = 0, 0
for _, q in ipairs(queries) do
  local off_ms = bench_one(q, nil, N)
  local on_ms = bench_one(q, FLAG_NFD, N)
  clear_query_caches()
  local pat_off = m:query(q, rxop)
  clear_query_caches()
  local pat_on = m:query(q, rxop, FLAG_NFD)
  off_total = off_total + off_ms
  on_total = on_total + on_ms
  len_off_total = len_off_total + #pat_off
  len_on_total = len_on_total + #pat_on
  local regr = off_ms > 0 and (on_ms / off_ms) or 0
  P(
    string.format(
      "%-12s | %9.4f ms | %9.4f ms | %8d | %8d | %+5d | %4.2fx",
      q,
      off_ms,
      on_ms,
      #pat_off,
      #pat_on,
      #pat_on - #pat_off,
      regr
    )
  )
end
P(sep)
P(
  string.format(
    "%-12s | %9.4f ms | %9.4f ms (overhead %.2fx)",
    "AVG",
    off_total / #queries,
    on_total / #queries,
    off_total > 0 and on_total / off_total or 0
  )
)
P(
  string.format(
    "Regex size: off=%d bytes  on=%d bytes  (size overhead %.2fx, +%d bytes)",
    len_off_total,
    len_on_total,
    len_off_total > 0 and len_on_total / len_off_total or 0,
    len_on_total - len_off_total
  )
)

----------------------------------------------------------------------
-- Test 2: warm-cache lookup (memoization)
----------------------------------------------------------------------
P ""
P "## Test 2: Warm-cache lookup (memoization effect)"
P "   Caches are NOT cleared between calls; should be near-instant"
P(sep)

clear_query_caches()
for _, q in ipairs(queries) do
  m:query(q, rxop)
  m:query(q, rxop, FLAG_NFD)
end

local M_inner = 1000
local off_warm_ns, on_warm_ns = 0, 0
for _, q in ipairs(queries) do
  local t0 = vim.uv.hrtime()
  for _ = 1, M_inner do
    m:query(q, rxop)
  end
  off_warm_ns = off_warm_ns + (vim.uv.hrtime() - t0)

  local t1 = vim.uv.hrtime()
  for _ = 1, M_inner do
    m:query(q, rxop, FLAG_NFD)
  end
  on_warm_ns = on_warm_ns + (vim.uv.hrtime() - t1)
end
local off_warm_us = off_warm_ns / #queries / M_inner / 1e3
local on_warm_us = on_warm_ns / #queries / M_inner / 1e3
P(
  string.format(
    "Cache hit: off = %.3f μs  on = %.3f μs  (ratio %.2fx)",
    off_warm_us,
    on_warm_us,
    off_warm_us > 0 and on_warm_us / off_warm_us or 0
  )
)

----------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------
P ""
P "## Summary"
P(sep)
P(string.format("Queries: %d   Outer N (Test 1): %d   Warm M (Test 2): %d", #queries, N, M_inner))
P(string.format("Dict:    %s", dict_path or "bundled"))

outfile:close()
print("Output written to " .. outpath)
