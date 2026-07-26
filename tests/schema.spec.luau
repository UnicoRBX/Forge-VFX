local Schema = require("@root/schema")
local harness = require("@tests/harness")
local test, expect = harness.test, harness.expect

local function deepCopy(t: any): any
  if type(t) ~= "table" then
    return t
  end
  local copy = {}
  for k, v in t do
    copy[k] = deepCopy(v)
  end
  return copy
end

local function good()
  return {
    schema = 1,
    effect = "particle",
    display_name = "Particle",
    entries = {
      {
        title = "Behavior",
        entries = {
          {
            name = "Timescale",
            display_name = "TimeScale",
            type = "number",
            details = { short = "s", long = "l" },
            kind = "value",
          },
        },
      },
    },
  }
end

local valid = {
  schema = 1,
  effect = "test_effect",
  display_name = "Test",
  entries = {
    {
      name = "Speed",
      display_name = "Speed",
      type = "number",
      kind = "value",
      details = { short = "s", long = "l" },
      default = 1,
    },
    {
      title = "Group",
      entries = {
        {
          name = "Enabled",
          display_name = "Enabled",
          type = "boolean",
          kind = "value",
          details = { short = "s", long = "l" },
          default = false,
        },
      },
    },
    -- interleaving: a row AFTER a group must be legal
    {
      name = "After",
      display_name = "After",
      type = "number",
      kind = "value",
      details = { short = "s", long = "l" },
      default = 0,
    },
  },
}

harness.suite(function()
  harness.describe("schema", function()
    test("accepts a valid descriptor", function()
      local ok = Schema.validate(good())
      expect(ok).toBe(true)
    end)
    test("rejects a newer major schema version", function()
      local d = good()
      d.schema = 999
      local ok = Schema.validate(d)
      expect(ok).toBe(false)
    end)
    test("rejects a row missing required fields", function()
      local d = good()
      d.entries[1].entries[1].display_name = nil
      local ok = Schema.validate(d)
      expect(ok).toBe(false)
    end)
    test("register/get round-trips and preserves unknown fields", function()
      local d = good()
      d.entries[1].entries[1].future = "keepme"
      Schema.register(d)
      local got = Schema.get("particle")
      expect(got.entries[1].entries[1].future).toBe("keepme")
    end)
    test("returns false (not error) when entries is not a table", function()
      local d = good()
      d.entries[1].entries = "not-a-table" :: any
      local ok = Schema.validate(d)
      expect(ok).toBe(false)
      local d2 = good()
      d2.entries = 5 :: any
      local ok2 = Schema.validate(d2)
      expect(ok2).toBe(false)
    end)

    test("accepts interleaved rows and groups in entries", function()
      expect(Schema.validate(valid)).toBe(true)
    end)

    test("rejects a dictionary-shaped entries table", function()
      local d = deepCopy(valid)
      d.entries = { Speed = d.entries[1] }
      local ok, why = Schema.validate(d)
      expect(ok).toBe(false)
      expect(why).ok()
    end)

    test("rejects an entry that is neither row nor group", function()
      local d = deepCopy(valid)
      d.entries[1] = { display_name = "Nameless" }
      local ok = Schema.validate(d)
      expect(ok).toBe(false)
    end)

    test("rejects an entry claiming to be both row and group", function()
      local d = deepCopy(valid)
      d.entries[1] = {
        name = "X",
        title = "X",
        display_name = "X",
        type = "number",
        kind = "value",
        details = { short = "s", long = "l" },
      }
      local ok = Schema.validate(d)
      expect(ok).toBe(false)
    end)

    test("rejects any function anywhere in the descriptor (data-only)", function()
      local d = deepCopy(valid)
      d.entries[2].entries[1].on_click = function() end
      local ok = Schema.validate(d)
      expect(ok).toBe(false)
      local d2 = deepCopy(valid)
      d2.custom = { nested = { fn = function() end } }
      local ok2 = Schema.validate(d2)
      expect(ok2).toBe(false)
    end)
  end)
end)
