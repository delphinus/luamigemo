# luamigemo

Pure Lua migemo engine for LuaJIT. Converts romaji input into regex patterns
that match hiragana, katakana, and kanji — enabling Japanese incremental search
without switching input methods.

Ported from [oguna/jsmigemo][].

[oguna/jsmigemo]: https://github.com/oguna/jsmigemo

## Requirements

- LuaJIT (including Neovim's built-in LuaJIT)
- A migemo compact dictionary file from [oguna/migemo-compact-dict-latest][]

[oguna/migemo-compact-dict-latest]: https://github.com/oguna/migemo-compact-dict-latest

## Usage

```lua
local migemo = require "luamigemo"

-- Load a dictionary and query with PCRE regex output
local pattern = migemo.query("/path/to/migemo-compact-dict", "kensaku", migemo.RXOP_PCRE)
-- => PCRE regex matching 検索, けんさく, ケンサク, etc.

-- Use Vim regex dialect instead
local vim_pattern = migemo.query("/path/to/migemo-compact-dict", "kensaku", migemo.RXOP_VIM)
```

### Lower-level API

```lua
local migemo = require "luamigemo"
local CompactDictionary = require "luamigemo.compact_dictionary"

-- Create and configure a Migemo instance manually
local m = migemo.get("/path/to/migemo-compact-dict")
m:set_rxop(migemo.RXOP_PCRE)
local pattern = m:query("tokyo")
```

## Regex dialects

| Constant | Description |
|---|---|
| `RXOP_PCRE` | PCRE syntax (for ripgrep, etc.) |
| `RXOP_VIM` | Vim regex syntax (for `vim.regex()`) |

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
{ "delphinus/luamigemo" }
```

### Manual

Clone this repository and add `lua/` to your `package.path`:

```bash
git clone https://github.com/delphinus/luamigemo.git
```

```lua
package.path = "/path/to/luamigemo/lua/?.lua;/path/to/luamigemo/lua/?/init.lua;" .. package.path
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

- [oguna/jsmigemo][] — original TypeScript implementation
- [koron/cmigemo](https://github.com/koron/cmigemo) — C/Migemo
- [migemo](http://0xcc.net/migemo/) — original concept by Satoru Takabayashi
