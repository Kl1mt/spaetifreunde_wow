-- SpaetiProbe: diagnostic addon for WoW: Forever (subtask S1).
-- Answers the in-game unknowns before the real addon depends on them.
-- Rule: the probe must never raise a Lua error. Every WoW API access goes
-- through resolve()/call(), which check existence and wrap the call in pcall.
-- Almost everything here is VERIFY IN-GAME by design.

local ADDON = (...) or "SpaetiProbe"
local VERSION = "0.1.0"
local PREFIX = "SpaetiProbe"

local SYSTEM_CAPTURE_SECONDS = 600
local MAX_SYSTEM = 100
local MAX_TIMELINE = 200
local MAX_ADDON_IN = 200
local MAX_SENDS = 150
local MAX_EVENTS = 100
local MAX_ERRORS = 50
local MAX_ECHO_RUNS = 20
local MAX_SLASH = 30
local SAMPLE_INTERVAL = 5
local ECHO_INTERVAL = 2
local ECHO_COUNT = 60
local BURST_COUNT = 12
local ROSTER_ROWS = 5
local ROSTER_SCAN_MAX = 1000
local FONT_TEST = "äöüß ÄÖÜ „Späti“"

local DB                      -- SpaetiProbeDB, set on ADDON_LOADED
local MISSING = {}            -- sentinel: API does not exist
local anon                    -- anonymisation state while building an anon report
local session = {
    clock = 0,                -- seconds since load, driven by OnUpdate
    systemUntil = nil,        -- capture CHAT_MSG_SYSTEM until this clock value
    systemDropped = 0,
    lastState = nil,
    nextSample = SAMPLE_INTERVAL,
    rosterUpdates = 0,
    registrations = {},       -- event -> "ok" or error text
    echo = nil,               -- running echo sender
    pingCount = 0,
    prefixResult = "noch nicht registriert",
}
local tasks = {}
local driver                  -- frame with OnEvent / OnUpdate
local report                  -- report window widgets
local handlers = {}

---------------------------------------------------------------------------
-- Safe helpers
---------------------------------------------------------------------------

local function index(t, k)
    return t[k]
end

local function resolve(path)
    local cur = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then
            return nil
        end
        local ok, v = pcall(index, cur, part)
        if not ok then
            return nil
        end
        cur = v
    end
    return cur
end

