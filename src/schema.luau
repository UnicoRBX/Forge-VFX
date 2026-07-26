-- Open, versioned schema standard for property/attribute rows. Data-only so it
-- round-trips across the plugin<->runtime boundary and can be authored by custom
-- effects. Unknown fields are preserved (validation never mutates the descriptor).
-- An entry is a row (has `name`) or a group (has `title` + ordered `entries`);
-- one ordered list per level so authors control row/group interleaving.
local Schema = {}
Schema.SCHEMA_VERSION = 1

export type RowKind = "value" | "external"
export type SchemaRow = {
  name: string,
  display_name: string,
  type: string,
  details: { short: string, long: string },
  kind: RowKind,
  [string]: any,
}
export type SchemaGroup = { title: string, entries: { SchemaEntry }, [string]: any }
export type SchemaEntry = SchemaRow | SchemaGroup
export type Schema = {
  schema: number,
  effect: string,
  display_name: string,
  entries: { SchemaEntry },
  [string]: any,
}

local registry: { [string]: Schema } = {}

-- Array-shape: every key must be a positive contiguous integer index.
local function isArray(t: { [any]: any }): boolean
  local n = 0
  for _ in t do
    n += 1
  end
  return n == #t
end

local function findFunction(v: any): boolean
  if type(v) == "function" then
    return true
  end
  if type(v) == "table" then
    for k, item in v do
      if type(k) == "function" or findFunction(item) then
        return true
      end
    end
  end
  return false
end

local function validateRow(row: any): (boolean, string?)
  for _, f in { "name", "display_name", "type" } do
    if type(row[f]) ~= "string" then
      return false, `row.{f} must be a string`
    end
  end
  if row.kind ~= "value" and row.kind ~= "external" then
    return false, "row.kind must be 'value' or 'external'"
  end
  if type(row.details) ~= "table" or type(row.details.short) ~= "string" or type(row.details.long) ~= "string" then
    return false, "row.details must be { short: string, long: string }"
  end
  return true
end

local function validateEntries(entries: any): (boolean, string?)
  if type(entries) ~= "table" or not isArray(entries) then
    return false, "entries must be an array"
  end
  for _, entry in entries do
    if type(entry) ~= "table" then
      return false, "entry is not a table"
    end
    local isRow = entry.name ~= nil
    local isGroup = entry.title ~= nil
    if isRow and isGroup then
      return false, "entry cannot have both name (row) and title (group)"
    elseif isRow then
      local ok, why = validateRow(entry)
      if not ok then
        return false, why
      end
    elseif isGroup then
      if type(entry.title) ~= "string" then
        return false, "group.title must be a string"
      end
      local ok, why = validateEntries(entry.entries)
      if not ok then
        return false, why
      end
    else
      return false, "entry must have name (row) or title (group)"
    end
  end
  return true
end

local function validateTarget(t: any): (boolean, string?)
  if type(t) ~= "table" then
    return false, "curve.target must be a table"
  end
  if t.kind == "sequence" then
    if type(t.prop) ~= "string" then
      return false, "sequence target requires prop: string"
    end
  elseif t.kind == "attribute" then
    if type(t.attr) ~= "string" then
      return false, "attribute target requires attr: string"
    end
  else
    return false, "curve.target.kind must be 'sequence' or 'attribute'"
  end
  return true
end

local function validateCurveEntry(entry: any): (boolean, string?)
  if type(entry) ~= "table" then
    return false, "curve entry is not a table"
  end
  if type(entry.name) ~= "string" then
    return false, "curve entry requires name: string"
  end
  local isGroup = entry.entries ~= nil
  local isLeaf = entry.target ~= nil
  if isGroup and isLeaf then
    return false, "curve entry cannot be both group (entries) and leaf (target)"
  elseif isGroup then
    if type(entry.entries) ~= "table" or not isArray(entry.entries) then
      return false, "curve group entries must be an array"
    end
    for _, sub in entry.entries do
      local ok, why = validateCurveEntry(sub)
      if not ok then
        return false, why
      end
    end
    return true
  elseif isLeaf then
    return validateTarget(entry.target)
  else
    return false, "curve entry must be a leaf (target) or group (entries)"
  end
end

function Schema.validateCurves(curves: any): (boolean, string?)
  if type(curves) ~= "table" or not isArray(curves) then
    return false, "curves must be an array"
  end
  for _, entry in curves do
    local ok, why = validateCurveEntry(entry)
    if not ok then
      return false, why
    end
  end
  return true
end

function Schema.validate(d: any): (boolean, string?)
  if type(d) ~= "table" then
    return false, "descriptor is not a table"
  end
  if type(d.schema) ~= "number" then
    return false, "descriptor.schema must be a number"
  end
  if d.schema > Schema.SCHEMA_VERSION then
    return false, `unsupported schema version {d.schema}`
  end
  if type(d.effect) ~= "string" then
    return false, "descriptor.effect must be a string"
  end
  if type(d.display_name) ~= "string" then
    return false, "descriptor.display_name must be a string"
  end
  if findFunction(d) then
    return false, "descriptor must be data-only (found a function)"
  end
  if d.curves ~= nil then
    local ok, why = Schema.validateCurves(d.curves)
    if not ok then
      return false, why
    end
  end
  return validateEntries(d.entries)
end

function Schema.define(d: any): Schema
  local ok, why = Schema.validate(d)
  if not ok then
    error(`invalid schema: {why}`, 2)
  end
  return d :: Schema
end

function Schema.register(d: any)
  local s = Schema.define(d)
  registry[s.effect] = s
end

function Schema.get(effectType: string): Schema?
  return registry[effectType]
end

return Schema
