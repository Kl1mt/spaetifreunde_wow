-- luacheck config for the SpaetiProbe diagnostic addon only (tools/SpaetiProbe).
-- Run from this folder: luacheck .
std = "lua51"
max_line_length = false

-- Globals the probe writes.
globals = {
    "SpaetiProbeDB",
    "SlashCmdList",
    "SLASH_SPAETIPROBE1",
    "SLASH_SPAETIPROBE_ASCII1",
    "SLASH_SPAETIPROBE_UML1",
    "SLASH_SPAETIPROBE_UMLUP1",
}

-- Almost all WoW API access goes through _G lookups guarded by type() checks.
read_globals = {}

files["tests/"] = {
    -- The mock harness builds fake WoW environments on purpose.
    globals = { "_G" },
    allow_defined_top = true,
}
