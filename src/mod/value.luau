--!strict
-- A modifier "Value" is a tagged union so future dynamic variables slot in with
-- no format change. Only `lit` is produced in Spec 1; `var` is round-tripped.
export type Value = { t: "lit", v: any } | { t: "var", ref: string }

local value = {}

function value.lit(v: any): Value
  return { t = "lit", v = v }
end

function value.isLit(x: Value): boolean
  return x.t == "lit"
end

-- Resolve to a concrete runtime value. Variables are unresolved in Spec 1 (nil),
-- so callers fall back to their own default.
function value.resolve(x: Value): any
  if x.t == "lit" then
    return (x :: any).v
  end
  return nil
end

return value
