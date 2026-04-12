# luamigemo

LuaJIT 向けの純 Lua migemo エンジン。ローマ字入力からひらがな・カタカナ・
漢字にマッチする正規表現パターンを生成し、入力メソッドを切り替えずに日本語の
インクリメンタル検索を実現します。

[oguna/jsmigemo][] からの移植です。

[oguna/jsmigemo]: https://github.com/oguna/jsmigemo

## 必要環境

- LuaJIT (Neovim 組み込みの LuaJIT を含む)

migemo 用コンパクト辞書が同梱されているため、追加のセットアップは不要です。

## 使い方

```lua
local migemo = require "luamigemo"

-- 同梱辞書と PCRE 正規表現をデフォルトで使用
local pattern = migemo.query("kensaku")
-- => 検索, けんさく, ケンサク などにマッチする PCRE 正規表現
```

### 正規表現方言・辞書のカスタマイズ

`migemo.get()` でインスタンスを作成すると細かく制御できます:

```lua
local migemo = require "luamigemo"

-- Vim 正規表現方言を使う場合
local m = migemo.get()
m:set_rxop(migemo.RXOP_VIM)
local pattern = m:query("tokyo")
```

### カスタム辞書

`migemo.get()` にパスを渡すことで別の辞書を使用できます:

```lua
local migemo = require "luamigemo"

-- カスタム辞書を使用 (例: migemo-compact-dict-latest の GPL 辞書)
local m = migemo.get("/path/to/migemo-compact-dict")
m:set_rxop(migemo.RXOP_PCRE)
local pattern = m:query("kensaku")
```

より大きな GPL ライセンスの辞書が [oguna/migemo-compact-dict-latest][] から
入手できます。SKK-JISYO.L 由来で、同梱の BSD 辞書よりも多くのエントリを
含んでいます。

[oguna/migemo-compact-dict-latest]: https://github.com/oguna/migemo-compact-dict-latest

## 正規表現方言

| 定数 | 説明 |
|---|---|
| `RXOP_PCRE` | PCRE 構文 (ripgrep 等向け) |
| `RXOP_VIM` | Vim 正規表現構文 (`vim.regex()` 向け) |

## ヘルスチェック

Neovim で `:checkhealth luamigemo` を実行すると、辞書と LuaJIT 環境を
検証できます。

## モジュール

| モジュール | 説明 |
|---|---|
| `luamigemo` | メイン API、シングルトン管理 |
| `luamigemo.compact_dictionary` | バイナリ辞書リーダー (jsmigemo 形式) |
| `luamigemo.louds_trie` | LOUDS エンコード trie |
| `luamigemo.bit_vector` | rank/select 付き簡潔ビットベクトル |
| `luamigemo.romaji_processor` | ローマ字→ひらがな変換 (予測変換対応) |
| `luamigemo.ternary_regex_generator` | 正規表現パターン生成器 |
| `luamigemo.character_converter` | 全角/半角・ひらがな/カタカナ変換 |

## インストール

### Neovim プラグイン依存として (lazy.nvim)

```lua
{ "delphinus/luamigemo" }
```

### LuaRocks

```bash
luarocks install luamigemo
```

### 手動

リポジトリをクローンし、`lua/` を `package.path` に追加してください:

```bash
git clone https://github.com/delphinus/luamigemo.git
```

```lua
package.path = "/path/to/luamigemo/lua/?.lua;/path/to/luamigemo/lua/?/init.lua;" .. package.path
```

## 辞書

同梱辞書 (`dict/migemo-compact-dict`) は [yet-another-migemo-dict][] から
jsmigemo によってコンパイルされたものです。BSD 3-Clause License の下で
提供されています (詳細は `dict/LICENSE` を参照)。

[yet-another-migemo-dict]: https://github.com/oguna/yet-another-migemo-dict

## リリース

`v*` にマッチするタグをプッシュすると、GitHub Actions ワークフローが
自動的にパッケージを [LuaRocks](https://luarocks.org/) に公開します。

```bash
git tag v1.0.0
git push origin v1.0.0
```

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照してください。

## クレジット

- [oguna/jsmigemo][] — 移植元の TypeScript 実装
- [oguna/yet-another-migemo-dict][] — 辞書データ (BSD 3-Clause)
- [koron/cmigemo](https://github.com/koron/cmigemo) — C/Migemo
- [migemo](http://0xcc.net/migemo/) — 高林哲氏によるオリジナルコンセプト
