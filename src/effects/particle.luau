local attr = require("@mod/attributes")
local clock = require("@mod/clock")
local tween = require("@mod/tween")
local types = require("@root/types")
local utility = require("@mod/utility")

local particle = {}

function particle.emit(ref: ParticleEmitter, obj: ParticleEmitter, scope: types.scope)
  if ref.Enabled then
    ref.Enabled = false
  end

  local delay = attr.get(ref, "EmitDelay", 0)
  local count = attr.get(ref, "EmitCount", 1)
  local duration = attr.get(ref, "EmitDuration", 0)

  local useDuration = duration > 0

  clock.wait(delay)

  if useDuration then
    obj.Enabled = true
  end

  local timeScaleDuration = attr.get(ref, "TimeScale_Duration", 0.1)

  local timeScale = clock.read(obj)

  local timeScaleStart = attr.get(ref, "TimeScale_Start", timeScale, true)
  local timeScaleEnd = attr.get(ref, "TimeScale_End", timeScale, true)

  local speedTween

  if timeScaleStart ~= timeScaleEnd then
    speedTween = tween.fromParams(
      attr.get(ref, "TimeScale_Curve", utility.default_bezier),
      timeScaleDuration,
      function(alpha, deltaTime)
        local speed = utility.lerp(timeScaleStart, timeScaleEnd, math.clamp(alpha, 0, 1))

        clock.write(obj, speed)

        return deltaTime
      end
    )

    table.insert(scope, speedTween)
  else
    clock.write(obj, timeScaleStart)
  end

  utility.onCancel(scope, function()
    if useDuration then
      obj.Enabled = false
    end

    obj:Clear()
  end)

  obj:Emit(count)

  if useDuration then
    clock.wait(duration)
    obj.Enabled = false
  end

  tween.timer(ref.Lifetime.Max, function(deltaTime, elapsed)
    local speed = clock.read(ref)

    return if speed > 0 or (elapsed > 0 and speedTween and speedTween.Connected) then deltaTime * speed else nil
  end, speedTween, scope)
end

return particle
