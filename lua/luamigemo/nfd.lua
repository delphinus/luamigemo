local utils = require "luamigemo.utils"

local M = {}

-- NFC codepoint -> NFD UTF-8 byte sequence.
-- Covers canonical decompositions in the Hiragana (U+3041-U+309F) and Katakana
-- (U+30A1-U+30FF) blocks. macOS APFS / iCloud return Japanese filenames in NFD,
-- so the migemo regex must tolerate either form for filename matching.
-- Pre-computed from UnicodeData.txt canonical decomposition (not compatibility).
local decompose = {
  [0x304C] = "\227\129\139\227\130\153", -- が = U+304B + U+3099
  [0x304E] = "\227\129\141\227\130\153", -- ぎ = U+304D + U+3099
  [0x3050] = "\227\129\143\227\130\153", -- ぐ = U+304F + U+3099
  [0x3052] = "\227\129\145\227\130\153", -- げ = U+3051 + U+3099
  [0x3054] = "\227\129\147\227\130\153", -- ご = U+3053 + U+3099
  [0x3056] = "\227\129\149\227\130\153", -- ざ = U+3055 + U+3099
  [0x3058] = "\227\129\151\227\130\153", -- じ = U+3057 + U+3099
  [0x305A] = "\227\129\153\227\130\153", -- ず = U+3059 + U+3099
  [0x305C] = "\227\129\155\227\130\153", -- ぜ = U+305B + U+3099
  [0x305E] = "\227\129\157\227\130\153", -- ぞ = U+305D + U+3099
  [0x3060] = "\227\129\159\227\130\153", -- だ = U+305F + U+3099
  [0x3062] = "\227\129\161\227\130\153", -- ぢ = U+3061 + U+3099
  [0x3065] = "\227\129\164\227\130\153", -- づ = U+3064 + U+3099
  [0x3067] = "\227\129\166\227\130\153", -- で = U+3066 + U+3099
  [0x3069] = "\227\129\168\227\130\153", -- ど = U+3068 + U+3099
  [0x3070] = "\227\129\175\227\130\153", -- ば = U+306F + U+3099
  [0x3071] = "\227\129\175\227\130\154", -- ぱ = U+306F + U+309A
  [0x3073] = "\227\129\178\227\130\153", -- び = U+3072 + U+3099
  [0x3074] = "\227\129\178\227\130\154", -- ぴ = U+3072 + U+309A
  [0x3076] = "\227\129\181\227\130\153", -- ぶ = U+3075 + U+3099
  [0x3077] = "\227\129\181\227\130\154", -- ぷ = U+3075 + U+309A
  [0x3079] = "\227\129\184\227\130\153", -- べ = U+3078 + U+3099
  [0x307A] = "\227\129\184\227\130\154", -- ぺ = U+3078 + U+309A
  [0x307C] = "\227\129\187\227\130\153", -- ぼ = U+307B + U+3099
  [0x307D] = "\227\129\187\227\130\154", -- ぽ = U+307B + U+309A
  [0x3094] = "\227\129\134\227\130\153", -- ゔ = U+3046 + U+3099
  [0x309E] = "\227\130\157\227\130\153", -- ゞ = U+309D + U+3099
  [0x30AC] = "\227\130\171\227\130\153", -- ガ = U+30AB + U+3099
  [0x30AE] = "\227\130\173\227\130\153", -- ギ = U+30AD + U+3099
  [0x30B0] = "\227\130\175\227\130\153", -- グ = U+30AF + U+3099
  [0x30B2] = "\227\130\177\227\130\153", -- ゲ = U+30B1 + U+3099
  [0x30B4] = "\227\130\179\227\130\153", -- ゴ = U+30B3 + U+3099
  [0x30B6] = "\227\130\181\227\130\153", -- ザ = U+30B5 + U+3099
  [0x30B8] = "\227\130\183\227\130\153", -- ジ = U+30B7 + U+3099
  [0x30BA] = "\227\130\185\227\130\153", -- ズ = U+30B9 + U+3099
  [0x30BC] = "\227\130\187\227\130\153", -- ゼ = U+30BB + U+3099
  [0x30BE] = "\227\130\189\227\130\153", -- ゾ = U+30BD + U+3099
  [0x30C0] = "\227\130\191\227\130\153", -- ダ = U+30BF + U+3099
  [0x30C2] = "\227\131\129\227\130\153", -- ヂ = U+30C1 + U+3099
  [0x30C5] = "\227\131\132\227\130\153", -- ヅ = U+30C4 + U+3099
  [0x30C7] = "\227\131\134\227\130\153", -- デ = U+30C6 + U+3099
  [0x30C9] = "\227\131\136\227\130\153", -- ド = U+30C8 + U+3099
  [0x30D0] = "\227\131\143\227\130\153", -- バ = U+30CF + U+3099
  [0x30D1] = "\227\131\143\227\130\154", -- パ = U+30CF + U+309A
  [0x30D3] = "\227\131\146\227\130\153", -- ビ = U+30D2 + U+3099
  [0x30D4] = "\227\131\146\227\130\154", -- ピ = U+30D2 + U+309A
  [0x30D6] = "\227\131\149\227\130\153", -- ブ = U+30D5 + U+3099
  [0x30D7] = "\227\131\149\227\130\154", -- プ = U+30D5 + U+309A
  [0x30D9] = "\227\131\152\227\130\153", -- ベ = U+30D8 + U+3099
  [0x30DA] = "\227\131\152\227\130\154", -- ペ = U+30D8 + U+309A
  [0x30DC] = "\227\131\155\227\130\153", -- ボ = U+30DB + U+3099
  [0x30DD] = "\227\131\155\227\130\154", -- ポ = U+30DB + U+309A
  [0x30F4] = "\227\130\166\227\130\153", -- ヴ = U+30A6 + U+3099
  [0x30F7] = "\227\131\175\227\130\153", -- ヷ = U+30EF + U+3099
  [0x30F8] = "\227\131\176\227\130\153", -- ヸ = U+30F0 + U+3099
  [0x30F9] = "\227\131\177\227\130\153", -- ヹ = U+30F1 + U+3099
  [0x30FA] = "\227\131\178\227\130\153", -- ヺ = U+30F2 + U+3099
  [0x30FE] = "\227\131\189\227\130\153", -- ヾ = U+30FD + U+3099
}

