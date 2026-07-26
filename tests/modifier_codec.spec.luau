local codec = require("@mod/modifier_codec")
local harness = require("@tests/harness")
local test, expect = harness.test, harness.expect
local Color3, NumberSequence = harness.datatypes.Color3, harness.datatypes.NumberSequence
local Instance = harness.datatypes.Instance

local function curve(): buffer
  return buffer.fromstring("CURVEBYTES")
end

harness.suite(function()
  harness.describe("modifier_codec", function()
    test("decode rejects a payload that is not a queue at all", function()
      expect(function()
        codec.decode(buffer.fromstring("not a queue"))
      end).toThrow()
    end)

    test("decode rejects a newer queue version", function()
      local newer = codec.encode({ v = 2, queue = {} } :: any)
      expect(function()
        codec.decode(newer)
      end).toThrow()
    end)

    test("decode rejects a payload truncated mid-modifier", function()
      local full = codec.encode({
        v = 1,
        queue = { { kind = "tween", chain = false, curve = buffer.fromstring("CURVEBYTES") } },
      } :: any)
      local cut = buffer.create(buffer.len(full) - 4)
      buffer.copy(cut, 0, full, 0, buffer.len(cut))
      expect(function()
        codec.decode(cut)
      end).toThrow()
    end)

    test("encode rejects a queue whose queue field is not a table", function()
      expect(function()
        codec.encode({ v = 1, queue = "nope" } :: any)
      end).toThrow()
    end)

    test("encode names a type it cannot represent rather than dropping it", function()
      local q =
        { v = 1, queue = { { kind = "tween", chain = false, start = { t = "lit", v = Instance.new("Folder") } } } }
      expect(function()
        codec.encode(q :: any)
      end).toThrow()
    end)

    test("round-trips a mixed queue (datatypes + curve buffer)", function()
      local q = {
        v = 1,
        queue = {
          {
            kind = "tween",
            chain = false,
            duration = 2,
            start = { t = "lit", v = Color3.new(1, 0, 0) },
            finish = { t = "lit", v = Color3.new(0, 1, 0) },
            curve = curve(),
          },
          {
            kind = "randomizer",
            chain = true,
            start = { t = "lit", v = NumberSequence.new(0) },
            finish = { t = "lit", v = NumberSequence.new(1) },
            weight = curve(),
          },
        },
      }
      local d = codec.decode(codec.encode(q))
      expect(d.v).toBe(1)
      expect(d.queue[1].kind).toBe("tween")
      expect(d.queue[1].duration).toBe(2)
      expect(d.queue[1].start.v).toBe(Color3.new(1, 0, 0))
      expect(d.queue[1].finish.v).toBe(Color3.new(0, 1, 0))
      expect(buffer.tostring(d.queue[1].curve)).toBe("CURVEBYTES")
      expect(d.queue[2].chain).toBe(true)
      expect(d.queue[2].start.v).toBe(NumberSequence.new(0))
    end)

    test("preserves unknown modifier kind and unknown fields", function()
      local q = { v = 1, queue = { { kind = "future_kind", chain = false, custom = 42 } } }
      local d = codec.decode(codec.encode(q))
      expect(d.queue[1].kind).toBe("future_kind")
      expect(d.queue[1].custom).toBe(42)
    end)

    test("empty() is a valid, encodable empty queue", function()
      local d = codec.decode(codec.encode(codec.empty()))
      expect(d.v).toBe(1)
      expect(#d.queue).toBe(0)
    end)

    local function roundTrip(v: any): any
      local q = { v = 1, queue = { { kind = "tween", chain = false, start = { t = "lit", v = v } } } }
      return codec.decode(codec.encode(q :: any)).queue[1].start.v
    end

    test("round-trips the exactly-representable endpoint datatypes", function()
      local d = harness.datatypes
      local cases = {
        d.Vector2.new(1.5, -2.5),
        d.Vector3.new(1.5, -2.5, 3.5),
        d.UDim.new(0.5, -12),
        d.UDim2.new(0.25, 4, 0.75, -8),
        d.NumberRange.new(2, 7),
        d.NumberSequence.new(0.25),
        123.456,
        true,
        "a string endpoint",
      }

      for _, v in cases do
        local back = roundTrip(v)
        expect(typeof(back)).toBe(typeof(v))
        expect(back).toBe(v)
      end
    end)

    -- Z stores a Color3 as three bytes via Color3.fromRGB, so an endpoint colour
    -- lands on the nearest 8-bit-per-channel colour. Pinned deliberately: it is
    -- the sRGB output resolution and quantizing is idempotent (a second round
    -- trip does not drift further), but it IS lossier than the engine's own
    -- float Color3, so a change here should be a decision and not a surprise.
    test("quantizes an endpoint colour to 8 bits per channel", function()
      local Color3 = harness.datatypes.Color3
      local back = roundTrip(Color3.new(0.25, 0.5, 0.75))
      expect(typeof(back)).toBe("Color3")
      expect(back).toBe(Color3.fromRGB(64, 128, 191))
      expect(roundTrip(back)).toBe(back)
    end)

    test("round-trips a raw array of maps, which is how a gradient stores stops", function()
      local Color3 = harness.datatypes.Color3
      local q = {
        v = 1,
        queue = {
          {
            kind = "gradient",
            chain = false,
            stops = {
              { time = 0, color = Color3.new(1, 0, 0), alpha = 0 },
              { time = 0.5, color = Color3.new(0, 1, 0), alpha = 0.25 },
            },
            blend = "linear",
          },
        },
      }
      local m = codec.decode(codec.encode(q :: any)).queue[1]
      expect(#m.stops).toBe(2)
      expect(m.stops[1].color).toBe(Color3.new(1, 0, 0))
      expect(m.stops[2].time).toBe(0.5)
      expect(m.stops[2].alpha).toBe(0.25)
      expect(m.blend).toBe("linear")
    end)

    test("round-trips field names and string values outside the dictionary", function()
      local q = {
        v = 1,
        queue = { { kind = "future_kind", chain = false, some_unlisted_field = "an unlisted value" } },
      }
      local m = codec.decode(codec.encode(q :: any)).queue[1]
      expect(m.kind).toBe("future_kind")
      expect(m.some_unlisted_field).toBe("an unlisted value")
    end)

    test("the same queue always encodes to the same bytes", function()
      local function build()
        return {
          v = 1,
          queue = {
            { kind = "tween", chain = false, duration = 2, zzz = 1, aaa = 2, start = { t = "lit", v = 3 } },
          },
        }
      end
      expect(buffer.tostring(codec.encode(build() :: any))).toBe(buffer.tostring(codec.encode(build() :: any)))
    end)

    test("round-trips a var Value, an unknown tagged Value, and an envelope buffer", function()
      local q = {
        v = 1,
        queue = {
          {
            kind = "tween",
            chain = false,
            start = { t = "var", ref = "MyVar" },
            finish = { t = "future_tag", custom_field = 1 },
            envelope = buffer.fromstring("ENVBYTES"),
          },
        },
      }
      local d = codec.decode(codec.encode(q))
      local m = d.queue[1]
      expect(m.start.t).toBe("var")
      expect(m.start.ref).toBe("MyVar")
      expect(m.finish.t).toBe("future_tag")
      expect(m.finish.custom_field).toBe(1)
      expect(buffer.tostring(m.envelope)).toBe("ENVBYTES")
    end)
  end)
end)
