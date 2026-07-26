local value = require("@mod/value")
local harness = require("@tests/harness")
local test, expect = harness.test, harness.expect
local Color3 = harness.datatypes.Color3

harness.suite(function()
  harness.describe("value", function()
    test("lit wraps a concrete value", function()
      local v = value.lit(Color3.new(1, 0, 0))
      expect(v.t).toBe("lit")
      expect(value.isLit(v)).toBe(true)
      expect(value.resolve(v)).toBe(Color3.new(1, 0, 0))
    end)
    test("var resolves to nil in 1A but is a valid Value", function()
      local v = { t = "var", ref = "MyVar" } :: any
      expect(value.isLit(v)).toBe(false)
      expect(value.resolve(v)).toBe(nil)
    end)
  end)
end)
