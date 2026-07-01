--!strict
-- Open, versioned schema standard for property/attribute rows. Data-only so it
-- round-trips across the plugin<->runtime boundary and can be authored by custom
-- effects. Unknown fields are preserved (validation never mutates the descriptor).
local Schema = {}
Schema.SCHEMA_VERSION = 1

export type RowKind = "value" | "external"
export type SchemaRow = {
    name: string, display_name: string, type: string,
    details: { short: string, long: string }, kind: RowKind, [string]: any,
}
export type SchemaGroup = { title: string, rows: { SchemaRow }?, groups: { SchemaGroup }? }
export type Schema = { schema: number, effect: string, display_name: string, groups: { SchemaGroup } }

local registry: { [string]: Schema } = {}

local function validateRow(row: any): (boolean, string?)
    if type(row) ~= "table" then return false, "row is not a table" end
    for _, f in { "name", "display_name", "type" } do
        if type(row[f]) ~= "string" then return false, `row.{f} must be a string` end
    end
    if row.kind ~= "value" and row.kind ~= "external" then
        return false, "row.kind must be 'value' or 'external'"
    end
    if type(row.details) ~= "table"
        or type(row.details.short) ~= "string"
        or type(row.details.long) ~= "string" then
        return false, "row.details must be { short: string, long: string }"
    end
    return true
end

local function validateGroup(group: any): (boolean, string?)
    if type(group) ~= "table" or type(group.title) ~= "string" then
        return false, "group.title must be a string"
    end
    if group.rows ~= nil then
        if type(group.rows) ~= "table" then return false, "group.rows must be a table" end
        for _, r in group.rows do
            local ok, why = validateRow(r)
            if not ok then return false, why end
        end
    end
    if group.groups ~= nil then
        if type(group.groups) ~= "table" then return false, "group.groups must be a table" end
        for _, g in group.groups do
            local ok, why = validateGroup(g)
            if not ok then return false, why end
        end
    end
    return true
end

function Schema.validate(d: any): (boolean, string?)
    if type(d) ~= "table" then return false, "descriptor is not a table" end
    if type(d.schema) ~= "number" then return false, "descriptor.schema must be a number" end
    if d.schema > Schema.SCHEMA_VERSION then
        return false, `unsupported schema version {d.schema}`
    end
    if type(d.effect) ~= "string" then return false, "descriptor.effect must be a string" end
    if type(d.display_name) ~= "string" then return false, "descriptor.display_name must be a string" end
    if type(d.groups) ~= "table" then return false, "descriptor.groups must be a table" end
    for _, g in d.groups do
        local ok, why = validateGroup(g)
        if not ok then return false, why end
    end
    return true
end

function Schema.define(d: any): Schema
    local ok, why = Schema.validate(d)
    if not ok then error(`invalid schema: {why}`, 2) end
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
