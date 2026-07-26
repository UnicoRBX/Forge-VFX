-- entry point for the open cloud engine lane
--
-- darklua bundles this and everything it requires into one self contained file,
-- which is the whole task body. the create task api takes a single script
-- string and has no field for extra modules, so bundling is what lets the specs
-- reach the engine at all without uploading a place first.
local run = require("@tests/roblox/run")

local passed, failed, report = run()

print(report)

-- a failing suite has to fail the TASK, not just print. the runner reads the
-- task state, and an error is the only signal the api carries back out
if failed > 0 then
  error(`{failed} of {passed + failed} engine tests failed`, 0)
end
