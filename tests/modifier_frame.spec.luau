local frame = require("@mod/modifier_frame")
local harness = require("@tests/harness")
local test, expect = harness.test, harness.expect

-- stand-in for EncodingService's base64: hex is enough to prove the framing
-- round-trips without reimplementing base64 in a test
local hex = {
  encode = function(buf: buffer): buffer
    local out = {}

    for i = 0, buffer.len(buf) - 1 do
      table.insert(out, string.format("%02x", buffer.readu8(buf, i)))
    end

    return buffer.fromstring(table.concat(out))
  end,

  decode = function(buf: buffer): buffer
    local s = buffer.tostring(buf)
    local out = buffer.create(#s // 2)

    for i = 1, #s, 2 do
      buffer.writeu8(out, (i - 1) // 2, tonumber(string.sub(s, i, i + 1), 16) :: number)
    end

    return out
  end,
}

frame.configure(hex, harness.fakeCompression)

harness.suite(function()
  harness.describe("modifier_frame", function()
    test("frame prefixes the encoded payload, behind a raw-storage flag byte", function()
      local framed = frame.frame(buffer.fromstring("AB"))
      expect(string.sub(framed, 1, 3)).toBe("v1:")
      expect(string.sub(framed, 4)).toBe("004142")
    end)

    test("unframe round-trips a framed payload byte for byte", function()
      local original = "QUEUE-BYTES"
      local back = frame.unframe(frame.frame(buffer.fromstring(original)))
      expect(back ~= nil).toBe(true)
      expect(buffer.tostring(back :: buffer)).toBe(original)
    end)

    test("unframe returns nil for anything that is not a framed string", function()
      expect(frame.unframe(nil)).toBe(nil)
      expect(frame.unframe(42)).toBe(nil)
      expect(frame.unframe("no prefix here")).toBe(nil)
      expect(frame.unframe("v2:4142")).toBe(nil)
    end)

    test("a payload the codec can shrink is stored compressed", function()
      local framed = frame.frame(buffer.fromstring(string.rep("A", 40)))
      expect(string.sub(framed, 4, 5)).toBe("01")
    end)

    test("a compressed payload round-trips byte for byte", function()
      local original = string.rep("A", 40) .. string.rep("\0", 24)
      local framed = frame.frame(buffer.fromstring(original))
      local back = frame.unframe(framed)
      expect(string.sub(framed, 4, 5)).toBe("01")
      expect(back ~= nil).toBe(true)
      expect(buffer.tostring(back :: buffer)).toBe(original)
    end)

    test("a payload the codec would grow stays raw", function()
      local framed = frame.frame(buffer.fromstring("ABCDEF"))
      expect(string.sub(framed, 4, 5)).toBe("00")
    end)

    test("a framed payload the compression codec cannot read returns nil", function()
      -- flag says compressed, body is a single byte, which is not a run/byte pair
      expect(frame.unframe("v1:0141")).toBe(nil)
    end)

    test("an unknown storage flag returns nil rather than guessing", function()
      expect(frame.unframe("v1:994142")).toBe(nil)
    end)

    test("a framed but empty body returns nil", function()
      expect(frame.unframe("v1:")).toBe(nil)
    end)

    test("isFramed accepts the prefix and nothing else", function()
      expect(frame.isFramed("v1:004142")).toBe(true)
      expect(frame.isFramed("v2:004142")).toBe(false)
      expect(frame.isFramed("4142")).toBe(false)
      expect(frame.isFramed(nil)).toBe(false)
      expect(frame.isFramed(42)).toBe(false)
    end)

    test("an empty payload round-trips", function()
      local back = frame.unframe(frame.frame(buffer.create(0)))
      expect(back ~= nil).toBe(true)
      expect(buffer.len(back :: buffer)).toBe(0)
    end)

    test("a v1:-prefixed string with corrupt payload returns nil rather than throwing", function()
      expect(frame.unframe("v1:zz")).toBe(nil)
      expect(frame.unframe("v1:abc")).toBe(nil)
    end)

    test("a valid payload still round-trips unchanged after pcall wrapping", function()
      local original = "TEST-PAYLOAD"
      local framed = frame.frame(buffer.fromstring(original))
      local back = frame.unframe(framed)
      expect(back ~= nil).toBe(true)
      expect(buffer.tostring(back :: buffer)).toBe(original)
    end)
  end)
end)
