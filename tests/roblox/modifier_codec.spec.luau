local codec = require("@mod/modifier_codec")

local function assertEqual(actual: unknown, expected: unknown, label: string)
  assert(actual == expected, `{label}: expected {tostring(expected)}, got {tostring(actual)}`)
end

local function roundTrip(v: any): any
  local q = { v = 1, queue = { { kind = "tween", chain = false, start = { t = "lit", v = v } } } }
  return codec.decode(codec.encode(q :: any)).queue[1].start.v
end

-- pins z's color3 quantization against the real engine color3, a stronger claim
-- than the lune spec's pin against lune's own emulated color3
return {
  {
    name = "quantizes an endpoint colour to the nearest 8-bit-per-channel value",
    run = function()
      local back = roundTrip(Color3.new(0.25, 0.5, 0.75))
      assertEqual(back, Color3.fromRGB(64, 128, 191), "quantized color")
    end,
  },

  {
    name = "re-encoding a quantized colour does not drift further",
    run = function()
      local once = roundTrip(Color3.new(0.25, 0.5, 0.75))
      local twice = roundTrip(once)
      assertEqual(twice, once, "twice-encoded color")
    end,
  },

  {
    name = "round-trips a gradient's raw stop array with real colors and exact times",
    run = function()
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
          },
        },
      }
      local m = codec.decode(codec.encode(q :: any)).queue[1]
      assertEqual(#m.stops, 2, "stop count")
      assertEqual(m.stops[1].color, Color3.new(1, 0, 0), "stop 1 color")
      assertEqual(m.stops[1].time, 0, "stop 1 time")
      assertEqual(m.stops[2].color, Color3.new(0, 1, 0), "stop 2 color")
      assertEqual(m.stops[2].time, 0.5, "stop 2 time")
      assertEqual(m.stops[2].alpha, 0.25, "stop 2 alpha")
    end,
  },
}
