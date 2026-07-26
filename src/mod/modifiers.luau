-- Runtime evaluator for a per-target modifier queue. A modifier is
-- lerp(start, finish, alpha); tween alpha = curve(progress), randomizer
-- alpha = weighted random via `rng`. `chain` feeds the previous modifier's
-- output into the next modifier's start. Unknown kinds pass their `start`
-- value through unchanged (forward-compat round-trip, no eval).
--
-- Pure: only requires `@mod/lerp` and `@mod/common/path`, neither of which
-- touch `game`/`script`, so this module is requirable under lune as well as
-- in Studio.
local lerp = require("@mod/lerp")
local path = require("@mod/common/path")

local modifiers = {}

local function typeLerp(a: any, b: any, t: number): any
  local fn = (lerp :: any)[typeof(a)]

  if fn then
    return fn(a, b, t)
  end

  return lerp.Other(a, b, t)
end

-- Sample a serialized curve (a Path2D control-point buffer/string) at
-- progress in [0,1]. Delegates to the pure path module, which mirrors
-- `mod/tween.luau`'s established runtime semantics exactly.
function modifiers.alphaFromCurve(curve: string | buffer, progress: number): number
  return path.alphaAt(curve, progress)
end

function modifiers.evaluate(queue: { any }, progress: number, rng: Random?): any
  local prevOut: any = nil
  local haveOut = false

  for _, m in queue do
    local startVal: any = nil

    if m.chain and haveOut then
      startVal = prevOut
    elseif m.start then
      startVal = m.start.v
    end

    local finishVal = if m.finish then m.finish.v else startVal

    local alpha: number

    if m.kind == "randomizer" then
      -- Constructed lazily, only when actually needed: bare `Random` may not
      -- exist under every Luau host (confirmed absent under lune 0.10.4).
      rng = rng or Random.new()
      alpha = rng:NextNumber()

      if m.weight then
        alpha = modifiers.alphaFromCurve(m.weight, alpha)
      end
    elseif m.kind == "tween" then
      alpha = if m.curve then modifiers.alphaFromCurve(m.curve, progress) else progress
    else
      -- Unknown kind: pass the value through unchanged (round-trip, no eval).
      if startVal ~= nil then
        prevOut = startVal
      end

      haveOut = prevOut ~= nil

      continue
    end

    prevOut = typeLerp(startVal, finishVal, alpha)
    haveOut = true
  end

  return prevOut
end

return modifiers
