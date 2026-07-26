-- a modifier value is a tagged union so a future dynamic variable slots in
-- with no format change; only lit is produced in spec 1, var round-trips
-- already
export type Value = { t: "lit", v: any } | { t: "var", ref: string }

local value = {}

function value.lit(v: any): Value
  return { t = "lit", v = v }
end

function value.isLit(x: Value): boolean
  return x.t == "lit"
end

-- a var resolves to nil in spec 1, so callers fall back to their own default
function value.resolve(x: Value): any
  if x.t == "lit" then
    return (x :: any).v
  end

  return nil
end

return value
