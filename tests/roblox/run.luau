local specs = {
  require("./modifier_frame.spec"),
}

return function()
  local passed = 0
  local failed = 0
  local lines = {}

  for _, spec in specs do
    for _, case in spec do
      local ok, err = pcall(case.run)

      if ok then
        passed += 1
        table.insert(lines, `[PASS] {case.name}`)
      else
        failed += 1
        table.insert(lines, `[FAIL] {case.name}\n       {tostring(err)}`)
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, `{passed} passed, {failed} failed`)

  return passed, failed, table.concat(lines, "\n")
end
