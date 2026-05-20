describe("luamigemo.nfd", function()
  local nfd = require "luamigemo.nfd"

  describe("expand()", function()
    it("returns the input unchanged when no codepoint decomposes", function()
      assert.equal("", nfd.expand "")
      assert.equal("abc", nfd.expand "abc")
      assert.equal("hello world", nfd.expand "hello world")
      -- hiragana without voicing
      assert.equal("あいうえお", nfd.expand "あいうえお")
      -- katakana without voicing
      assert.equal("カキクケコ", nfd.expand "カキクケコ")
      -- kanji
      assert.equal("漢字", nfd.expand "漢字")
    end)

    it("returns the SAME string object (no allocation) on the unchanged path", function()
      local s = "abc"
      assert.is_true(nfd.expand(s) == s)
      local jp = "あいうえお"
      assert.is_true(nfd.expand(jp) == jp)
    end)

    it("expands voiced hiragana into base + U+3099", function()
      -- が = か (U+304B) + ◌゙ (U+3099) → 6 bytes UTF-8
      assert.equal("\227\129\139\227\130\153", nfd.expand "が")
      assert.equal("\227\129\141\227\130\153", nfd.expand "ぎ")
      assert.equal("\227\129\187\227\130\153", nfd.expand "ぼ")
    end)

    it("expands semi-voiced hiragana into base + U+309A", function()
      -- ぱ = は (U+306F) + ◌゚ (U+309A)
      assert.equal("\227\129\175\227\130\154", nfd.expand "ぱ")
      assert.equal("\227\129\187\227\130\154", nfd.expand "ぽ")
    end)

    it("expands voiced katakana", function()
      -- ブ = フ (U+30D5) + ◌゙
      assert.equal("\227\131\149\227\130\153", nfd.expand "ブ")
      -- ヴ = ウ + ◌゙
      assert.equal("\227\130\166\227\130\153", nfd.expand "ヴ")
    end)

    it("expands multi-char strings, preserving non-decomposable codepoints", function()
      -- サブ: サ stays, ブ expands
      assert.equal("\227\130\181\227\131\149\227\130\153", nfd.expand "サブ")
      -- abcサブdef: ASCII bracketing preserved
      assert.equal("abc\227\130\181\227\131\149\227\130\153def", nfd.expand "abcサブdef")
      -- mixed kanji + voiced kana
      assert.equal("漢\227\129\139\227\130\153字", nfd.expand "漢が字")
    end)

    it("is idempotent on already-decomposed input", function()
      local nfd_form = nfd.expand "サブ"
      assert.equal(nfd_form, nfd.expand(nfd_form))

      local complex = nfd.expand "ガギグゲゴ"
      assert.equal(complex, nfd.expand(complex))
    end)

    it("expands all entries in the decompose_map", function()
      -- Each entry's NFC form should decompose into the corresponding NFD bytes
      for cp, expected in pairs(nfd.decompose_map) do
        local utf8_char
        if cp < 0x80 then
          utf8_char = string.char(cp)
        elseif cp < 0x800 then
          utf8_char = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
        else
          utf8_char = string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
        end
        assert.equal(expected, nfd.expand(utf8_char), string.format("U+%04X should decompose", cp))
      end
    end)
  end)
end)
