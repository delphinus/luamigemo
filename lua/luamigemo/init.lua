local CompactDictionary = require "luamigemo.compact_dictionary"
local RomajiProcessor = require "luamigemo.romaji_processor"
local TernaryRegexGenerator = require "luamigemo.ternary_regex_generator"
local cc = require "luamigemo.character_converter"

--- Resolve the path to the bundled dictionary file.
--- Uses debug.getinfo to find the plugin root, independent of vim.* APIs.
--- @return string|nil
local function resolve_bundled_dict()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) ~= "@" then
    return nil
  end
  -- this_file: /path/to/luamigemo/lua/luamigemo/init.lua
  local dir = source:sub(2)
  for _ = 1, 3 do
    dir = dir:match "^(.*)[/\\][^/\\]+$"
    if not dir then
      return nil
    end
  end
  local dict_path = dir .. "/dict/migemo-compact-dict"
  local f = io.open(dict_path, "rb")
  if f then
    f:close()
    return dict_path
  end
  return nil
end

local _bundled_dict_path = resolve_bundled_dict()

local M = {}

--- rxop format: {or, beginGroup, endGroup, beginClass, endClass, newline, escape}
M.RXOP_VIM = { "\\|", "\\%(", "\\)", "[", "]", "", "\\.[]*~^$" }
M.RXOP_PCRE = { "|", "(?:", ")", "[", "]", "", "\\.[]{}()*+-?^$|" }
M.VIM_PREFIX = "\\m"

local Migemo = {}
Migemo.__index = Migemo

function Migemo.new()
  local self = setmetatable({}, Migemo)
  self.dict = nil
  self.processor = RomajiProcessor.build()
  -- Query result cache: rxop table → { word → pattern string }
  self._query_cache = {}
  return self
end

function Migemo:set_dict(dict)
  self.dict = dict
end

--- @param word string
--- @param rxop table|nil rxop format table. Defaults to M.RXOP_PCRE.
--- @param use_dict boolean|nil Whether to use dictionary lookup. Defaults to true.
function Migemo:query_a_word(word, rxop, use_dict)
  rxop = rxop or M.RXOP_PCRE
  if use_dict == nil then
    use_dict = true
  end
  local cache_for_rxop = self._query_cache[rxop]
  if cache_for_rxop and use_dict then
    local cached = cache_for_rxop[word]
    if cached then
      return cached
    end
  elseif not cache_for_rxop then
    cache_for_rxop = {}
    self._query_cache[rxop] = cache_for_rxop
  end

  local generator = TernaryRegexGenerator.new(rxop)
  generator:add(word)

  local lower = word:lower()
  if use_dict and self.dict then
    local results = self.dict:predictive_search_results(lower)
    for _, w in ipairs(results) do
      generator:add(w)
    end
  end

  generator:add(cc.han2zen(word))
  generator:add(cc.zen2han(word))

  local result = self.processor:romaji_to_hiragana_predictively(lower)
  for _, suffix in ipairs(result.suffixes) do
    local hira = result.prefix .. suffix
    generator:add(hira)
    if use_dict and self.dict then
      local hira_results = self.dict:predictive_search_results(hira)
      for _, w in ipairs(hira_results) do
        generator:add(w)
      end
    end
    local kata = cc.hira2kata(hira)
    generator:add(kata)
    generator:add(cc.zen2han(kata))
  end

  local pattern = generator:generate()
  if use_dict then
    cache_for_rxop[word] = pattern
  end
  return pattern
end

--- @param word string
--- @param rxop table|nil rxop format table. Defaults to M.RXOP_PCRE.
--- @param use_dict boolean|nil Whether to use dictionary lookup. Defaults to true.
function Migemo:query(word, rxop, use_dict)
  if word == "" then
    return ""
  end
  local words = Migemo.parse_query(word)
  local parts = {}
  for _, w in ipairs(words) do
    parts[#parts + 1] = self:query_a_word(w, rxop, use_dict)
  end
  return table.concat(parts)
end

--- Split a query string into words (handles camelCase and spaces).
function Migemo.parse_query(query)
  local words = {}
  local i = 1
  while i <= #query do
    local c = query:byte(i)
    if c == 0x20 or c == 0x09 or c == 0x0A or c == 0x0D then
      i = i + 1
    elseif c >= 0x41 and c <= 0x5A then
      local j = i + 1
      while j <= #query and query:byte(j) >= 0x41 and query:byte(j) <= 0x5A do
        j = j + 1
      end
      if j > i + 1 then
        words[#words + 1] = query:sub(i, j - 1)
        i = j
      else
        while j <= #query do
          local cj = query:byte(j)
          if (cj >= 0x41 and cj <= 0x5A) or cj == 0x20 or cj == 0x09 or cj == 0x0A or cj == 0x0D then
            break
          end
          j = j + 1
        end
        words[#words + 1] = query:sub(i, j - 1)
        i = j
      end
    else
      local j = i + 1
      while j <= #query do
        local cj = query:byte(j)
        if (cj >= 0x41 and cj <= 0x5A) or cj == 0x20 or cj == 0x09 or cj == 0x0A or cj == 0x0D then
          break
        end
        j = j + 1
      end
      words[#words + 1] = query:sub(i, j - 1)
      i = j
    end
  end
  return words
end

-- Singleton management

local _instance = nil
local _dict_path = nil

--- Get or create the singleton Migemo instance.
--- @param dict_path string|nil Path to migemo-compact-dict. nil uses bundled dict.
--- @return table Migemo instance
function M.get(dict_path)
  if dict_path == nil then
    dict_path = _bundled_dict_path
  end
  if _instance and _dict_path == dict_path then
    return _instance
  end
  local migemo = Migemo.new()
  if dict_path then
    migemo:set_dict(CompactDictionary.load(dict_path))
  end
  _instance = migemo
  _dict_path = dict_path
  return migemo
end

--- Query using the default singleton instance.
--- @param word string Input romaji
--- @param rxop table|nil rxop format table. Defaults to M.RXOP_PCRE.
--- @param use_dict boolean|nil Whether to use dictionary lookup. Defaults to true.
--- @return string regex pattern
function M.query(word, rxop, use_dict)
  local migemo = M.get()
  return migemo:query(word, rxop, use_dict)
end

--- Return the path to the bundled dictionary, or nil if not found.
--- @return string|nil
function M.bundled_dict_path()
  return _bundled_dict_path
end

--- Return the currently active dictionary path, or nil if none loaded.
--- @return string|nil
function M.active_dict_path()
  return _dict_path
end

return M
