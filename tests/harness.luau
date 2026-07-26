--!strict
-- Test harness: injects Roblox datatypes as globals (so emit-module code runs
-- under lune), hosts module trees that lune's plain `require()` cannot, and
-- re-exports a stable
-- assertion surface wrapping dphfox/tiniest so later specs never touch
-- tiniest's raw API or lune's `@lune/roblox` / `@lune/luau` libraries.
--
-- tiniest pin (Task 1): the vendored `pkg/tiniest` bundle for lune is
-- `pkg/tiniest/src/tiniest_for_lune.luau` (required here as
-- "@tiniest/src/tiniest_for_lune", since the `tiniest` alias points at the
-- submodule root, which has no init.luau of its own). Its real API
-- (confirmed by reading pkg/tiniest/src/tiniest.luau and
-- tiniest_for_lune.luau) is:
--   tiniest_for_lune.configure(options) -> {
--     describe(label, fn), test(label, fn),
--     collect_tests(fn) -> {Test}, run_tests(tests, {}) -> RunResult,
--     expect, snapshot, format_run,
--   }
--   RunResult = { tests, status_tally = { pass: number, fail: number }, individual }
-- (there is no `results.failures` field, contrary to the brief's guessed
-- shape -- exit-code logic below uses `status_tally.fail` instead). The
-- `tiniest_pretty` plugin auto-prints a formatted report on `after_run`
-- unless `pretty.disable_output.after_run` is set, so `harness.run()` gets
-- readable console output for free.
--
-- ## Known lune / @lune-roblox gaps, and why requireRojoModule exists
--
-- Rojo-packaged Roblox modules require their own submodules via the engine's
-- Instance-tree convention: `script.Parent.X`, `script:GetChildren()`,
-- `script:GetAttributes()`, `game:GetService(...)`. Plain `lune run` does NOT
-- provide a `script`/`game` global at all -- confirmed empirically: `_G`
-- mutations make it into required chunks (since `_G` is a genuinely shared
-- table), but bare/implicit globals like `script` do NOT (each required chunk
-- gets its own global environment; `script`/`game` are engine-injected bindings
-- that only exist for real inside Roblox/Studio). lune *can* host this kind of
-- require, but only via a hand-rolled loader built on `@lune/luau`'s
-- `luau.load(bytecode, { environment = ..., injectGlobals = true })` -- this is
-- exactly the mechanism the lune maintainers landed on for this purpose in
-- v0.7.9 (see https://github.com/lune-org/lune/issues/21); lune does not ship a
-- ready-made "requireFromRojo" helper, so `harness.requireRojoModule` below
-- implements one, generically. Z is what needs it here: it registers its Roblox
-- datatype handlers from globals (`if Color3 then ...`), and a plainly required
-- Z would silently register none of them, so Z.table could not encode a Color3.
--
-- Two engine behaviours `@lune/roblox`'s Rust-side emulation does not implement
-- are bridged below rather than faked, because hosted modules can rely on them:
--   1. `Enum.<X>.FromValue` (a real EnumType method) is missing from lune's
--      `Enum` datatypes entirely (indexing it errors, doesn't return nil).
--      Bridged with an EnumType proxy that implements `FromValue` via a real
--      `GetEnumItems()` + `.Value` scan, forwarding everything else untouched.
--   2. In the real engine, `Vector3`/`Vector2` are backed by the native
--      `vector` primitive type, so e.g. `vector.magnitude(cframe:ToAxisAngle())`
--      works transparently. lune's `@lune/roblox` Vector3/Vector2 are a
--      separate hand-implemented userdata that does NOT interop with the native
--      `vector` library (confirmed: `CFrame:ToAxisAngle()` returns a lune
--      `Vector3`, and `vector.magnitude()` rejects it with "vector expected,
--      got Vector3"). Bridged with a thin per-module `vector.*` wrapper that
--      unwraps Vector3/Vector2 into a native `vector` before delegating to the
--      real native function -- this mirrors real engine interop, it does not
--      change any math.
--
-- If a FUTURE spec hits something lune truly cannot host under this loader
-- (e.g. a datatype `@lune/roblox` can't construct, or an engine behaviour too
-- deep to bridge cheaply), do not fake it: skip that spec under lune, note
-- exactly what failed and why in a comment here, and run the equivalent spec
-- via the ui-labs MCP path (`execute_luau` + `tiniest_plugin`, in real Studio,
-- where `script`/`game`/native engine behaviour all genuinely exist).
local roblox = require("@lune/roblox") :: any
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local DATATYPE_NAMES = {
  "Vector2",
  "Vector3",
  "CFrame",
  "Color3",
  "UDim",
  "UDim2",
  "NumberRange",
  "NumberSequence",
  "NumberSequenceKeypoint",
  "ColorSequence",
  "ColorSequenceKeypoint",
  "Rect",
  "BrickColor",
  "PhysicalProperties",
  "Ray",
  "Region3",
}

-- Third real gap found while building this harness: the brief's original
-- plan was to inject datatype constructors as bare globals via `_G`, on the
-- assumption that Roblox code referring to e.g. bare `NumberSequence` would
-- then just work anywhere. That assumption is wrong under lune: `_G` IS a
-- genuinely shared table across required chunks (confirmed: `_G.foo` set in
-- one file reads back fine in a file it requires), but *bare* global
-- identifiers are resolved through each chunk's own separate global
-- environment, NOT through `_G` -- confirmed empirically (`_G.foo = "x"` in
-- one file, then bare `foo` read in a required child prints `nil`). This is
-- deliberate Luau/Roblox behaviour (mirrors why `_G.script` isn't a thing in
-- real Roblox either), lune just inherits it. Re-exporting the datatype
-- table below (`harness.datatypes`) is the fix: every spec gets datatypes
-- from harness explicitly, so `@lune/roblox` is still only ever touched here.
local datatypeGlobals: { [string]: any } = {}
for _, name in DATATYPE_NAMES do
  if roblox[name] ~= nil then
    datatypeGlobals[name] = roblox[name]
  end
end

--------------------------------------------------------------------------------
-- requireRojoModule: host a Rojo-style ("script.Parent.X") module tree under
-- lune, for vendored Roblox packages that don't use path/alias requires.
--------------------------------------------------------------------------------

local function resolveModulePath(path: string): string?
  if fs.isFile(path .. ".luau") then
    return path .. ".luau"
  end
  if fs.isFile(path .. "/init.luau") then
    return path .. "/init.luau"
  end
  return nil
end

-- Bridge gap #1: Enum.<X>.FromValue, missing from lune's Enum emulation.
local EnumTypeMeta = {}
EnumTypeMeta.__index = function(self, key)
  local real = (self :: any).__real
  if key == "FromValue" then
    return function(_, value: number)
      for _, item in real:GetEnumItems() do
        if item.Value == value then
          return item
        end
      end
      return nil
    end
  end
  local v = real[key]
  if typeof(v) == "function" then
    return function(_, ...)
      return v(real, ...)
    end
  end
  return v
end
EnumTypeMeta.__tostring = function(self)
  return tostring((self :: any).__real)
end

local enumTypeCache: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local function wrapEnumType(real: any): any
  local cached = enumTypeCache[real]
  if cached then
    return cached
  end
  local proxy = setmetatable({ __real = real }, EnumTypeMeta)
  enumTypeCache[real] = proxy
  return proxy
end

local EnumProxy = setmetatable({}, {
  __index = function(_, key)
    if key == "GetEnums" then
      return function()
        local list = {}
        for _, e in (roblox.Enum :: any):GetEnums() do
          table.insert(list, wrapEnumType(e))
        end
        return list
      end
    end
    local real = (roblox.Enum :: any)[key]
    if real == nil then
      return nil
    end
    return wrapEnumType(real)
  end,
})

-- Bridge gap #2: native `vector` library rejecting lune's Vector3/Vector2.
local realVector = vector
local vectorCompat = setmetatable({}, {
  __index = function(_, key)
    local fn = (realVector :: any)[key]
    if typeof(fn) ~= "function" then
      return fn
    end
    return function(...)
      local args = table.pack(...)
      for i = 1, args.n do
        local v = args[i]
        if typeof(v) == "Vector3" then
          args[i] = vector.create(v.X, v.Y, v.Z)
        elseif typeof(v) == "Vector2" then
          args[i] = vector.create(v.X, v.Y, 0)
        end
      end
      return fn(table.unpack(args, 1, args.n))
    end
  end,
})

-- Minimal fake DataModel, for hosted modules that reach for a service.
local fakeRunService = setmetatable({}, {
  __index = function(_, key)
    if key == "IsServer" then
      return function()
        return true
      end
    end
    if key == "IsClient" then
      return function()
        return false
      end
    end
    error(`RunService.{tostring(key)} is not implemented in the lune test shim`, 0)
  end,
})

local fakeGame = setmetatable({}, {
  __index = function(_, key)
    if key == "GetService" then
      return function(_, name: string)
        if name == "RunService" then
          return fakeRunService
        end
        error(`game:GetService("{name}") is not implemented in the lune test shim`, 0)
      end
    end
    error(`game.{tostring(key)} is not implemented in the lune test shim`, 0)
  end,
})

-- A shim stands in for a Roblox Instance (ModuleScript/Folder) purely for
-- require-routing purposes: indexing it returns another shim (a child
-- reference), and only `require()`-ing a shim actually loads + executes the
-- file it points to.
local ShimMeta = {}

local function makeShim(path: string, loader: (string) -> any): any
  return setmetatable({ __path = path, __load = loader }, ShimMeta)
end

local function customRequire(x: any): any
  if typeof(x) == "table" and getmetatable(x) == ShimMeta then
    local shim = x :: any
    return (shim.__load :: (string) -> any)(shim.__path)
  end
  return require(x)
end

ShimMeta.__index = function(self, key)
  local path = (self :: any).__path :: string
  local loader = (self :: any).__load :: (string) -> any
  if key == "Parent" then
    return makeShim(path:match("(.*)/[^/]+$") or ".", loader)
  elseif key == "Name" then
    return path:match("([^/]+)$")
  elseif key == "GetAttributes" then
    return function()
      return {}
    end
  elseif key == "GetAttribute" then
    return function()
      return nil
    end
  elseif key == "FindFirstChild" then
    return function(_, name: string)
      local childPath = path .. "/" .. name
      if resolveModulePath(childPath) then
        return makeShim(childPath, loader)
      end
      return nil
    end
  elseif key == "GetChildren" then
    return function()
      local children = {}
      for _, entry in fs.readDir(path) do
        if entry ~= "init.luau" then
          local childPath = path .. "/" .. (entry:gsub("%.luau$", ""))
          if resolveModulePath(childPath) then
            -- Speculatively load each child so a module that needs
            -- something lune genuinely can't host is *skipped with
            -- a warning* instead of taking the whole tree down.
            local ok, errOrResult = pcall(loader, childPath)
            if ok then
              table.insert(children, makeShim(childPath, loader))
            else
              warn(`[lune rojo-require shim] skipping {childPath}: {tostring(errOrResult)}`)
            end
          end
        end
      end
      return children
    end
  else
    return makeShim(path .. "/" .. key, loader)
  end
end

-- Load a Rojo-style module tree rooted at `rootPath` (e.g. the `src` folder
-- of a vendored package whose files use `script.Parent.X` requires), and
-- return the root module's return value.
local function requireRojoModule(rootPath: string): any
  local moduleCache: { [string]: any } = {}

  local function loadModule(path: string): any
    if moduleCache[path] ~= nil then
      return moduleCache[path]
    end
    local file = resolveModulePath(path)
    assert(file ~= nil, `cannot resolve module at {path}`)
    local source = fs.readFile(file :: string)
    local bytecode = luau.compile(source)
    local env = table.clone(datatypeGlobals)
    env.script = makeShim(path, loadModule)
    env.game = fakeGame
    env.Enum = EnumProxy
    env.vector = vectorCompat
    env.require = customRequire
    local chunk = luau.load(bytecode, {
      environment = env,
      injectGlobals = true,
      debugName = file,
    })
    local result = chunk()
    moduleCache[path] = result
    return result
  end

  return loadModule(rootPath)
end

--------------------------------------------------------------------------------
-- tiniest pin
--------------------------------------------------------------------------------

local tiniest = require("@tiniest/src/tiniest_for_lune").configure({
  pretty = {},
})

local collected: { () -> () } = {}

local function deepEqual(a: any, b: any): boolean
  if a == b then
    return true
  end
  if typeof(a) ~= "table" or typeof(b) ~= "table" then
    -- buffers: compare byte content
    if typeof(a) == "buffer" and typeof(b) == "buffer" then
      return buffer.tostring(a) == buffer.tostring(b)
    end
    return false
  end
  for k, v in a do
    if not deepEqual(v, (b :: any)[k]) then
      return false
    end
  end
  for k in b do
    if (a :: any)[k] == nil then
      return false
    end
  end
  return true
end

local harness = {}
harness.deepEqual = deepEqual
harness.requireRojoModule = requireRojoModule
-- Roblox datatype constructors (Vector2, Vector3, CFrame, NumberSequence, ...)
-- for specs to destructure explicitly, e.g.
-- `local NumberSequence = harness.datatypes.NumberSequence`.
-- Instance is deliberately excluded from datatypeGlobals (which is injected as
-- implicit globals in hosted modules): Instance.new is a
-- side-effecting constructor, and we must not activate dead code branches that
-- might exist in those modules. Specs get Instance via a separate table.
local specDataTypes = table.clone(datatypeGlobals)
specDataTypes.Instance = roblox.Instance
harness.datatypes = specDataTypes

-- Stand-in for EncodingService's zstd, for specs that exercise modifier_frame's
-- compressed encoding. A toy run-length coder: like zstd it shrinks repetitive
-- input (a real modifier queue is largely zero runs) and grows short
-- unrepetitive input, so both branches of frame's pick-the-smaller are
-- reachable headlessly. Not a compressor anyone should reuse.
harness.fakeCompression = {
  compress = function(buf: buffer): buffer
    local runs = {}
    local len = buffer.len(buf)
    local i = 0

    while i < len do
      local byte = buffer.readu8(buf, i)
      local run = 1

      while run < 255 and i + run < len and buffer.readu8(buf, i + run) == byte do
        run += 1
      end

      table.insert(runs, string.char(run, byte))
      i += run
    end

    return buffer.fromstring(table.concat(runs))
  end,

  -- an odd length cannot be a run/byte pair sequence, which stands in for the
  -- real codec's corrupt-input detection
  decompress = function(buf: buffer): buffer?
    local len = buffer.len(buf)

    if len % 2 ~= 0 then
      return nil
    end

    local out = {}

    for i = 0, len - 1, 2 do
      table.insert(out, string.rep(string.char(buffer.readu8(buf, i + 1)), buffer.readu8(buf, i)))
    end

    return buffer.fromstring(table.concat(out))
  end,
}

function harness.describe(name: string, body: () -> ())
  tiniest.describe(name, body)
end

function harness.test(name: string, body: () -> ())
  tiniest.test(name, body)
end

function harness.expect(actual: any)
  return {
    toBe = function(expected: any)
      assert(actual == expected, `expected {tostring(actual)} to be {tostring(expected)}`)
    end,
    toEqual = function(expected: any)
      assert(deepEqual(actual, expected), `values not deeply equal`)
    end,
    toThrow = function()
      assert(not pcall(actual), "expected function to throw")
    end,
    ok = function()
      assert(actual, `expected truthy, got {tostring(actual)}`)
    end,
  }
end

-- Register a spec's suite for the runner.
function harness.suite(fn: () -> ())
  table.insert(collected, fn)
end

function harness.run(): number
  local tests = tiniest.collect_tests(function()
    for _, fn in collected do
      fn()
    end
  end)
  local result = tiniest.run_tests(tests, {})
  return if result.status_tally.fail > 0 then 1 else 0
end

return harness
