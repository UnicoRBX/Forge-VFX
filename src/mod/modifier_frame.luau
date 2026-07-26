local modifier_frame = {}

-- frames an encoded modifier queue as "v1:" .. base64(body), matching
-- model_serializer's convention that attributes hold strings, not buffers
modifier_frame.PREFIX = "v1:"

-- the flag is not a version: both forms are current and the writer picks per
-- payload, because zstd roughly halves a real authored curve but its frame
-- header costs more than it saves on a short queue, so an empty tombstone
-- would grow. picking the smaller of the two is what makes compression free
-- rather than a trade. a genuine format change bumps the prefix instead
local RAW = 0
local ZSTD = 1

-- zstd's top level; 0.008ms on a real queue against 0.003ms at level 3, for
-- ~4% fewer characters, matching model_serializer and the theme export
local LEVEL = 22

type Base64 = {
  encode: (buffer) -> buffer,
  decode: (buffer) -> buffer,
}

-- decompress returns nil rather than throwing on input it cannot read, so the
-- guard lives with the implementation that knows how to detect that
type Compression = {
  compress: (buffer) -> buffer,
  decompress: (buffer) -> buffer?,
}

local _base64: Base64? = nil
local _compression: Compression? = nil

-- injected rather than required at module scope: EncodingService is reached
-- through game:GetService, which does not exist under lune, so resolving it
-- eagerly would make every consumer of this module untestable headlessly.
-- real Studio callers never call configure and get the lazy EncodingService
-- defaults on first use
function modifier_frame.configure(base64: Base64, compression: Compression?)
  _base64 = base64
  _compression = compression
end

local function codec(): Base64
  if _base64 == nil then
    local service = game:GetService("EncodingService")
    _base64 = {
      encode = function(buf: buffer): buffer
        return service:Base64Encode(buf)
      end,

      decode = function(buf: buffer): buffer
        return service:Base64Decode(buf)
      end,
    }
  end

  return _base64 :: Base64
end

local function packer(): Compression
  if _compression == nil then
    local service = game:GetService("EncodingService")
    local algorithm = Enum.CompressionAlgorithm.Zstd

    _compression = {
      compress = function(buf: buffer): buffer
        return service:CompressBuffer(buf, algorithm, LEVEL)
      end,

      -- DecompressBuffer throws on a corrupt or oversized payload, and
      -- GetDecompressedBufferSize returns nil for exactly those cases
      decompress = function(buf: buffer): buffer?
        if service:GetDecompressedBufferSize(buf, algorithm) == nil then
          return nil
        end

        return service:DecompressBuffer(buf, algorithm)
      end,
    }
  end

  return _compression :: Compression
end

-- whether this attribute value is one of ours at all, as opposed to a legacy
-- value or something a user set by hand, which distinguishes "framed but
-- unreadable" (corruption, worth warning about) from "not a modifier queue"
-- (fall through)
function modifier_frame.isFramed(raw: unknown): boolean
  if typeof(raw) ~= "string" then
    return false
  end

  return string.sub(raw :: string, 1, #modifier_frame.PREFIX) == modifier_frame.PREFIX
end

local function tagged(flag: number, buf: buffer): buffer
  local out = buffer.create(buffer.len(buf) + 1)
  buffer.writeu8(out, 0, flag)
  buffer.copy(out, 1, buf, 0, buffer.len(buf))
  return out
end

function modifier_frame.frame(buf: buffer): string
  local base64 = codec()
  local packed = packer().compress(buf)
  local body = if buffer.len(packed) < buffer.len(buf) then tagged(ZSTD, packed) else tagged(RAW, buf)

  return modifier_frame.PREFIX .. buffer.tostring(base64.encode(body))
end

function modifier_frame.unframe(raw: unknown): buffer?
  if not modifier_frame.isFramed(raw) then
    return nil
  end

  local payload = string.sub(raw :: string, #modifier_frame.PREFIX + 1)
  local decoder = codec()
  local unpack = packer().decompress

  local ok, result = pcall(function()
    local body = decoder.decode(buffer.fromstring(payload))
    local size = buffer.len(body)

    if size == 0 then
      return nil
    end

    local flag = buffer.readu8(body, 0)
    local rest = buffer.create(size - 1)
    buffer.copy(rest, 0, body, 1, size - 1)

    if flag == ZSTD then
      return unpack(rest)
    elseif flag == RAW then
      return rest
    end

    return nil
  end)

  if ok then
    return result :: buffer?
  else
    return nil
  end
end

return modifier_frame
