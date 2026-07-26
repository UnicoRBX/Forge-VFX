-- Encodes/decodes a modifier queue with Z (pkg/Z, MIT), a schema-based binary
-- serializer.
--
-- A schema writes no field names at all, which is where most of the payload
-- would otherwise go. The two places a queue is genuinely polymorphic ride Z.table's
-- self-describing mode instead, because that is where the type really does vary:
--   * `start` / `finish` hold a tagged Value whose `v` is whatever the row's
--     property type is (number, Color3, UDim2, NumberRange, ...);
--   * `extra` carries any field this version of the plugin does not know about,
--     which is what keeps modifier_queue.merge's union-of-keys behaviour honest
--     across plugin versions rather than silently dropping a newer field.
--
-- Buffer and string widths are deliberate: Z exposes the length-prefix size as
-- part of the type (buffer8/16/32, str8/16/32), so `curve` tops out at 65535
-- bytes rather than at some accidental limit. A curve is 24 bytes per control
-- point, so that is thousands of points.
--
-- Z is injected rather than required at module scope: under lune it must be
-- hosted through the harness's Rojo loader so the Roblox datatype globals it
-- registers are in scope (without them Z.table cannot encode a Color3). Real
-- Studio callers never call `configure`.
local value = require("./value")

local codec = {}

local VERSION = 1

-- Fields the schema names explicitly. Anything else on a modifier goes to
-- `extra`, so a field written by a newer plugin survives a round trip here.
local KNOWN = {
  kind = true,
  chain = true,
  duration = true,
  start = true,
  finish = true,
  curve = true,
  weight = true,
  envelope = true,
}

export type Modifier = {
  kind: string,
  chain: boolean,
  duration: number?,
  start: value.Value?,
  finish: value.Value?,
  curve: buffer?,
  weight: buffer?,
  envelope: buffer?,
  [string]: any,
}

export type Queue = { v: number, queue: { Modifier } }

local _z: any = nil
local _schema: any = nil

function codec.configure(z: any)
  _z = z
  _schema = nil
end

local function schema(): (any, any)
  if _schema == nil then
    local Z = _z or require("@z") :: any
    _z = Z

    local modifier = Z.schema({
      kind = Z.str8,
      chain = Z.bool,
      duration = Z.some(Z.f64),
      start = Z.some(Z.table),
      finish = Z.some(Z.table),
      curve = Z.some(Z.buffer16),
      weight = Z.some(Z.buffer16),
      envelope = Z.some(Z.buffer16),
      extra = Z.some(Z.table),
    })

    -- a queue is a handful of entries, so an 8-bit count is plenty
    _schema = Z.schema({
      v = Z.u8,
      queue = Z.schema8({ modifier }),
    })
  end

  return _z, _schema
end

function codec.empty(): Queue
  return { v = VERSION, queue = {} }
end

function codec.encode(queue: Queue): buffer
  if type(queue) ~= "table" or type(queue.queue) ~= "table" then
    error("cannot encode a malformed modifier queue", 2)
  end

  local Z, s = schema()
  local mods = {}

  for i, m in queue.queue do
    if type(m) ~= "table" then
      error("cannot encode a modifier that is not a table", 2)
    end

    local extra: { [string]: any }? = nil

    for k, v in m do
      if not KNOWN[k] then
        if type(k) ~= "string" then
          error(`modifier codec cannot encode a modifier with a {type(k)} key`, 2)
        end
        extra = extra or {}
        (extra :: any)[k] = v
      end
    end

    mods[i] = {
      kind = m.kind or "",
      chain = m.chain == true,
      duration = m.duration,
      start = m.start,
      finish = m.finish,
      curve = m.curve,
      weight = m.weight,
      envelope = m.envelope,
      extra = extra,
    }
  end

  -- Z.ser REPORTS failure as a second return rather than raising, so an
  -- unencodable value would otherwise sail through as a nil buffer
  local out, err = Z.ser(s, { v = queue.v or VERSION, queue = mods })

  if err ~= nil or typeof(out) ~= "buffer" then
    error(`cannot encode modifier queue: {err or "no buffer produced"}`, 2)
  end

  return out :: buffer
end

function codec.decode(buf: buffer): Queue
  if typeof(buf) ~= "buffer" then
    error("malformed modifier queue payload", 2)
  end

  local Z, s = schema()

  -- Z's safe mode swallows the read error and hands back nil, so absence of a
  -- table IS one failure signal. It is not sufficient on its own: a payload
  -- truncated at a field boundary still decodes, just short. Z.migrate shows the
  -- intended check, which is that the reader consumed exactly the whole buffer,
  -- and that also rejects trailing garbage.
  local data, pos = Z.des(s, buf, 0, true)

  if type(data) ~= "table" or type(data.v) ~= "number" or type(data.queue) ~= "table" then
    error("malformed modifier queue payload", 2)
  end

  if pos ~= buffer.len(buf) then
    error(`malformed modifier queue payload: read {pos} of {buffer.len(buf)} bytes`, 2)
  end

  if data.v > VERSION then
    error(`unsupported modifier queue version {data.v} (reader supports <= {VERSION})`, 2)
  end

  local out = {}

  for i, m in data.queue do
    local mod: { [string]: any } = {
      kind = m.kind,
      chain = m.chain,
      duration = m.duration,
      start = m.start,
      finish = m.finish,
      curve = m.curve,
      weight = m.weight,
      envelope = m.envelope,
    }

    if type(m.extra) == "table" then
      for k, v in m.extra do
        mod[k] = v
      end
    end

    out[i] = mod :: any
  end

  return { v = data.v, queue = out }
end

return codec
