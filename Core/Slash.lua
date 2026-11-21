-- Core/Slash.lua: /spaeti (/späti) and /spruch.
local _, ns = ...

local L = ns.L
local Util = ns.Util

local function yesNo(v)
    if v == nil then
        return L.UNKNOWN
    end
    return v and L.YES or L.NO
end

local function printHelp()
    ns.Print(L.HELP_HEADER)
    for _, line in ipairs(L.HELP_LINES) do
        ns.Print("  " .. line)
    end
end

local function printStatus()
    local version, build, _, interface = GetBuildInfo()
    local roster = ns.Roster
    ns.Print(L.STATUS_HEADER)
    ns.Print(L.STATUS_VERSION:format(ns.VERSION, ns.SCHEMA_VERSION))
    ns.Print(L.STATUS_INTERFACE:format(tostring(interface), tostring(version), tostring(build)))
    local guild = roster:GuildName()
    ns.Print(L.STATUS_GUILD:format(guild or L.STATUS_NO_GUILD))
    if guild then
        local rankName, rankIndex = roster:PlayerRank()
        ns.Print(L.STATUS_RANK:format(("%s (%s)"):format(rankName or L.UNKNOWN, tostring(rankIndex))))
        ns.Print(L.STATUS_MEMBERS:format(roster.numOnline, roster.numTotal))
    end
    ns.Print(L.STATUS_OFFICER:format(yesNo(roster:IsOfficer())))
    ns.Print(L.STATUS_LOCKDOWN:format(yesNo(ns.Chat.IsLockedDown())))
    ns.Print(L.STATUS_SECRETS:format(Util.HAS_SECRET_API and L.YES or L.NOT_AVAILABLE))
    ns.Print(L.STATUS_SETTINGS:format(ns.HasSettingsPanel() and L.YES or L.NOT_AVAILABLE))
    if ns.DB.readOnly then
        ns.Print(L.STATUS_READONLY)
    end
    local store = ns.Points.store
    local stats = ns.Comm.stats
    ns.Print(L.STATUS_SYNC:format(store and store.count or 0, ns.Comm.QueueSize(), stats.sent,
        stats.received, stats.throttled))
    local c1, c2, c3 = ns.Comm.GateInfo()
    ns.Print(L.STATUS_SYNC_DIAG:format(yesNo(ns.Comm.paused), tostring(c1), tostring(c2), tostring(c3),
        tostring(ns.Comm.lastResult), stats.dropped, stats.lockdown, stats.errors,
        tostring(ns.Comm.prefixResult)))
    if ns.Comm.lastError then
        ns.Print(L.STATUS_SYNC_ERROR:format(ns.Comm.lastError))
    end
    local missing = ns.MissingLocaleKeys()
    if #missing > 0 then
        ns.Print(L.STATUS_MISSING_KEYS:format(table.concat(missing, ", ")))
    end
end

local function spruch()
    ns.Sprueche.ShowLocal()
end

local commands = {
    spruch = spruch,
    status = printStatus,
    hilfe = printHelp,
    help = printHelp,
    ["?"] = printHelp,
    danke = function(rest) ns.Points:Thank(rest) end,
    punkte = function() ns.UI.Toggle(ns.UI.TAB_POINTS) end,
    optionen = function() ns.OpenSettings() end,
    einstellungen = function() ns.OpenSettings() end,
}

local function handler(msg)
    msg = Util.SafeText(msg) or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = Util.Lower(cmd or "")
    if cmd == "" then
        ns.UI.Toggle()
        return
    end
    local fn = commands[cmd]
    if fn then
        fn(rest)
    else
        ns.Print(L.UNKNOWN_COMMAND:format((cmd:gsub("|", "||"))))
    end
end

SLASH_SPAETI1 = "/spaeti"
SLASH_SPAETI2 = "/späti" -- VERIFY IN-GAME: umlaut slash commands (probe S1)
SlashCmdList.SPAETI = handler

SLASH_SPAETISPRUCH1 = "/spruch"
SlashCmdList.SPAETISPRUCH = spruch
