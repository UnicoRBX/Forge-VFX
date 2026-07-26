local frame = require("../mod/modifier_frame")

local function assertEqual(actual: unknown, expected: unknown, label: string)
  assert(actual == expected, `{label}: expected {tostring(expected)}, got {tostring(actual)}`)
end

-- the one lane that runs frame.frame and frame.unframe against the real
-- EncodingService base64 and zstd codecs rather than a lune stand-in
return {
  {
    name = "round-trips a payload that compression shrinks",
    run = function()
      local payload = buffer.fromstring(string.rep("A", 400) .. string.rep("\0", 120))
      local back = frame.unframe(frame.frame(payload))
      assert(back ~= nil, "unframe returned nil for a payload frame() just produced")
      assertEqual(buffer.tostring(back :: buffer), buffer.tostring(payload), "round-tripped payload")
    end,
  },

  {
    name = "stores a shrinkable payload compressed",
    run = function()
      local framed = frame.frame(buffer.fromstring(string.rep("A", 400)))
      local body = game:GetService("EncodingService"):Base64Decode(buffer.fromstring(string.sub(framed, 4)))
      assertEqual(buffer.readu8(body, 0), 1, "storage flag")
    end,
  },

  {
    name = "stores a payload compression would grow raw",
    run = function()
      local framed = frame.frame(buffer.fromstring("ABCDEF"))
      local body = game:GetService("EncodingService"):Base64Decode(buffer.fromstring(string.sub(framed, 4)))
      assertEqual(buffer.readu8(body, 0), 0, "storage flag")
    end,
  },

  {
    name = "returns nil for a corrupt compressed body rather than throwing",
    run = function()
      local ES = game:GetService("EncodingService")
      local body = buffer.create(4)
      buffer.writeu8(body, 0, 1)
      buffer.writeu8(body, 1, 0x99)
      local framed = "v1:" .. buffer.tostring(ES:Base64Encode(body))
      assertEqual(frame.unframe(framed), nil, "unframe result for a corrupt body")
    end,
  },
}
