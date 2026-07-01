--!strict
-- Pure Path2D control-point (de)serialization + curve sampling. No engine
-- access (no `game`/`script`) so this is requirable under lune as well as in
-- Studio -- unlike `@mod/utility`, which does top-level `game:GetService`.
--
-- `serializePath`/`deserializePath` are moved verbatim from `mod/utility.luau`
-- (which now delegates to this module; see its comment). `alphaAt` mirrors
-- the ease-sampling semantics `mod/tween.luau` uses at runtime exactly:
-- deserialize -> `Bezier.new(points, 0)` -> `1 - bezier:getEase(t).y`. The
-- `1 - y` inversion is an established semantic (the curves are authored in
-- UI space, where Y increases downward) -- match it exactly so editor- and
-- runtime-sampled curves agree.
local Bezier = require("@obj/Bezier")

local path = {}

function path.serializePath(points: { Path2DControlPoint })
  local buf = buffer.create(#points * 4 * 6)

  local offset = 0

  for i, p in points do
    local px = p.Position.X.Scale
    local py = p.Position.Y.Scale

    if i ~= 1 then
      buffer.writef32(buf, offset, px + p.LeftTangent.X.Scale)
      buffer.writef32(buf, offset + 4, py + p.LeftTangent.Y.Scale)

      offset += 8
    end

    buffer.writef32(buf, offset, px)
    buffer.writef32(buf, offset + 4, py)

    offset += 8

    if i ~= #points then
      buffer.writef32(buf, offset, px + p.RightTangent.X.Scale)
      buffer.writef32(buf, offset + 4, py + p.RightTangent.Y.Scale)

      offset += 8
    end
  end

  return buf
end

function path.deserializePath(data: string | buffer)
  local buf = typeof(data) == "string" and buffer.fromstring(data) or data
  local count = buffer.len(buf) / 24

  local points = {}

  for i = 0, count - 1 do
    local offset = i * 4 * 6

    local px = buffer.readf32(buf, offset)
    local py = buffer.readf32(buf, offset + 4)

    table.insert(points, vector.create(px, py))

    if i ~= count - 1 then
      local t1x = buffer.readf32(buf, offset + 8)
      local t1y = buffer.readf32(buf, offset + 12)

      local t2x = buffer.readf32(buf, offset + 16)
      local t2y = buffer.readf32(buf, offset + 20)

      table.insert(points, vector.create(t1x, t1y))
      table.insert(points, vector.create(t2x, t2y))
    end
  end

  return points
end

path.bezier_cache = {} :: { [string]: Bezier.Bezier }

-- Sample a serialized curve at progress `t` in [0,1]. Keyed like
-- `tween.bezier_cache`, by the serialized form (buffers are converted to
-- their string form for a stable cache key).
function path.alphaAt(curve: string | buffer, t: number): number
  local key = if typeof(curve) == "buffer" then buffer.tostring(curve) else curve

  local bezier = path.bezier_cache[key]

  if not bezier then
    local points = path.deserializePath(key)
    bezier = Bezier.new(points, 0)
    path.bezier_cache[key] = bezier
  end

  -- `getEase` (the production path everywhere else in forge-vfx) interpolates
  -- its ease LUT via the native `vector` type's `:Lerp` method. Some Luau
  -- hosts don't implement it -- confirmed empirically on lune 0.10.4: no
  -- `:Lerp` method, no `vector.lerp` function either, and the `vector`
  -- library table is read-only (can't be monkeypatched). Real Roblox/Studio
  -- always has it, so this fallback is dead code there; under a host that
  -- lacks it, fall back to the LUT-free Newton solve (`_getEaseRaw`) -- the
  -- exact same per-point algorithm `getEase` uses to build its LUT, just
  -- without the fast lerp-interpolation step, so results agree to numerical
  -- precision.
  local ok, y = pcall(function()
    return (bezier :: any):getEase(t).y
  end)

  if not ok then
    y = (bezier :: any):_getEaseRaw(t).y
  end

  return 1 - y
end

return path
