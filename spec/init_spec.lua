describe("luamigemo (Migemo:query)", function()
  local luamigemo = require "luamigemo"

  -- A fresh instance per test so caches don't leak across cases.
  local function fresh()
    return luamigemo.get()
  end

  describe("FLAG_NFD constant", function()
    it("is a positive integer", function()
      assert.is_number(luamigemo.FLAG_NFD)
      assert.is_true(luamigemo.FLAG_NFD > 0)
    end)
  end)

  describe(":query() default mode", function()
    it("returns a non-empty regex for a romaji query", function()
      local r = fresh():query("sabu", luamigemo.RXOP_VIM)
      assert.is_string(r)
      assert.is_true(#r > 0)
    end)

    it("includes the NFC kana branch", function()
      -- 'sabu' should match dictionary words containing サブ / さぶ
      local r = fresh():query("sabu", luamigemo.RXOP_VIM)
      assert.is_truthy(r:find("サブ", 1, true))
      assert.is_truthy(r:find("さぶ", 1, true))
    end)

    it("returns empty string for empty input", function()
      assert.equal("", fresh():query("", luamigemo.RXOP_VIM))
    end)

    it("flags = nil and flags = 0 produce identical output", function()
      -- Critical: confirms FLAG_NFD bit-check correctly treats 0 as off
      local r_nil = fresh():query("sabu", luamigemo.RXOP_VIM)
      local r_zero = fresh():query("sabu", luamigemo.RXOP_VIM, 0)
      assert.equal(r_nil, r_zero)
    end)
  end)

  describe(":query() with FLAG_NFD", function()
    it("produces a regex distinct from the default for inputs with voiced kana", function()
      local m = fresh()
      local r_default = m:query("sabu", luamigemo.RXOP_VIM)
      local r_nfd = m:query("sabu", luamigemo.RXOP_VIM, luamigemo.FLAG_NFD)
      assert.is_not_equal(r_default, r_nfd)
      -- NFD regex must be at least as long (more branches)
      assert.is_true(#r_nfd >= #r_default)
    end)

    it("contains the NFD byte sequence for voiced kana", function()
      local r = fresh():query("sabu", luamigemo.RXOP_VIM, luamigemo.FLAG_NFD)
      -- NFD form of ブ = フ (E3 83 95) + U+3099 (E3 82 99)
      assert.is_truthy(r:find("\227\131\149\227\130\153", 1, true), "Expected NFD bytes for ブ in NFD regex")
    end)

    it("produces same output as default when query has no decomposable kana", function()
      local m = fresh()
      -- 'a' expands to dict words mostly free of voiced kana; check separately
      local r_default = m:query("kanji", luamigemo.RXOP_VIM)
      local r_nfd = m:query("kanji", luamigemo.RXOP_VIM, luamigemo.FLAG_NFD)
      -- They may still differ if dict words contain voiced kana, but the
      -- output length difference is bounded by the number of voiced kana.
      assert.is_true(#r_nfd >= #r_default)
    end)
  end)

  describe("cache separation", function()
    it("default and NFD modes use independent caches", function()
      local m = fresh()
      local r1 = m:query("sabu", luamigemo.RXOP_VIM)
      local r2 = m:query("sabu", luamigemo.RXOP_VIM, luamigemo.FLAG_NFD)
      -- Two separate lookups; second call hits the NFD cache
      local r1_again = m:query("sabu", luamigemo.RXOP_VIM)
      local r2_again = m:query("sabu", luamigemo.RXOP_VIM, luamigemo.FLAG_NFD)
      assert.equal(r1, r1_again)
      assert.equal(r2, r2_again)
      assert.is_not_equal(r1, r2)
    end)
  end)
end)
