-- entry point for the open cloud engine lane, uploaded as the task script
--
-- deliberately outside the synced tree: test.project.json maps src, pkg and
-- tests/roblox only, so this file reaches the engine as the task body rather
-- than as a module inside the place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local run = require(ReplicatedStorage.ForgeVFXTest.tests.run)

local passed, failed, report = run()

print(report)

-- a failing suite has to fail the TASK, not just print. the runner reads the
-- task state, and an error is the only signal the api carries back out
if failed > 0 then
  error(`{failed} of {passed + failed} engine tests failed`, 0)
end
