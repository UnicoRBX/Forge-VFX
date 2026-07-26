-- darklua bundles this whole require graph into the one script string the
-- create-task api accepts, which is why the specs reach the engine without a
-- place upload
local run = require("@tests/roblox/run")

local passed, failed, report = run()

print(report)

-- a failing suite has to fail the TASK, not just print. the runner reads the
-- task state, and an error is the only signal the api carries back out
if failed > 0 then
  error(`{failed} of {passed + failed} engine tests failed`, 0)
end
