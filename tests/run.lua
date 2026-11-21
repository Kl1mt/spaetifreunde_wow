-- tests/run.lua: run all plain-Lua tests. From the repo root: lua5.1 tests/run.lua
local root = (arg and arg[0] or ""):match("^(.-)tests/run%.lua$") or "./"
package.path = root .. "tests/?.lua;" .. package.path

local T = require("helpers.wow")
for _, name in ipairs({ "test_logic", "test_sync", "test_storm" }) do
    local before = T.failures
    local chunk = assert(loadfile(root .. "tests/" .. name .. ".lua"))
    local ok, err = pcall(chunk)
    if not ok then
        T.failures = T.failures + 1
        print("ERROR in " .. name .. ": " .. tostring(err))
    end
    print(("%-12s %s"):format(name, (T.failures == before) and "ok" or "FAILED"))
end
local failures = T.Summary("all tests")
os.exit(failures == 0 and 0 or 1)
