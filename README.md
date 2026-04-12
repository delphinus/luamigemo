# luamigemo

[日本語](README.ja.md)

Pure Lua migemo engine for LuaJIT. Converts romaji input into regex patterns
that match hiragana, katakana, and kanji — enabling Japanese incremental search
without switching input methods.

Ported from [oguna/jsmigemo][].

[oguna/jsmigemo]: https://github.com/oguna/jsmigemo

## Requirements

- LuaJIT (including Neovim's built-in LuaJIT)

A migemo compact dictionary is bundled, so no additional setup is needed.

## Usage

```lua
local migemo = require "luamigemo"

-- Uses the bundled dictionary and PCRE regex by default
local pattern = migemo.query("kensaku")
-- => PCRE regex matching 検索, けんさく, ケンサク, etc.
```

### Customizing regex dialect or dictionary

Pass an rxop table to `query()` to change the regex dialect:

```lua
local migemo = require "luamigemo"

-- Use Vim regex dialect
local pattern = migemo.query("tokyo", migemo.RXOP_VIM)
```

### Custom dictionary

You can use a different dictionary by passing a path to `migemo.get()`:

```lua
local migemo = require "luamigemo"

-- Use a custom dict (e.g., the larger GPL dict from migemo-compact-dict-latest)
local m = migemo.get("/path/to/migemo-compact-dict")
local pattern = m:query("kensaku")
```

The larger GPL-licensed dictionary is available from
[oguna/migemo-compact-dict-latest][]. It is derived from SKK-JISYO.L and
has more entries than the bundled BSD dictionary.

[oguna/migemo-compact-dict-latest]: https://github.com/oguna/migemo-compact-dict-latest

## Regex dialects

| Constant | Description |
|---|---|
| `RXOP_PCRE` | PCRE syntax (for ripgrep, etc.) |
| `RXOP_VIM` | Vim regex syntax (for `vim.regex()`) |

## Health check

In Neovim, run `:checkhealth luamigemo` to verify the dictionary and
LuaJIT environment.

## Modules

| Module | Description |
|---|---|
| `luamigemo` | Main API with singleton management |
| `luamigemo.compact_dictionary` | Binary dictionary reader (jsmigemo format) |
| `luamigemo.louds_trie` | LOUDS-encoded trie |
| `luamigemo.bit_vector` | Succinct bit vector with rank/select |
| `luamigemo.romaji_processor` | Romaji to hiragana with predictive conversion |
| `luamigemo.ternary_regex_generator` | Regex pattern builder |
| `luamigemo.character_converter` | Full/half-width and hiragana/katakana conversion |

## Install

### As a Neovim plugin dependency (lazy.nvim)

```lua
{ "delphinus/luamigemo", version = "*" }
```

### LuaRocks

```bash
luarocks install luamigemo
```

### Manual

Clone this repository and add `lua/` to your `package.path`:

```bash
git clone https://github.com/delphinus/luamigemo.git
```

```lua
package.path = "/path/to/luamigemo/lua/?.lua;/path/to/luamigemo/lua/?/init.lua;" .. package.path
```

## Dictionary

The bundled dictionary (`dict/migemo-compact-dict`) is compiled from
[yet-another-migemo-dict][] by jsmigemo. It is licensed under the
BSD 3-Clause License (see `dict/LICENSE`).

[yet-another-migemo-dict]: https://github.com/oguna/yet-another-migemo-dict

## Release

Pushing a tag matching `v*` triggers a GitHub Actions workflow that
automatically publishes the package to [LuaRocks](https://luarocks.org/).

```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

- [oguna/jsmigemo][] — original TypeScript implementation
- [oguna/yet-another-migemo-dict][] — dictionary data (BSD 3-Clause)
- [koron/cmigemo](https://github.com/koron/cmigemo) — C/Migemo
- [migemo](http://0xcc.net/migemo/) — original concept by Satoru Takabayashi
