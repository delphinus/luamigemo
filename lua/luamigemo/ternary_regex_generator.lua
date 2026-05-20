local BitList = require "luamigemo.bit_list"
local nfd = require "luamigemo.nfd"
local utils = require "luamigemo.utils"

local TernaryRegexGenerator = {}
TernaryRegexGenerator.__index = TernaryRegexGenerator

--- @param rxop table {or, begin_group, end_group, begin_class, end_class, newline, escape}
--- @param nfd_tolerant boolean|nil when true, each :add(w) also inserts the
---   canonical NFD form of w so the generated regex matches both NFC and NFD
---   text. Default false; the default-off path is unchanged from prior versions.
function TernaryRegexGenerator.new(rxop, nfd_tolerant)
  local self = setmetatable({}, TernaryRegexGenerator)
  self.or_op = rxop[1]
  self.begin_group = rxop[2]
  self.end_group = rxop[3]
  self.begin_class = rxop[4]
  self.end_class = rxop[5]
  self.newline = rxop[6]
  self.escape_chars = TernaryRegexGenerator._init_escape(rxop[7])
  self.root = nil
  self.nfd = nfd_tolerant == true
  return self
end

function TernaryRegexGenerator._init_escape(escape)
  local bits = BitList.new(128)
  for i = 1, #escape do
    local c = escape:byte(i)
    if c < 128 then
      bits:set(c, true)
    end
  end
  return bits
end

-- AA-tree operations

local function skew(t)
  if t == nil or t.left == nil then
    return t
  end
  if t.left.level == t.level then
    local l = t.left
    t.left = l.right
    l.right = t
    return l
  end
  return t
end

local function split(t)
  if t == nil or t.right == nil or t.right.right == nil then
    return t
  end
  if t.level == t.right.right.level then
    local r = t.right
    t.right = r.left
    r.left = t
    r.level = r.level + 1
    return r
  end
  return t
end

-- Pre-allocated buffers for iterative insert (avoids per-call table allocation).
-- Max AA-tree depth is O(log n); 32 is more than enough.
local _insert_path = {}
local _insert_dirs = {} -- 1 = left, 2 = right

--- Iterative AA-tree insertion. Avoids recursive calls that prevent LuaJIT JIT compilation.
local function insert_node(x, root)
  if root == nil then
    local r = { value = x, child = nil, left = nil, right = nil, level = 1 }
    return r, r, true
  end

  -- Phase 1: descend to find insertion point
  local path = _insert_path
  local dirs = _insert_dirs
  local n = 0
  local t = root

  while true do
    if x == t.value then
      return root, t, false
    end
    n = n + 1
    path[n] = t
    if x < t.value then
      dirs[n] = 1
      if t.left == nil then
        break
      end
      t = t.left
    else
      dirs[n] = 2
      if t.right == nil then
        break
      end
      t = t.right
    end
  end

  -- Phase 2: attach new node
  local new_node = { value = x, child = nil, left = nil, right = nil, level = 1 }
  if dirs[n] == 1 then
    path[n].left = new_node
  else
    path[n].right = new_node
  end

  -- Phase 3: walk back up, applying skew and split
  for i = n, 1, -1 do
    t = path[i]
    t = skew(t)
    t = split(t)
    if i > 1 then
      if dirs[i - 1] == 1 then
        path[i - 1].left = t
      else
        path[i - 1].right = t
      end
    else
      root = t
    end
    path[i] = nil -- clear for GC
  end

  return root, new_node, true
end

local function traverse_siblings(node, results)
  if node ~= nil then
    traverse_siblings(node.left, results)
    results[#results + 1] = node
    traverse_siblings(node.right, results)
  end
end

--- Add a word to the generator (iterative).
function TernaryRegexGenerator:add(word)
  if #word == 0 then
    return
  end

  local pos = 1
  local node = self.root
  local prev_target = nil
  local is_root = true

  while pos <= #word do
    local cp, next_pos = utils.decode_utf8_at(word, pos)
    if cp == nil then
      break
    end

    local new_node, target, inserted = insert_node(cp, node)

    -- Connect this level's (possibly rebalanced) tree root to the parent
    if is_root then
      self.root = new_node
      is_root = false
    else
      prev_target.child = new_node
    end

    if next_pos > #word then
      -- Last codepoint: set child to nil (shorter prefix subsumes longer)
      if inserted or target.child ~= nil then
        target.child = nil
      end
      break
    end

    -- More codepoints: descend into child subtree
    if not (inserted or target.child ~= nil) then
      break -- existing leaf, shorter prefix already covers this word
    end

    prev_target = target
    node = target.child
    pos = next_pos
  end

  -- NFD-tolerant path: also insert the canonical NFD form so the same trie
  -- matches dakuten/handakuten written as base + combining mark. nfd.expand
  -- is idempotent for already-decomposed input, so the recursive :add(form)
  -- bails on the second pass via the `form ~= word` guard.
  if self.nfd then
    local form = nfd.expand(word)
    if form ~= word then
      self:add(form)
    end
  end
end

function TernaryRegexGenerator:_escape_char(value)
  if value < 128 and self.escape_chars:get(value) then
    return "\\" .. utils.utf8_char(value)
  end
  return utils.utf8_char(value)
end

function TernaryRegexGenerator:generate_stub(node)
  local siblings = {}
  traverse_siblings(node, siblings)
  local brother = #siblings
  local haschild = 0
  for _, n in ipairs(siblings) do
    if n.child ~= nil then
      haschild = haschild + 1
    end
  end
  local nochild = brother - haschild

  local parts = {}

  if brother > 1 and haschild > 0 then
    parts[#parts + 1] = self.begin_group
  end

  if nochild > 0 then
    if nochild > 1 then
      parts[#parts + 1] = self.begin_class
    end
    for _, n in ipairs(siblings) do
      if n.child == nil then
        parts[#parts + 1] = self:_escape_char(n.value)
      end
    end
    if nochild > 1 then
      parts[#parts + 1] = self.end_class
    end
  end

  if haschild > 0 then
    if nochild > 0 then
      parts[#parts + 1] = self.or_op
    end
    local child_parts = {}
    for _, n in ipairs(siblings) do
      if n.child ~= nil then
        local cp = { self:_escape_char(n.value) }
        if self.newline and #self.newline > 0 then
          cp[#cp + 1] = self.newline
        end
        cp[#cp + 1] = self:generate_stub(n.child)
        child_parts[#child_parts + 1] = table.concat(cp)
      end
    end
    parts[#parts + 1] = table.concat(child_parts, self.or_op)
  end

  if brother > 1 and haschild > 0 then
    parts[#parts + 1] = self.end_group
  end

  return table.concat(parts)
end

function TernaryRegexGenerator:generate()
  if self.root == nil then
    return ""
  end
  return self:generate_stub(self.root)
end

return TernaryRegexGenerator
