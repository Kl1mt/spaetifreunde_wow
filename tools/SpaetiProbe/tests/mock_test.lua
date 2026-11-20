-- Mock harness for SpaetiProbe (not loaded by the TOC).
-- Run from the repo root: lua5.1 tools/SpaetiProbe/tests/mock_test.lua
-- Loads Probe.lua into fake WoW environments and checks it never errors.

local PROBE = (arg and arg[0] or ""):gsub("tests/mock_test%.lua$", "") .. "Probe.lua"

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

local function baseEnv()
    local env = {
        string = string, table = table, math = math, pairs = pairs, ipairs = ipairs, type = type,
        tostring = tostring, tonumber = tonumber, select = select, pcall = pcall, error = error,
        setmetatable = setmetatable, print = function() end, next = next,
    }
    env._G = env
    return env
end

-- Frame mock: any unknown method is a no-op.
local function mockFrames(env, opts)
    env.frames = {}
    local function obj()
        local o = { scripts = {}, events = {} }
        return setmetatable(o, { __index = function(_, k)
            if k == "SetScript" then
                return function(self, s, f) self.scripts[s] = f end
            elseif k == "RegisterEvent" then
                return function(self, e)
                    if opts.unknownEvents and opts.unknownEvents[e] then
                        error("Attempt to register unknown event \"" .. e .. "\"")
                    end
                    self.events[e] = true
                end
            elseif k == "CreateFontString" or k == "CreateTexture" then
                return function() return obj() end
            end
            return function() end
        end })
    end
    env.CreateFrame = function()
        local f = obj()
        env.frames[#env.frames + 1] = f
        return f
    end
    env.SlashCmdList = {}
    env.UIParent = obj()
    env.UISpecialFrames = {}
end

local function fire(env, event, ...)
    for _, f in ipairs(env.frames or {}) do
        if f.events[event] and f.scripts.OnEvent then
            f.scripts.OnEvent(f, event, ...)
        end
    end
end

local function tick(env, seconds)
    for _ = 1, seconds * 2 do
        env.now = (env.now or 0) + 0.5
        for _, f in ipairs(env.frames or {}) do
            if f.scripts.OnUpdate then
                f.scripts.OnUpdate(f, 0.5)
            end
        end
    end
end

local function slash(env, key, msg)
    local fn = env.SlashCmdList and env.SlashCmdList[key]
    if fn then
        fn(msg)
    end
end

local function load(env)
    local chunk = assert(loadfile(PROBE))
    setfenv(chunk, env)
    local ok, err = pcall(chunk, "SpaetiProbe", {})
    check(ok, "load: " .. tostring(err))
end

local function runAll(env)
    fire(env, "ADDON_LOADED", "SpaetiProbe")
    fire(env, "PLAYER_LOGIN")
    fire(env, "PLAYER_ENTERING_WORLD", true, false)
    fire(env, "CHAT_MSG_SYSTEM", "Klaus ist jetzt online.")
    for _, cmd in ipairs({ "", "anon", "ping", "burst", "echo", "gildeslash", "gildetimer", "font",
        "system", "hilfe", "echo stop" }) do
        slash(env, "SPAETIPROBE", cmd)
    end
    slash(env, "SPAETIPROBE_UML", "")
    slash(env, "SPAETIPROBE_UMLUP", "anon")
    tick(env, 130)
    fire(env, "ENCOUNTER_START", 1, "Boss", 1, 5)
    fire(env, "PLAYER_REGEN_DISABLED")
    fire(env, "ENCOUNTER_END", 1, "Boss", 1, 5, 1)
    slash(env, "SPAETIPROBE", "")
end

-- Scenario 1: nothing at all (no CreateFrame, no SlashCmdList).
do
    local env = baseEnv()
    load(env)
end

-- Scenario 2: frames and slash only, every other API missing.
do
    local env = baseEnv()
    mockFrames(env, { unknownEvents = { ADDON_RESTRICTION_STATE_CHANGED = true } })
    load(env)
    runAll(env)
    check(type(env.SpaetiProbeDB) == "table", "scenario 2: DB created")
    local rep = env.SpaetiProbeDB and env.SpaetiProbeDB.lastReport or ""
    check(rep:find("C_ChatInfo = nil", 1, true), "scenario 2: missing API reported")
    check(rep:find("Attempt to register unknown event", 1, true), "scenario 2: restriction event failure reported")
    check(#env.SpaetiProbeDB.errors == 0, "scenario 2: no caught errors, got: "
        .. table.concat(env.SpaetiProbeDB.errors, " | "))
end

-- Scenario 3: a plausible Forever-like API set.
do
    local env = baseEnv()
    mockFrames(env, {})
    env.date = os.date
    env.time = os.time
    env.GetTime = function() return env.now or 0 end
    env.strlower = string.lower
    env.strupper = string.upper
    env.issecretvalue = function(v) return v == "SECRET" end
    env.GetBuildInfo = function() return "1.60.1", "12345", "Nov 1 2026", 16001 end
    env.WOW_PROJECT_ID = 21
    env.GetLocale = function() return "deDE" end
    env.UnitName = function() return "Klaus" end
    env.UnitFullName = function() return "Klaus", "Spandau" end
    env.UnitGUID = function() return "Player-1234-0ABCDEF0" end
    env.IsInGuild = function() return true end
    env.GetGuildInfo = function() return "Spätifreunde Spandau", "Officer", 1 end
    env.ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h ist jetzt online."
    env.RANDOM_ROLL_RESULT = "%s würfelt. Ergebnis: %d (%d-%d)"
    local roster = {
        { "Klaus-Spandau", "Officer", 1, 60, "Krieger", "", "", "", true, 0, "WARRIOR", 0, 0, false, false, 0,
            "Player-1234-0ABCDEF0" },
        { "Bärbel-Spandau", "Stammkunde", 3, 42, "Magier", "", "", "", false, 0, "MAGE", 0, 0, false, false, 0,
            "Player-1234-0BBBBBB0" },
    }
    env.GetNumGuildMembers = function() return #roster, 1 end
    env.GetGuildRosterInfo = function(i) return unpack(roster[i]) end
    env.Ambiguate = function(name, mode)
        if mode == "none" or mode == "short" then
            return (name:gsub("%-.*$", ""))
        end
        return name
    end
    env.C_Timer = { After = function() end }
    local sent = {}
    local locked = false
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        SendAddonMessage = function(_, msg) sent[#sent + 1] = msg; return (#sent > 10) and 3 or 0 end,
        InChatMessagingLockdown = function() return locked end,
        SendChatMessage = function() end,
    }
    env.Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 } }
    env.IsInInstance = function() return locked, locked and "party" or "none" end
    load(env)
    fire(env, "ADDON_LOADED", "SpaetiProbe")
    fire(env, "PLAYER_LOGIN")
    fire(env, "CHAT_MSG_SYSTEM", "|Hplayer:Bärbel-Spandau|h[Bärbel]|h ist jetzt online.")
    fire(env, "CHAT_MSG_SYSTEM", "SECRET")
    slash(env, "SPAETIPROBE", "burst")
    slash(env, "SPAETIPROBE", "echo")
    -- Receiver side: echo from Bärbel with a gap (simulated dungeon entry).
    for seq = 1, 10 do
        if seq < 4 or seq > 7 then
            fire(env, "CHAT_MSG_ADDON", "SpaetiProbe", "ECHO:4242:" .. seq .. ":60", "GUILD", "Bärbel-Spandau")
        end
        if seq == 5 then
            locked = true
        end
        tick(env, 2)
    end
    locked = false
    fire(env, "CHAT_MSG_ADDON", "OtherPrefix", "x", "GUILD", "Bärbel-Spandau")
    fire(env, "CHAT_MSG_ADDON", "SpaetiProbe", "PING:1:1", "GUILD", "Bärbel-Spandau")
    fire(env, "CHAT_MSG_ADDON", "SECRET", "PING:1:1", "GUILD", "Bärbel-Spandau")
    slash(env, "SPAETIPROBE", "gildeslash")
    fire(env, "CHAT_MSG_GUILD", "[SpaetiProbe] Gilden-Test (slash) - bitte ignorieren", "Klaus-Spandau")
    slash(env, "SPAETIPROBE_UML", "")
    local db = env.SpaetiProbeDB
    local rep = db.lastReport
    check(#db.errors == 0, "scenario 3: no caught errors, got: " .. table.concat(db.errors, " | "))
    check(rep:find("alias=/spätiprobe", 1, true), "scenario 3: alias recorded")
    check(rep:find("[ERR_FRIEND_ONLINE_SS]", 1, true), "scenario 3: online message classified")
    check(rep:find("<secret>", 1, true), "scenario 3: secret system line guarded")
    check(rep:find("fehlt 4-7", 1, true), "scenario 3: echo gap recorded")
    check(rep:find("exakt (Zeile 2)", 1, true), "scenario 3: roster match")
    check(rep:find("3(AddonMessageThrottle)", 1, true), "scenario 3: burst throttle code named")
    check(rep:find("angekommen: ja", 1, true), "scenario 3: guild chat arrival seen")
    check(not rep:find("OtherPrefix", 1, true), "scenario 3: foreign prefix ignored")
    check(#db.addonIn == 2, "scenario 3: two addon log entries (first echo + ping), got " .. #db.addonIn)
    slash(env, "SPAETIPROBE", "anon")
    local an = db.lastReport
    check(not an:find("Bärbel", 1, true), "scenario 3: anon hides Bärbel")
    check(not an:find("Klaus", 1, true), "scenario 3: anon hides Klaus")
    check(not an:find("0BBBBBB0", 1, true), "scenario 3: anon hides GUID tail")
    check(an:find("Member", 1, true), "scenario 3: anon aliases present")
    if os.getenv("SHOW_REPORT") then
        print(an)
    end
end

if failures > 0 then
    print(failures .. " check(s) failed")
    os.exit(1)
end
print("SpaetiProbe mock test: all checks passed")