M.decompose_map = decompose

--- Expand the canonical NFD form of s. Returns s unchanged when no codepoint
--- in s has a canonical decomposition (no table allocation in that case).
---
--- Implementation: scan once. On the first hit, allocate parts[] and copy the
--- preceding bytes in verbatim. Subsequent codepoints are appended either as
--- their decomposition (if present) or as their original UTF-8 bytes.
---
--- @param s string UTF-8 string
--- @return string NFD form, or s itself when no decomposition applies
function M.expand(s)
  -- Fast path: scan for the first decomposable codepoint. If none, return s
  -- unchanged with zero allocation. This is the common case for ASCII-heavy
  -- or kanji-heavy input where every character is already in NFD form.
  local n = #s
  local pos = 1
  while pos <= n do
    local cp, next_pos = utils.decode_utf8_at(s, pos)
    if cp == nil then
      return s
    end
    if decompose[cp] then
      break
    end
    pos = next_pos
  end

  if pos > n then
    return s
  end

  -- Slow path: build the decomposed string. Copy the unchanged prefix
  -- verbatim, then walk the remaining codepoints expanding as needed.
  local parts = { s:sub(1, pos - 1) }
  while pos <= n do
    local cp, next_pos = utils.decode_utf8_at(s, pos)
    if cp == nil then
      break
    end
    local d = decompose[cp]
    if d then
      parts[#parts + 1] = d
    else
      parts[#parts + 1] = s:sub(pos, next_pos - 1)
    end
    pos = next_pos
  end
  return table.concat(parts)
end

return M
