local RunService = game:GetService("RunService")

local MAX_LIFETIME = 20
local MAX_PLAYBACK_SPEED = 20

local clock = {}

clock.rate = 1

local now = 0
local stepper: RBXScriptConnection? = nil

local Sleeping = {} :: { { thread: thread, wakeAt: number } }
local Tracked = setmetatable({}, { __mode = "k" }) :: { [Instance]: boolean }
local Bodies = setmetatable({}, { __mode = "k" }) :: { [BasePart]: { velocity: Vector3?, spin: Vector3? } }

-- the engine runs these by itself, so the clock keeps each at its base times the rate
local PROPERTIES = {
  Beam = "TextureSpeed",
  Sound = "PlaybackSpeed",
  Trail = "Lifetime",
  ParticleEmitter = "TimeScale",
}

local function getAttributeName(property: string)
  return `__forge_base_{property}`
end

local function apply(instance: Instance, property: string, base: number)
  local rate = clock.rate
  local target = instance :: any

  if property == "TimeScale" then
    target.TimeScale = math.min(base * rate, 1)
  elseif property == "Lifetime" then
    -- a trail can't freeze, so the longest lifetime holds it the longest
    target.Lifetime = if rate > 0 then math.min(base / rate, MAX_LIFETIME) else MAX_LIFETIME
  elseif property == "PlaybackSpeed" then
    target.PlaybackSpeed = math.min(base * rate, MAX_PLAYBACK_SPEED)
  else
    target[property] = base * rate
  end
end

local function getGravityForce(part: BasePart)
  local force = part:FindFirstChild("__forge_gravity")

  if force and force:IsA("VectorForce") then
    return force
  end

  local attachment = Instance.new("Attachment")
  attachment.Name = "__forge_gravity_attachment"
  attachment.Parent = part

  local created = Instance.new("VectorForce")
  created.Name = "__forge_gravity"
  created.RelativeTo = Enum.ActuatorRelativeTo.World
  created.ApplyAtCenterOfMass = true
  created.Attachment0 = attachment
  created.Parent = part

  return created
end

-- a body moving at rate r under gravity scaled by r squared follows the same path, r times as fast
local function applyBody(part: BasePart, body: { velocity: Vector3?, spin: Vector3? })
  local rate = clock.rate
  local velocity, spin = body.velocity, body.spin

  if not velocity or not spin then
    return
  end

  if rate <= 0 then
    part.Anchored = true
    return
  end

  part.Anchored = false

  part.AssemblyLinearVelocity = velocity * rate
  part.AssemblyAngularVelocity = spin * rate

  if rate ~= 1 or part:FindFirstChild("__forge_gravity") then
    local force = getGravityForce(part)
    force.Force = Vector3.new(0, part.AssemblyMass * workspace.Gravity * (1 - rate * rate), 0)
  end
end

local function step(deltaTime: number)
  now += deltaTime * clock.rate

  if #Sleeping == 0 then
    return
  end

  local due = {}
  local waiting = {}

  for _, sleeper in Sleeping do
    if sleeper.wakeAt <= now then
      table.insert(due, sleeper.thread)
    else
      table.insert(waiting, sleeper)
    end
  end

  Sleeping = waiting

  for _, thread in due do
    -- a cancelled effect closes its thread while it sleeps
    if coroutine.status(thread) == "suspended" then
      task.spawn(thread)
    end
  end
end

function clock.init()
  if stepper then
    return
  end

  stepper = RunService.Heartbeat:Connect(step)
end

function clock.deinit()
  if stepper then
    stepper:Disconnect()
    stepper = nil
  end

  table.clear(Sleeping)
end

function clock.now()
  return now
end

function clock.scale(deltaTime: number)
  return deltaTime * clock.rate
end

function clock.wait(duration: number?)
  if not stepper then
    return task.wait(duration)
  end

  table.insert(Sleeping, { thread = coroutine.running(), wakeAt = now + math.max(duration or 0, 0) })
  coroutine.yield()
end

function clock.delay(duration: number, callback: (...any) -> (), ...: any)
  local args = table.pack(...)

  return task.spawn(function()
    clock.wait(duration)
    callback(table.unpack(args, 1, args.n))
  end)
end

function clock.read(instance: Instance): number?
  local property = PROPERTIES[instance.ClassName]

  if not property then
    return nil
  end

  local base = instance:GetAttribute(getAttributeName(property))

  if type(base) == "number" then
    return base
  end

  return (instance :: any)[property]
end

function clock.write(instance: Instance, value: number)
  local property = PROPERTIES[instance.ClassName]

  if not property then
    return
  end

  instance:SetAttribute(getAttributeName(property), value)
  Tracked[instance] = true

  apply(instance, property, value)
end

function clock.track(instance: Instance)
  local base = clock.read(instance)

  if base == nil then
    return
  end

  clock.write(instance, base)
end

function clock.untrack(instance: Instance)
  local property = PROPERTIES[instance.ClassName]

  if not property or not Tracked[instance] then
    return
  end

  local base = clock.read(instance)

  Tracked[instance] = nil
  instance:SetAttribute(getAttributeName(property), nil)

  if base ~= nil then
    (instance :: any)[property] = base
  end
end

function clock.trackBody(part: BasePart)
  local body = {}

  Bodies[part] = body

  -- the impulses it was launched with show in its velocity once physics has stepped
  RunService.Heartbeat:Once(function()
    if Bodies[part] ~= body then
      return
    end

    body.velocity = part.AssemblyLinearVelocity
    body.spin = part.AssemblyAngularVelocity

    if clock.rate ~= 1 then
      applyBody(part, body)
    end
  end)
end

function clock.untrackBody(part: BasePart)
  Bodies[part] = nil

  local force = part:FindFirstChild("__forge_gravity")

  if force then
    force:Destroy()
  end

  local attachment = part:FindFirstChild("__forge_gravity_attachment")

  if attachment then
    attachment:Destroy()
  end
end

function clock.setRate(rate: number)
  if rate ~= rate or rate < 0 then
    return
  end

  local previous = clock.rate

  if rate == previous then
    return
  end

  for part, body in Bodies do
    if body.velocity and previous > 0 and not part.Anchored then
      body.velocity = part.AssemblyLinearVelocity / previous
      body.spin = part.AssemblyAngularVelocity / previous
    end
  end

  clock.rate = rate

  for instance in Tracked do
    local property = PROPERTIES[instance.ClassName]
    local base = clock.read(instance)

    if property and base ~= nil then
      apply(instance, property, base)
    end
  end

  for part, body in Bodies do
    applyBody(part, body)
  end
end

return clock
