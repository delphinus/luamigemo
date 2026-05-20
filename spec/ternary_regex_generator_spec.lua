describe("luamigemo.ternary_regex_generator", function()
  local TRG = require "luamigemo.ternary_regex_generator"
  local luamigemo = require "luamigemo"
  local RXOP_PCRE = luamigemo.RXOP_PCRE
  local RXOP_VIM = luamigemo.RXOP_VIM

  describe(":add() default mode", function()
    it("inserts a single word and generates a literal regex", function()
      local g = TRG.new(RXOP_PCRE)
      g:add "abc"
      assert.equal("abc", g:generate())
    end)

    it("collapses common prefixes via the trie", function()
      local g = TRG.new(RXOP_PCRE)
      g:add "abc"
      g:add "abd"
      -- ab + (c|d) → ab[cd]
      assert.equal("ab[cd]", g:generate())
    end)

    it("handles NFC kana without expansion", function()
      local g = TRG.new(RXOP_PCRE)
      g:add "サブ"
      assert.equal("サブ", g:generate())
    end)
  end)

  describe(":add() with nfd_tolerant = true", function()
    it("inserts the NFD variant alongside the NFC input", function()
      local g = TRG.new(RXOP_PCRE, true)
      g:add "サブ"
      -- Expected: サ(?:ブ|フ◌゙) — both NFC and NFD branches present
      local out = g:generate()
      -- Match the NFD branch literally
      assert.is_truthy(
        out:find("\227\131\149\227\130\153", 1, true),
        "NFD bytes 'フ + U+3099' should appear in the regex"
      )
      -- Match the NFC branch literally
      assert.is_truthy(out:find("\227\131\150", 1, true), "NFC byte 'ブ' should appear in the regex")
    end)

    it("does not duplicate when input has no decomposable chars", function()
      local g_default = TRG.new(RXOP_PCRE)
      g_default:add "あいうえお"
      local g_nfd = TRG.new(RXOP_PCRE, true)
      g_nfd:add "あいうえお"
      -- No decomposable chars → both regexes should be identical
      assert.equal(g_default:generate(), g_nfd:generate())
    end)

    it("is idempotent: adding an NFD form does not re-expand", function()
      local nfd = require "luamigemo.nfd"
      local g = TRG.new(RXOP_PCRE, true)
      g:add(nfd.expand "サブ")
      local out = g:generate()
      -- Only the NFD form should appear since it's already decomposed
      -- and the recursive :add(form) in NFD path bails because form == word
      assert.is_truthy(out:find("\227\131\149\227\130\153", 1, true))
    end)

    it("nfd_tolerant defaults to false", function()
      local g = TRG.new(RXOP_PCRE)
      assert.is_false(g.nfd)
      local g_nil = TRG.new(RXOP_PCRE, nil)
      assert.is_false(g_nil.nfd)
      local g_false = TRG.new(RXOP_PCRE, false)
      assert.is_false(g_false.nfd)
    end)

    it("Vim regex output is well-formed for sabu-style queries", function()
      local g = TRG.new(RXOP_VIM, true)
      g:add "サブ"
      g:add "さぶ"
      local out = g:generate()
      -- Should contain the trie-grouped form ending in \)
      assert.is_truthy(out:find("\\%(", 1, true))
      assert.is_truthy(out:find("\\)", 1, true))
    end)
  end)
end)
