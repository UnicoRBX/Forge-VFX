local process = require("@lune/process")
local harness = require("@tests/harness")

require("@tests/schema.spec")
require("@tests/schema_curves.spec")
require("@tests/modifiers_eval.spec")
require("@tests/value.spec")
require("@tests/modifier_codec.spec")
require("@tests/modifier_frame.spec")

process.exit(harness.run())
