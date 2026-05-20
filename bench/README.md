# Benchmark scripts

Development tools for profiling and comparing luamigemo performance.

## Setup

These scripts require a **bench-migemo** environment with:

- luamigemo (this repo)
- [kensaku.vim](https://github.com/lambdalisue/kensaku.vim) + denops (for comparison)
- A Japanese document open in the buffer (e.g., vimdoc-ja's `usr_21.jax`)

## Scripts

### `profile.lua`

Internal profiling of `query_a_word` phases. Breaks down time spent in
romaji conversion, dictionary search, tree building, and regex generation.

```
nvim --headless -l bench/profile.lua
```

### `practical_bench.lua`

Practical benchmark with 80+ diverse queries and incremental typing
simulation. Compares luamigemo vs kensaku.vim (jsmigemo + denops IPC).

```vim
:luafile bench/practical_bench.lua
" Output: /tmp/luamigemo_practical.txt
```

### `compare_patterns.lua`

Side-by-side pattern output comparison for specific inputs.

```vim
:luafile bench/compare_patterns.lua
" Output: /tmp/luamigemo_compare.txt
```

### `nfd_bench.lua`

Compares the cold-cache and warm-cache cost of `FLAG_NFD` against the default
path. Reports per-query timing, regex size delta, and warm-cache lookup time.
Use the same `bench-migemo` environment as `practical_bench.lua`.

```bash
NVIM_APPNAME=nvim-dev/bench-migemo nvim --headless +'luafile bench/nfd_bench.lua' +qa
" Output: /tmp/luamigemo_nfd_bench.txt
```

### `find_differences.lua`

Scans a-z and common romaji combinations to find all pattern differences
between luamigemo and kensaku. Ignores the `\m` prefix difference.

```vim
:luafile bench/find_differences.lua
" Output: /tmp/luamigemo_diff.txt
```
