--!strict
local Schema = require("@root/schema")
local harness = require("@tests/harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function base()
  return {
    schema = 1,
    effect = "t",
    display_name = "T",
    entries = {},
  }
end

harness.suite(function()
  describe("schema curves", function()
    test("descriptor without curves validates", function()
      local ok = Schema.validate(base())
      expect(ok).toBe(true)
    end)

    test("valid sequence-target curve leaf validates", function()
      local d = base()
      d.curves = {
        {
          name = "Transparency",
          short = "s",
          target = { kind = "sequence", prop = "Transparency", min = 0, max = 1 },
          inputs = { { name = "Start", default = 0, min = 0, max = 1 } },
        },
      }
      local ok, why = Schema.validate(d)
      expect(ok).toBe(true)
      expect(why).toBe(nil)
    end)

    test("valid attribute-target curve leaf validates", function()
      local d = base()
      d.curves = { { name = "Easing", short = "s", target = { kind = "attribute", attr = "Easing_Curve" } } }
      expect(Schema.validate(d)).toBe(true)
    end)

    test("valid curve group validates", function()
      local d = base()
      d.curves = {
        {
          name = "Base",
          short = "s",
          entries = {
            { name = "Start", short = "s", target = { kind = "attribute", attr = "A_Curve" } },
          },
        },
      }
      expect(Schema.validate(d)).toBe(true)
    end)

    test("curve entry with bad target kind is rejected", function()
      local d = base()
      d.curves = { { name = "X", short = "s", target = { kind = "bogus" } } }
      local ok, why = Schema.validate(d)
      expect(ok).toBe(false)
      expect(typeof(why)).toBe("string")
    end)

    test("curve entry that is neither leaf nor group is rejected", function()
      local d = base()
      d.curves = { { name = "X", short = "s" } }
      expect(Schema.validate(d)).toBe(false)
    end)

    test("curves containing a function is rejected (data-only)", function()
      local d = base()
      d.curves = { { name = "X", short = "s", target = { kind = "attribute", attr = "A" }, handler = function() end } }
      expect(Schema.validate(d)).toBe(false)
    end)

    test("curves must be an array", function()
      local d = base()
      d.curves = { foo = "bar" }
      expect(Schema.validate(d)).toBe(false)
    end)
  end)
end)