local function call(path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then
        return false, MISSING
    end
    return pcall(fn, ...)
end

local function packed(ok, ...)
    return ok, { n = select("#", ...), ... }
end

local function isSecret(v)
    local f = resolve("issecretvalue")
    if type(f) ~= "function" then
        return false
    end
    local ok, r = pcall(f, v)
    return ok and r == true
end

local str

local function shallow(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    for i = 1, math.min(#keys, 40) do
        local k = keys[i]
        local v = t[k]
        parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{...}" or str(v))
    end
    if #keys > 40 then
        parts[#parts + 1] = "..."
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

str = function(v)
    if v == nil then
        return "nil"
    end
    if isSecret(v) then
        return "<secret>"
    end
    if type(v) == "table" then
        local ok, s = pcall(shallow, v)
        return ok and s or "<table>"
    end
    local ok, s = pcall(tostring, v)
    if not ok or type(s) ~= "string" then
        return "<tostring-fehler>"
    end
    return (s:gsub("\r", "\\r"):gsub("\n", "\\n"))
end

local function joinR(r)
    if r.n == 0 then
        return "(keine Rueckgabe)"
    end
    local parts = {}
    for i = 1, r.n do
        parts[i] = str(r[i])
    end
    return table.concat(parts, ", ")
end

-- Calls an API and formats the result as one string.
local function fmtCall(path, ...)
    local ok, r = packed(call(path, ...))
    if not ok then
        if r[1] == MISSING then
            return "FEHLT"
        end
        return "FEHLER: " .. str(r[1])
    end
    return joinR(r)
end

-- First return value or nil.
local function v1(path, ...)
    local ok, a = call(path, ...)
    if ok then
        return a
    end
    return nil
end

local function stamp()
    local d = resolve("date")
    local s = "?"
    if type(d) == "function" then
        local ok, v = pcall(d, "%H:%M:%S")
        if ok then
            s = v
        end
    end
    return s .. string.format(" +%.1fs", session.clock)
end

local function out(msg)
    local text = "|cffe8a33dSpaetiProbe|r: " .. tostring(msg)
    local cf = resolve("DEFAULT_CHAT_FRAME")
    if type(cf) == "table" and type(cf.AddMessage) == "function" then
        pcall(cf.AddMessage, cf, text)
    elseif type(print) == "function" then
        pcall(print, text)
    end
end

local function ensureDB()
    if DB then
        return
    end
    if type(_G.SpaetiProbeDB) ~= "table" then
        _G.SpaetiProbeDB = {}
    end
    DB = _G.SpaetiProbeDB
    DB.dbVersion = 1
    DB.sessions = (tonumber(DB.sessions) or 0) + 1
    for _, k in ipairs({ "slash", "system", "addonIn", "sends", "timeline", "echoRx", "echoTx",
        "guildChat", "events", "errors" }) do
        if type(DB[k]) ~= "table" then
            DB[k] = {}
        end
    end
end

-- Appends to a list in DB. ring=true drops the oldest entry when full.
local function push(key, entry, max, ring)
    ensureDB()
    local list = DB[key]
    if #list >= max then
        if not ring then
            return false
        end
        table.remove(list, 1)
    end
    list[#list + 1] = entry
    return true
end

local function logError(where, err)
    push("errors", stamp() .. " " .. where .. ": " .. str(err), MAX_ERRORS, true)
end

local function escapePattern(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Turns a WoW format string ("%s has come online", "%1$s") into a Lua pattern.
local function fmtToPattern(fmt)
    if type(fmt) ~= "string" or isSecret(fmt) then
        return nil
    end
    local p = fmt:gsub("%%%d+%$s", "\1"):gsub("%%%d+%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    p = escapePattern(p)
    p = p:gsub("\1", "(.+)"):gsub("\2", "(%%-?%%d+)")
    return "^" .. p .. "$"
end

---------------------------------------------------------------------------
-- Anonymisation (only applied while building an anon report)
---------------------------------------------------------------------------

local function shape(s)
    -- Keep separators so the name format stays visible, hide the letters.
    return (s:gsub("[%w\128-\255]", "x"))
end

-- Display a character name (anonymised in anon mode).
local function N(name)
    local s = str(name)
    if not anon or s == "nil" or s == "<secret>" or s == "" then
        return s
    end
    local cached = anon.full[s]
    if cached then
        return cached
    end
    local base, rest = s:match("^([^%-]+)%-(.+)$")
    base = base or s
    local id = anon.base[base]
    if not id then
        anon.n = anon.n + 1
        id = anon.n
        anon.base[base] = id
    end
    local alias = "Member" .. id .. "{" .. shape(base) .. "}"
    if rest then
        alias = alias .. "-{" .. shape(rest) .. "}"
    end
    anon.full[s] = alias
    return alias
end

-- Display a GUID (shortened in anon mode, format kept).
local function G(guid)
    local s = str(guid)
    if not anon or s == "nil" or s == "<secret>" then
        return s
    end
    local id = anon.guid[s]
    if not id then
        anon.gn = anon.gn + 1
        id = anon.gn
        anon.guid[s] = id
    end
    local parts, i = {}, 0
    for part in s:gmatch("[^%-]+") do
        i = i + 1
        if i == 1 or (i == 2 and part:match("^%d+$")) then
            parts[i] = part
        else
            parts[i] = string.rep("x", #part)
        end
    end
    return table.concat(parts, "-") .. "#" .. id
end

-- Replace known names inside free text (system messages, chat lines).
local function anonText(text)
    if not anon then
        return text
    end
    text = text:gsub("|Hplayer:([^|]*)|h%[([^%]]*)%]|h", function(target, shown)
        return "|Hplayer:" .. N(target) .. "|h[" .. N(shown) .. "]|h"
    end)
    local keys = {}
    for k in pairs(anon.full) do
        if #k >= 3 then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys, function(a, b)
        return #a > #b
    end)
    for _, k in ipairs(keys) do
        text = text:gsub(escapePattern(k), (anon.full[k]:gsub("%%", "%%%%")))
    end
    return text
end

---------------------------------------------------------------------------
-- Scheduler (OnUpdate based)
---------------------------------------------------------------------------

local function schedule(delay, fn)
    if driver then
        tasks[#tasks + 1] = { at = session.clock + delay, fn = fn }
        return true
    end
    local after = resolve("C_Timer.After")
    if type(after) == "function" then
        return (pcall(after, delay, fn))
    end
    return false
end

local function runTasks()
    local i = 1
    while i <= #tasks do
        local t = tasks[i]
        if t.at <= session.clock then
            table.remove(tasks, i)
            local ok, err = pcall(t.fn)
            if not ok then
                logError("task", err)
            end
        else
            i = i + 1
        end
    end
end

---------------------------------------------------------------------------
-- State / lockdown timeline
---------------------------------------------------------------------------

local function stateString()
    local parts = {}
    parts[#parts + 1] = "lockdown=" .. fmtCall("C_ChatInfo.InChatMessagingLockdown")
    parts[#parts + 1] = "instanz=" .. fmtCall("IsInInstance")
    local ok, r = packed(call("GetInstanceInfo"))
    if ok then
        parts[#parts + 1] = "info=" .. str(r[1]) .. "/" .. str(r[2]) .. "/diff" .. str(r[3]) .. "/id" .. str(r[8])
    end
    parts[#parts + 1] = "kampf=" .. fmtCall("InCombatLockdown")
    local zone = v1("GetRealZoneText") or v1("GetZoneText")
    parts[#parts + 1] = "zone=" .. str(zone)
    return table.concat(parts, " ")
end

local function timeline(event, extra, onlyIfChanged)
    local s = stateString()
    if onlyIfChanged and s == session.lastState then
        return
    end
    session.lastState = s
    local line = stamp() .. " " .. event
    if extra and extra ~= "" then
        line = line .. " [" .. extra .. "]"
    end
    push("timeline", line .. " " .. s, MAX_TIMELINE, true)
end

---------------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------------

local function requestRoster()
    if resolve("C_GuildInfo.GuildRoster") then
        call("C_GuildInfo.GuildRoster")
    else
        call("GuildRoster")
    end
end

local function numMembers()
    local ok, n = call("GetNumGuildMembers")
    if ok and type(n) == "number" and not isSecret(n) then
        return math.min(n, ROSTER_SCAN_MAX)
    end
    return 0
end

-- Returns match kind ("exakt", "ambiguate", "kein Treffer", ...) and guid.
local function rosterMatch(sender)
    if isSecret(sender) or type(sender) ~= "string" then
        return "sender nicht pruefbar", nil
    end
    local n = numMembers()
    if n == 0 then
        return "roster leer", nil
    end
    local senderNone = v1("Ambiguate", sender, "none")
    for i = 1, n do
        local ok, r = packed(call("GetGuildRosterInfo", i))
        local name = ok and r[1] or nil
        if type(name) == "string" and not isSecret(name) then
            if name == sender then
                return "exakt (Zeile " .. i .. ")", r[17]
            end
            local nameNone = v1("Ambiguate", name, "none")
            if senderNone and nameNone and nameNone == senderNone then
                return "nach Ambiguate(none) (Zeile " .. i .. ", Roster='" .. N(name) .. "')", r[17]
            end
        end
    end
    return "kein Treffer", nil
end

---------------------------------------------------------------------------
-- Addon messages
---------------------------------------------------------------------------

local function enumName(enumPath, value)
    local e = resolve(enumPath)
    if type(e) ~= "table" or value == nil or isSecret(value) then
        return ""
    end
    for k, v in pairs(e) do
        if v == value then
            return "(" .. tostring(k) .. ")"
        end
    end
    return ""
end

local function registerPrefix()
    local ok, r = packed(call("C_ChatInfo.RegisterAddonMessagePrefix", PREFIX))
    if not ok then
        session.prefixResult = (r[1] == MISSING) and "FEHLT" or ("FEHLER: " .. str(r[1]))
    else
        session.prefixResult = joinR(r) .. enumName("Enum.RegisterAddonMessagePrefixResult", r[1])
    end
end

local function sendAddon(kind, payload)
    local lock = fmtCall("C_ChatInfo.InChatMessagingLockdown")
    local ok, r = packed(call("C_ChatInfo.SendAddonMessage", PREFIX, payload, "GUILD"))
    local result
    if not ok then
        result = (r[1] == MISSING) and "FEHLT" or ("FEHLER: " .. str(r[1]))
    else
        result = joinR(r) .. enumName("Enum.SendAddonMessageResult", r[1])
    end
    push("sends", stamp() .. " " .. kind .. " '" .. payload .. "' -> " .. result .. " | lockdown=" .. lock,
        MAX_SENDS, true)
    return result
end

local function runId()
    return tostring(math.random(1000, 9999))
end

local function cmdPing()
    session.pingCount = session.pingCount + 1
    local result = sendAddon("ping", "PING:" .. runId() .. ":" .. session.pingCount)
    out("Ping an GILDE gesendet, Ergebnis: " .. result)
end

local function cmdBurst()
    local run = runId()
    local results = {}
    for i = 1, BURST_COUNT do
        results[#results + 1] = sendAddon("burst", "BURST:" .. run .. ":" .. i)
    end
    out("Burst: " .. BURST_COUNT .. " Nachrichten gesendet. Ergebnisse: " .. table.concat(results, " / "))
end

local function cmdEcho(arg)
    if arg == "stop" then
        if session.echo then
            session.echo.stopped = true
            out("Echo gestoppt.")
        else
            out("Kein Echo aktiv.")
        end
        return
    end
    if session.echo and not session.echo.stopped and not session.echo.done then
        out("Echo laeuft schon (/sfprobe echo stop zum Abbrechen).")
        return
    end
    local tx = { run = runId(), started = stamp(), sent = 0, codes = {}, failures = {} }
    session.echo = tx
    push("echoTx", tx, MAX_ECHO_RUNS, true)
    local function step(seq)
        if tx.stopped then
            tx.ended = stamp() .. " (abgebrochen)"
            return
        end
        local result = sendAddon("echo", "ECHO:" .. tx.run .. ":" .. seq .. ":" .. ECHO_COUNT)
        tx.sent = seq
        tx.codes[result] = (tx.codes[result] or 0) + 1
        if not result:match("^0") and not result:match("^true") then
            if #tx.failures < 60 then
                tx.failures[#tx.failures + 1] = "#" .. seq .. " " .. result .. " " .. stateString()
            end
        end
        if seq < ECHO_COUNT then
            schedule(ECHO_INTERVAL, function()
                step(seq + 1)
            end)
        else
            tx.done = true
            tx.ended = stamp()
            out("Echo fertig (" .. ECHO_COUNT .. " Nachrichten).")
        end
    end
    out("Echo startet: " .. ECHO_COUNT .. " Nachrichten, alle " .. ECHO_INTERVAL .. " s (Lauf " .. tx.run .. ").")
    step(1)
end

local function onEchoReceived(sender, run, seq, total)
    local key = str(sender) .. "#" .. run
    local rec
    for _, r in ipairs(DB.echoRx) do
        if r.key == key then
            rec = r
            break
        end
    end
    local first = false
    if not rec then
        first = true
        rec = { key = key, sender = str(sender), run = run, total = total, first = seq, last = seq,
            count = 0, gaps = {}, firstAt = stamp(), lastClock = session.clock, maxPause = 0 }
        if seq > 1 then
            rec.gaps[#rec.gaps + 1] = "Start fehlt: 1-" .. (seq - 1)
        end
        push("echoRx", rec, MAX_ECHO_RUNS, true)
    end
    rec.count = rec.count + 1
    local pause = session.clock - rec.lastClock
    if pause > rec.maxPause then
        rec.maxPause = pause
    end
    if seq > rec.last + 1 and #rec.gaps < 40 then
        rec.gaps[#rec.gaps + 1] = string.format("fehlt %d-%d (Pause %.1fs, angekommen %s) %s",
            rec.last + 1, seq - 1, pause, stamp(), stateString())
    elseif seq <= rec.last and not first and #rec.gaps < 40 then
        rec.gaps[#rec.gaps + 1] = "Reihenfolge/Duplikat: #" .. seq .. " nach #" .. rec.last
    end
    if seq > rec.last then
        rec.last = seq
    end
    rec.lastClock = session.clock
    rec.lastAt = stamp()
    return first
end

handlers.CHAT_MSG_ADDON = function(prefix, text, channel, sender, target)
    if isSecret(prefix) or prefix ~= PREFIX then
        return
    end
    local t = str(text)
    local run, seq, total = t:match("^ECHO:(%d+):(%d+):(%d+)$")
    if run then
        if not onEchoReceived(sender, run, tonumber(seq), tonumber(total)) then
            return -- only the first echo message per run goes into the log
        end
    end
    local amb = {}
    for _, mode in ipairs({ "none", "short", "guild", "mail", "all" }) do
        amb[mode] = fmtCall("Ambiguate", sender, mode)
    end
    local match, guid = rosterMatch(sender)
    local own = v1("UnitName", "player")
    local isOwn = "?"
    if type(own) == "string" and type(sender) == "string" and not isSecret(sender) and not isSecret(own) then
        isOwn = (sender == own or amb.none == own) and "ja" or "nein"
    end
    push("addonIn", { at = stamp(), text = t, channel = str(channel),
        sender = isSecret(sender) and "<secret>" or sender, target = str(target),
        senderType = type(sender), amb = amb, match = match, guid = guid, own = isOwn,
        state = stateString() }, MAX_ADDON_IN, true)
end

---------------------------------------------------------------------------
-- System chat
---------------------------------------------------------------------------

local SYSTEM_GLOBALS = {
    "ERR_FRIEND_ONLINE_SS", "ERR_FRIEND_OFFLINE_S", "RANDOM_ROLL_RESULT",
    "ERR_GUILD_JOIN_S", "ERR_GUILD_LEAVE_S", "ERR_GUILD_REMOVE_SS",
    "ERR_GUILD_PROMOTE_SSS", "ERR_GUILD_DEMOTE_SSS", "ERR_CHAT_THROTTLED",
}

local function classifySystem(text)
    for _, name in ipairs(SYSTEM_GLOBALS) do
        local p = fmtToPattern(resolve(name))
        if p then
            local ok, m = pcall(string.match, text, p)
            if ok and m then
                return name
            end
        end
    end
    return nil
end

handlers.CHAT_MSG_SYSTEM = function(text)
    if not session.systemUntil or session.clock > session.systemUntil then
        return
    end
    local entry = { at = stamp() }
    if isSecret(text) then
        entry.text = "<secret>"
    else
        entry.text = str(text)
        entry.tag = classifySystem(entry.text)
    end
    if not push("system", entry, MAX_SYSTEM, false) then
        session.systemDropped = session.systemDropped + 1
    end
end

local function blocked(event, addonName, fn)
    if isSecret(addonName) or addonName ~= ADDON then
        return
    end
    local line = stamp() .. " " .. event .. " " .. str(fn)
    push("events", line, MAX_EVENTS, true)
end

handlers.ADDON_ACTION_BLOCKED = function(addonName, fn)
    blocked("ADDON_ACTION_BLOCKED", addonName, fn)
end

handlers.ADDON_ACTION_FORBIDDEN = function(addonName, fn)
    blocked("ADDON_ACTION_FORBIDDEN", addonName, fn)
end

---------------------------------------------------------------------------
-- Lifecycle and timeline events
---------------------------------------------------------------------------

local function argsString(...)
    return joinR({ n = select("#", ...), ... })
end

handlers.ADDON_LOADED = function(name)
    if name ~= ADDON then
        return
    end
    DB = nil -- SavedVariables are loaded now; bind to the real table
    ensureDB()
    DB.probeVersion = VERSION
    registerPrefix()
end

handlers.PLAYER_LOGIN = function()
    ensureDB()
    session.systemUntil = session.clock + SYSTEM_CAPTURE_SECONDS
    session.systemDropped = 0
    DB.system = {} -- each login gets its own 10-minute capture window
    requestRoster()
    timeline("PLAYER_LOGIN")
end

handlers.PLAYER_ENTERING_WORLD = function(...)
    timeline("PLAYER_ENTERING_WORLD", argsString(...))
end

handlers.ZONE_CHANGED_NEW_AREA = function()
    timeline("ZONE_CHANGED_NEW_AREA")
end

handlers.ENCOUNTER_START = function(...)
    timeline("ENCOUNTER_START", argsString(...))
end

handlers.ENCOUNTER_END = function(...)
    timeline("ENCOUNTER_END", argsString(...))
end

handlers.PLAYER_REGEN_DISABLED = function()
    timeline("PLAYER_REGEN_DISABLED")
end

handlers.PLAYER_REGEN_ENABLED = function()
    timeline("PLAYER_REGEN_ENABLED")
end

handlers.ADDON_RESTRICTION_STATE_CHANGED = function(...)
    timeline("ADDON_RESTRICTION_STATE_CHANGED", argsString(...))
end

handlers.GUILD_ROSTER_UPDATE = function()
    session.rosterUpdates = session.rosterUpdates + 1
end

local function onUpdate(_, elapsed)
    if type(elapsed) ~= "number" then
        return
    end
    session.clock = session.clock + elapsed
    if #tasks > 0 then
        runTasks()
    end
    if session.clock >= session.nextSample then
        session.nextSample = session.clock + SAMPLE_INTERVAL
        if DB then
            timeline("5s", nil, true)
        end
    end
end

---------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------

local API_LIST = {
    "C_ChatInfo", "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.IsAddonMessagePrefixRegistered",
    "C_ChatInfo.SendAddonMessage", "C_ChatInfo.SendAddonMessageLogged", "C_ChatInfo.SendChatMessage",
    "C_ChatInfo.InChatMessagingLockdown", "C_ChatInfo.GetRegisteredAddonMessagePrefixes",
    "SendChatMessage", "Ambiguate",
    "C_GuildInfo", "C_GuildInfo.GuildRoster", "C_GuildInfo.IsGuildOfficer", "C_GuildInfo.CanEditOfficerNote",
    "C_GuildInfo.MemberExistsByName", "C_GuildInfo.GetGuildRankOrder", "C_GuildInfo.GuildControlGetRankFlags",
    "C_GuildInfo.GetPreferredPlaySettings", "C_GuildInfo.QueryGuildMembersForRecipe",
    "GuildRoster", "GetGuildRosterInfo", "GetNumGuildMembers", "GetGuildInfo", "IsInGuild", "IsGuildLeader",
    "GuildControlGetNumRanks", "GuildControlGetRankName", "CanEditOfficerNote",
    "C_Club", "C_Club.GetGuildClubId", "C_Club.GetClubInfo",
    "issecretvalue", "canaccessvalue", "issecrettable", "C_Secrets", "C_RestrictedActions",
    "Settings", "Settings.RegisterVerticalLayoutCategory", "Settings.RegisterCanvasLayoutCategory",
    "Settings.RegisterAddOnCategory", "Settings.OpenToCategory",
    "AddonCompartmentFrame", "AddonCompartmentFrame.RegisterAddon",
    "Menu", "Menu.ModifyMenu", "MenuUtil", "MenuUtil.CreateContextMenu",
    "ScrollUtil", "ScrollUtil.InitScrollBoxListWithScrollBar", "CreateScrollBoxListLinearView", "CreateDataProvider",
    "C_Timer", "C_Timer.After", "C_Timer.NewTicker", "RandomRoll",
    "IsTrialAccount", "IsVeteranTrialAccount", "GetServerTime", "C_DateAndTime",
    "C_DateAndTime.GetCurrentCalendarTime", "C_DateAndTime.GetServerTimeLocal",
    "C_Calendar", "C_Calendar.OpenCalendar", "C_Calendar.GetNumDayEvents", "C_Calendar.GetDayEvent",
    "C_Calendar.CreateGuildSignUpEvent", "C_Calendar.CreateGuildAnnouncementEvent", "C_Calendar.EventSignUp",
    "C_Calendar.CanAddEvent", "C_Calendar.GetEventInfo",
    "GetNumGuildTradeSkill", "GetGuildTradeSkillInfo", "QueryGuildRecipes", "C_TradeSkillUI",
    "GetProfessions", "GetProfessionInfo",
    "C_AddOns", "C_AddOns.GetAddOnMetadata", "C_AddOns.IsAddOnLoaded", "GetAddOnMetadata",
    "C_EncodingUtil", "C_EncodingUtil.SerializeCBOR", "C_EncodingUtil.CompressString",
    "C_EncodingUtil.EncodeBase64", "C_EventUtils", "C_EventUtils.IsEventValid",
    "UnitName", "UnitFullName", "UnitGUID", "GetPlayerInfoByGUID", "GetNormalizedRealmName", "GetRealmName",
    "IsInInstance", "GetInstanceInfo", "InCombatLockdown", "GetRealZoneText",
    "CreateFrame", "BackdropTemplateMixin", "UISpecialFrames", "hooksecurefunc",
    "ChatFrame_AddMessageEventFilter", "StaticPopup_Show", "PlaySound", "strlower", "strupper", "utf8",
}

local NAMESPACES = { "C_ChatInfo", "C_GuildInfo", "C_RestrictedActions", "C_Secrets" }

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    return keys
end

local function buildReport(anonymise)
    anon = anonymise and { full = {}, base = {}, n = 0, guid = {}, gn = 0 } or nil
    ensureDB()
    local L = {}
    local function add(...)
        L[#L + 1] = table.concat({ ... })
    end
    local function section(title)
        add("")
        add("== ", title, " ==")
    end

    add("SpaetiProbe ", VERSION, " Bericht, ", stamp(), ", Sitzung ", str(DB.sessions),
        anonymise and ", ANONYMISIERT" or "")
    add("Hinweis: '||' im Text ist ein einzelnes |-Zeichen.")

    section("Build")
    add("GetBuildInfo = ", fmtCall("GetBuildInfo"))
    for _, g in ipairs({ "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC", "WOW_PROJECT_CAMELOT",
        "LE_EXPANSION_LEVEL_CURRENT" }) do
        add(g, " = ", str(resolve(g)))
    end
    add("GetExpansionLevel = ", fmtCall("GetExpansionLevel"))
    add("GetLocale = ", fmtCall("GetLocale"))
    add("GetServerTime = ", fmtCall("GetServerTime"), " | time = ", fmtCall("time"))
    add("date lokal = ", fmtCall("date", "%Y-%m-%d %H:%M:%S"), " | date UTC = ", fmtCall("date", "!%Y-%m-%d %H:%M:%S"))
    add("C_DateAndTime.GetCurrentCalendarTime = ", fmtCall("C_DateAndTime.GetCurrentCalendarTime"))

    section("API-Existenz (type)")
    for _, path in ipairs(API_LIST) do
        add(path, " = ", type(resolve(path)))
    end

    section("Namespaces (Schluessel)")
    for _, ns in ipairs(NAMESPACES) do
        local t = resolve(ns)
        if type(t) == "table" then
            add(ns, ": ", table.concat(sortedKeys(t), ", "))
        else
            add(ns, ": ", type(t))
        end
    end
    local enum = resolve("Enum")
    if type(enum) == "table" then
        for _, k in ipairs(sortedKeys(enum)) do
            if k:find("AddonMessage") or k:find("Restrict") or k:find("Lockdown") or k:find("Secret")
                or k:find("ChatMessaging") then
                add("Enum.", k, " = ", str(enum[k]))
            end
        end
    else
        add("Enum = ", type(enum))
    end

    section("Identitaet")
    local ok, r = packed(call("UnitName", "player"))
    add("UnitName(player) = ", ok and (N(r[1]) .. ", realm=" .. str(r[2])) or "FEHLT/FEHLER")
    ok, r = packed(call("UnitFullName", "player"))
    add("UnitFullName(player) = ", ok and (N(r[1]) .. ", realm=" .. str(r[2])) or "FEHLT/FEHLER")
    local guid = v1("UnitGUID", "player")
    add("UnitGUID(player) = ", G(guid))
    ok, r = packed(call("GetPlayerInfoByGUID", guid))
    if ok then
        add("GetPlayerInfoByGUID = class=", str(r[2]), " race=", str(r[4]), " name=", N(r[6]), " realm=", str(r[7]))
    else
        add("GetPlayerInfoByGUID = FEHLT/FEHLER")
    end
    add("GetNormalizedRealmName = ", fmtCall("GetNormalizedRealmName"), " | GetRealmName = ", fmtCall("GetRealmName"))
    add("IsTrialAccount = ", fmtCall("IsTrialAccount"), " | IsVeteranTrialAccount = ", fmtCall("IsVeteranTrialAccount"))
    add("IsInGuild = ", fmtCall("IsInGuild"), " | IsGuildLeader = ", fmtCall("IsGuildLeader"))
    ok, r = packed(call("GetGuildInfo", "player"))
    if ok then
        add("GetGuildInfo(player) = gilde=", str(r[1]), " rang=", str(r[2]), " rangIndex=", str(r[3]),
            " realm=", str(r[4]), " (", r.n, " Werte)")
    else
        add("GetGuildInfo(player) = FEHLT/FEHLER")
    end
    add("C_Club.GetGuildClubId = ", fmtCall("C_Club.GetGuildClubId"))

    section("Gilden-Roster")
    add("GetNumGuildMembers = ", fmtCall("GetNumGuildMembers"), " | GUILD_ROSTER_UPDATE bisher: ", session.rosterUpdates)
    local n = numMembers()
    if n == 0 then
        add("Roster leer oder noch nicht geladen. Ein paar Sekunden warten und /sfprobe erneut ausfuehren.")
    end
    for i = 1, math.min(n, ROSTER_ROWS) do
        ok, r = packed(call("GetGuildRosterInfo", i))
        if ok then
            local name = r[1]
            local info = ""
            if type(name) == "string" and not isSecret(name) then
                info = string.format(" (bytes=%d, bindestrich=%s, leerzeichen=%s)", #name,
                    name:find("-", 1, true) and "ja" or "nein", name:find(" ", 1, true) and "ja" or "nein")
            end
            add("#", i, " name=", N(name), info, " rankName=", str(r[2]), " rankIndex=", str(r[3]),
                " level=", str(r[4]), " online=", str(r[9]), " guid=", G(r[17]), " (", r.n, " Werte)")
        else
            add("#", i, " FEHLER: ", str(r[1]))
        end
    end
    -- Register every roster name so anonText() can replace it in free text.
    if anon then
        for i = 1, n do
            ok, r = packed(call("GetGuildRosterInfo", i))
            if ok and type(r[1]) == "string" and not isSecret(r[1]) then
                N(r[1])
                local short = v1("Ambiguate", r[1], "none")
                if type(short) == "string" then
                    N(short)
                end
            end
        end
    end
    local ranks = v1("GuildControlGetNumRanks")
    if type(ranks) == "number" and not isSecret(ranks) then
        local names = {}
        for i = 1, math.min(ranks, 20) do
            names[#names + 1] = i .. "=" .. fmtCall("GuildControlGetRankName", i)
        end
        add("Raenge (GuildControlGetRankName): ", table.concat(names, ", "))
    else
        add("GuildControlGetNumRanks = ", fmtCall("GuildControlGetNumRanks"))
    end

    section("Slash-Befehle (welcher Alias hat gefeuert)")
    if #DB.slash == 0 then
        add("(noch keine)")
    end
    for _, s in ipairs(DB.slash) do
        add(s)
    end

    section("Text / Umlaute")
    add("Schrifttest: ", FONT_TEST)
    add("strlower('ÄÖÜ') = ", fmtCall("strlower", "ÄÖÜ"), " | strupper('äöü') = ", fmtCall("strupper", "äöü"))
    add("Bytes von 'ä' = ", #"ä")

    section("Globale Strings (roh) und abgeleitetes Muster")
    for _, g in ipairs(SYSTEM_GLOBALS) do
        local v = resolve(g)
        local p = fmtToPattern(v)
        add(g, " = ", str(v), p and ("   => Muster: " .. p) or "")
    end

    section("CHAT_MSG_SYSTEM (max " .. MAX_SYSTEM .. ", " .. SYSTEM_CAPTURE_SECONDS / 60 .. " min nach Login)")
    if session.systemUntil then
        local left = session.systemUntil - session.clock
        add(left > 0 and string.format("Aufzeichnung laeuft noch %.0f s", left) or "Aufzeichnung beendet",
            ", verworfen (voll): ", session.systemDropped)
    end
    for _, e in ipairs(DB.system) do
        add(e.at, " ", e.tag and ("[" .. e.tag .. "] ") or "", anonText(e.text))
    end

    section("Addon-Nachrichten")
    add("Prefix '", PREFIX, "' registrieren: ", session.prefixResult)
    add("IsAddonMessagePrefixRegistered = ", fmtCall("C_ChatInfo.IsAddonMessagePrefixRegistered", PREFIX))
    add("-- Gesendet (", #DB.sends, ")")
    for _, s in ipairs(DB.sends) do
        add(s)
    end
    add("-- Empfangen (nur Prefix ", PREFIX, ", Echo nur erste Nachricht je Lauf; ", #DB.addonIn, ")")
    for _, e in ipairs(DB.addonIn) do
        local a = e.amb or {}
        add(e.at, " ", e.channel, " '", e.text, "' sender=", N(e.sender), " (", str(e.senderType), ")",
            " eigene=", str(e.own))
        add("   Ambiguate none=", N(a.none), " short=", N(a.short), " guild=", N(a.guild), " mail=", N(a.mail),
            " all=", N(a.all))
        add("   Roster: ", anonText(str(e.match)), " guid=", G(e.guid), " | ", str(e.state))
    end

    section("Echo")
    for _, tx in ipairs(DB.echoTx) do
        local codes = {}
        for code, count in pairs(tx.codes or {}) do
            codes[#codes + 1] = code .. " x" .. count
        end
        add("Gesendet Lauf ", str(tx.run), ": start ", str(tx.started), ", ende ", str(tx.ended), ", gesendet ",
            str(tx.sent), "/", ECHO_COUNT, ", Codes: ", table.concat(codes, ", "))
        for _, f in ipairs(tx.failures or {}) do
            add("   ", f)
        end
    end
    for _, rx in ipairs(DB.echoRx) do
        add("Empfangen von ", N(rx.sender), " Lauf ", str(rx.run), ": ", str(rx.count), " von ", str(rx.total),
            ", erste #", str(rx.first), " letzte #", str(rx.last), ", max Pause ",
            string.format("%.1f", tonumber(rx.maxPause) or 0), " s, ", str(rx.firstAt), " bis ", str(rx.lastAt))
        for _, g in ipairs(rx.gaps or {}) do
            add("   ", g)
        end
    end
    if #DB.echoTx == 0 and #DB.echoRx == 0 then
        add("(noch kein Echo)")
    end

    section("Lockdown-Zeitleiste (Ereignisse + alle 5 s bei Aenderung)")
    add("Jetzt: ", stateString())
    add("ADDON_RESTRICTION_STATE_CHANGED registrieren: ", str(session.registrations.ADDON_RESTRICTION_STATE_CHANGED))
    add("C_EventUtils.IsEventValid(ADDON_RESTRICTION_STATE_CHANGED) = ",
        fmtCall("C_EventUtils.IsEventValid", "ADDON_RESTRICTION_STATE_CHANGED"))
    for ev, res in pairs(session.registrations) do
        if res ~= "ok" and ev ~= "ADDON_RESTRICTION_STATE_CHANGED" then
            add("Event ", ev, " nicht registrierbar: ", res)
        end
    end
    for _, t in ipairs(DB.timeline) do
        add(t)
    end

    section("Blockierte Aktionen")
    for _, e in ipairs(DB.events) do
        add(e)
    end

    section("Spaetere Features")
    add("GetNumGuildTradeSkill() = ", fmtCall("GetNumGuildTradeSkill"))
    add("C_Calendar.CanAddEvent() = ", fmtCall("C_Calendar.CanAddEvent"))
    add("GetProfessions() = ", fmtCall("GetProfessions"))

    section("Abgefangene Fehler im Probe")
    if #DB.errors == 0 then
        add("(keine)")
    end
    for _, e in ipairs(DB.errors) do
        add(e)
    end

    local text = table.concat(L, "\n")
    anon = nil
    return text
end

---------------------------------------------------------------------------
-- Report window
---------------------------------------------------------------------------

local function newButton(parent, label, onClick)
    local CF = resolve("CreateFrame")
    local ok, b = pcall(CF, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then
        b = CF("Button", nil, parent)
        local font = resolve("GameFontNormal")
        if font then
            b:SetNormalFontObject(font)
        end
    end
    b:SetSize(150, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function buildWindow()
    local CF = resolve("CreateFrame")
    local parent = resolve("UIParent")
    local name = "SpaetiProbeReportFrame"
    local ok, f = pcall(CF, "Frame", name, parent, resolve("BackdropTemplateMixin") and "BackdropTemplate" or nil)
    if not ok or not f then
        f = CF("Frame", name, parent)
    end
    f:SetSize(760, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local hasBackdrop = false
    if type(f.SetBackdrop) == "function" then
        hasBackdrop = pcall(f.SetBackdrop, f, {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    if not hasBackdrop then
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("SpaetiProbe-Bericht: ins Textfeld klicken, Strg+A, Strg+C")
    local font = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    font:SetPoint("TOPLEFT", 18, -36)
    font:SetText("Schrifttest: " .. FONT_TEST)

    local sok, scroll = pcall(CF, "ScrollFrame", "SpaetiProbeReportScroll", f, "UIPanelScrollFrameTemplate")
    if not sok or not scroll then
        scroll = CF("ScrollFrame", "SpaetiProbeReportScroll", f)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            local cur = (self:GetVerticalScroll() or 0) - delta * 40
            self:SetVerticalScroll(math.max(0, math.min(range, cur)))
        end)
    end
    scroll:SetPoint("TOPLEFT", 18, -58)
    scroll:SetPoint("BOTTOMRIGHT", -36, 46)

    local eb = CF("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(0)
    eb:SetFontObject(resolve("ChatFontNormal") or resolve("GameFontHighlightSmall"))
    eb:SetWidth(700)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput and report and report.text then
            self:SetText(report.text)
        end
    end)
    scroll:SetScrollChild(eb)

    local close = newButton(f, "Schliessen", function()
        f:Hide()
    end)
    close:SetPoint("BOTTOMRIGHT", -18, 16)
    local refresh = newButton(f, "Aktualisieren", function()
        if report then
            report.show(report.anon)
        end
    end)
    refresh:SetPoint("BOTTOM", 0, 16)

    local usf = resolve("UISpecialFrames")
    if type(usf) == "table" then
        table.insert(usf, name)
    end
    return { frame = f, edit = eb, scroll = scroll }
end

local function showReport(anonymise)
    local text = buildReport(anonymise)
    DB.lastReport = text
    DB.lastReportAnon = anonymise and true or false
    if type(resolve("CreateFrame")) ~= "function" then
        out("Kein Fenster moeglich. Bericht liegt in SavedVariables (SpaetiProbeDB.lastReport).")
        return
    end
    if not report then
        local ok, w = pcall(buildWindow)
        if not ok then
            logError("Fenster", w)
            out("Fenster-Fehler: " .. str(w) .. ". Bericht liegt in SavedVariables (SpaetiProbeDB.lastReport).")
            return
        end
        report = w
        report.show = showReport
    end
    report.anon = anonymise
    report.text = text:gsub("|", "||")
    local ok, err = pcall(function()
        report.frame:Show()
        report.edit:SetText(report.text)
        report.edit:SetFocus()
        report.edit:HighlightText()
    end)
    if not ok then
        logError("Fenster anzeigen", err)
        out("Fenster-Fehler: " .. str(err))
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local HELP = {
    "/sfprobe - Bericht anzeigen (kopierbar)",
    "/sfprobe anon - Bericht mit anonymisierten Namen/GUIDs",
    "/sfprobe ping - eine Addon-Nachricht an GILDE",
    "/sfprobe echo - 2 Minuten lang alle 2 s eine Nachricht (echo stop = abbrechen)",
    "/sfprobe burst - 12 Nachrichten auf einmal (nur EINMAL ausfuehren!)",
    "/sfprobe font - Schrifttest im Chat",
    "/sfprobe system - CHAT_MSG_SYSTEM-Aufzeichnung neu starten (10 min)",
    "/sfprobe reset - alle gespeicherten Probe-Daten loeschen",
}

local function handleSlash(alias, msg)
    ensureDB()
    local raw = str(msg)
    push("slash", stamp() .. " alias=" .. alias .. " msg='" .. raw .. "'", MAX_SLASH, true)
    local cmd, rest = raw:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    if cmd == "" then
        showReport(false)
    elseif cmd == "anon" then
        showReport(true)
    elseif cmd == "ping" then
        cmdPing()
    elseif cmd == "burst" then
        cmdBurst()
    elseif cmd == "echo" then
        cmdEcho(string.lower(rest or ""))
    elseif cmd == "font" then
        out("Schrifttest: " .. FONT_TEST)
    elseif cmd == "system" then
        session.systemUntil = session.clock + SYSTEM_CAPTURE_SECONDS
        session.systemDropped = 0
        DB.system = {}
        out("CHAT_MSG_SYSTEM wird 10 Minuten aufgezeichnet.")
    elseif cmd == "reset" then
        for _, k in ipairs({ "slash", "system", "addonIn", "sends", "timeline", "echoRx", "echoTx",
            "guildChat", "events", "errors" }) do
            DB[k] = {}
        end
        DB.lastReport = nil
        out("Probe-Daten geloescht.")
    else
        for _, line in ipairs(HELP) do
            out(line)
        end
    end
end

local function registerSlash()
    local list = resolve("SlashCmdList")
    if type(list) ~= "table" then
        return
    end
    -- Separate keys per alias, so the report shows which spelling the client matched.
    _G.SLASH_SPAETIPROBE1 = "/sfprobe"
    _G.SLASH_SPAETIPROBE_ASCII1 = "/spaetiprobe"
    _G.SLASH_SPAETIPROBE_UML1 = "/spätiprobe"
    _G.SLASH_SPAETIPROBE_UMLUP1 = "/SPÄTIPROBE"
    local function wrap(alias)
        return function(msg)
            local ok, err = pcall(handleSlash, alias, msg)
            if not ok then
                logError("slash " .. alias, err)
                out("Interner Fehler (im Bericht protokolliert): " .. str(err))
            end
        end
    end
    list.SPAETIPROBE = wrap("/sfprobe")
    list.SPAETIPROBE_ASCII = wrap("/spaetiprobe")
    list.SPAETIPROBE_UML = wrap("/spätiprobe")
    list.SPAETIPROBE_UMLUP = wrap("/SPÄTIPROBE")
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

local EVENTS = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "CHAT_MSG_SYSTEM", "CHAT_MSG_ADDON", "GUILD_ROSTER_UPDATE",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "ADDON_RESTRICTION_STATE_CHANGED",
}

local function bootstrap()
    local CF = resolve("CreateFrame")
    if type(CF) ~= "function" then
        return
    end
    local ok, f = pcall(CF, "Frame")
    if not ok or not f then
        return
    end
    driver = f
    for _, ev in ipairs(EVENTS) do
        local rok, err = pcall(f.RegisterEvent, f, ev)
        session.registrations[ev] = rok and "ok" or ("FEHLER: " .. str(err))
    end
    pcall(f.SetScript, f, "OnEvent", function(_, event, ...)
        local h = handlers[event]
        if h and (DB or event == "ADDON_LOADED") then
            local hok, err = pcall(h, ...)
            if not hok then
                logError(event, err)
            end
        end
    end)
    pcall(f.SetScript, f, "OnUpdate", onUpdate)
end

pcall(registerSlash)
pcall(bootstrap)
