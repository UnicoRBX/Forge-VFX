local roblox = require("@lune/roblox") :: any

-- assigned bare rather than into a table, because lune propagates bare globals
-- into plainly required chunks. that is what lets modules under test and the
-- vendored Z see Color3 with no environment plumbing
-- this project's roblox.yml std (the stock generated Roblox library) is
-- roblox-based, so selene treats these names as read-only standard library
-- globals; both lints are the cost of that choice
-- selene: allow(unscoped_variables, incorrect_standard_library_use)
do
  CFrame = roblox.CFrame
  Color3 = roblox.Color3
  Rect = roblox.Rect
  UDim = roblox.UDim
  UDim2 = roblox.UDim2
  Vector2 = roblox.Vector2
  Vector3 = roblox.Vector3
  NumberRange = roblox.NumberRange
  ColorSequence = roblox.ColorSequence
  NumberSequence = roblox.NumberSequence
  ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
  NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
end

-- specs destructure from here rather than relying on the globals, which keeps
-- their dependencies visible at the top of the file. Instance is included; it is
-- a side-effecting constructor and deliberately not a bare global
local datatypes: { [string]: any } = {
  CFrame = roblox.CFrame,
  Color3 = roblox.Color3,
  Rect = roblox.Rect,
  UDim = roblox.UDim,
  UDim2 = roblox.UDim2,
  Vector2 = roblox.Vector2,
  Vector3 = roblox.Vector3,
  Instance = roblox.Instance,
  NumberRange = roblox.NumberRange,
  ColorSequence = roblox.ColorSequence,
  NumberSequence = roblox.NumberSequence,
  ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
  NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
}

--------------------------------------------------------------------------------
-- tiniest pin
--------------------------------------------------------------------------------

local tiniest = require("@tiniest/src/tiniest_for_lune").configure({
  pretty = {},
})

local collected: { () -> () } = {}

local function deepEqual(a: any, b: any): boolean
  if a == b then
    return true
  end

  if typeof(a) ~= "table" or typeof(b) ~= "table" then
    -- buffers: compare byte content
    if typeof(a) == "buffer" and typeof(b) == "buffer" then
      return buffer.tostring(a) == buffer.tostring(b)
    end

    return false
  end

  for k, v in a do
    if not deepEqual(v, (b :: any)[k]) then
      return false
    end
  end

  for k in b do
    if (a :: any)[k] == nil then
      return false
    end
  end

  return true
end

local harness = {}

-- roblox datatype constructors (Vector2, Vector3, CFrame, NumberSequence, ...)
-- for specs to destructure explicitly, e.g.
-- `local NumberSequence = harness.datatypes.NumberSequence`
--
-- Instance is here but deliberately not a bare global: Instance.new is a
-- side-effecting constructor, and vendored code under test has dead
-- Instance.new branches that must not become reachable
harness.datatypes = datatypes

-- stand-in for EncodingService's zstd, for specs that exercise modifier_frame's
-- compressed encoding. a toy run-length coder: like zstd it shrinks repetitive
-- input (a real modifier queue is largely zero runs) and grows short
-- unrepetitive input, so both branches of frame's pick-the-smaller are
-- reachable headlessly. not a compressor anyone should reuse
harness.fakeCompression = {
  compress = function(buf: buffer): buffer
    local runs = {}
    local len = buffer.len(buf)
    local i = 0

    while i < len do
      local byte = buffer.readu8(buf, i)
      local run = 1

      while run < 255 and i + run < len and buffer.readu8(buf, i + run) == byte do
        run += 1
      end

      table.insert(runs, string.char(run, byte))
      i += run
    end

    return buffer.fromstring(table.concat(runs))
  end,

  -- an odd length cannot be a run/byte pair sequence, which stands in for the
  -- real codec's corrupt-input detection
  decompress = function(buf: buffer): buffer?
    local len = buffer.len(buf)

    if len % 2 ~= 0 then
      return nil
    end

    local out = {}

    for i = 0, len - 1, 2 do
      table.insert(out, string.rep(string.char(buffer.readu8(buf, i + 1)), buffer.readu8(buf, i)))
    end

    return buffer.fromstring(table.concat(out))
  end,
}

function harness.describe(name: string, body: () -> ())
  tiniest.describe(name, body)
end

function harness.test(name: string, body: () -> ())
  tiniest.test(name, body)
end

function harness.expect(actual: any)
  return {
    toBe = function(expected: any)
      assert(actual == expected, `expected {tostring(actual)} to be {tostring(expected)}`)
    end,
    toEqual = function(expected: any)
      assert(deepEqual(actual, expected), `values not deeply equal`)
    end,
    toThrow = function()
      assert(not pcall(actual), "expected function to throw")
    end,
    ok = function()
      assert(actual, `expected truthy, got {tostring(actual)}`)
    end,
  }
end

function harness.suite(fn: () -> ())
  table.insert(collected, fn)
end

function harness.run(): number
  local tests = tiniest.collect_tests(function()
    for _, fn in collected do
      fn()
    end
  end)
  local result = tiniest.run_tests(tests, {})
  return if result.status_tally.fail > 0 then 1 else 0
end

return harness
