-- tests/helpers/wow.lua: tiny WoW API mock for plain lua5.1 tests.
-- A "world" holds a fake clock, a guild roster and a shared GUILD addon channel.
-- Each client gets its own global environment and loads the real addon files
-- listed in SpaetiFreunde.toc (UI included; frames are no-op objects).
local M = {}

M.ROOT = (arg and arg[0] or ""):match("^(.-)tests/[^/]*$") or "./"
M.START = 1795255200 -- 2026-11-21 10:00 UTC (11:00 Berlin)
M.failures = 0
M.checks = 0

function M.check(cond, msg)
    M.checks = M.checks + 1
    if not cond then
        M.failures = M.failures + 1
        print("FAIL: " .. msg)
    end
    return cond
end

function M.eq(a, b, msg)
    return M.check(a == b, ("%s (expected %s, got %s)"):format(msg, tostring(b), tostring(a)))
end

local function tocFiles()
    local files = {}
    for line in io.lines(M.ROOT .. "SpaetiFreunde.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") and not line:match("^#") then
            files[#files + 1] = M.ROOT .. line:gsub("\\", "/")
        end
    end
    return files
end
M.TocFiles = tocFiles

---------------------------------------------------------------------------
-- Frames: every unknown method is a no-op.
---------------------------------------------------------------------------
local function newObj(client, name)
    local o = { scripts = {}, events = {}, shown = true, text = "", name = name }
    local methods = {
        SetScript = function(self, s, f) self.scripts[s] = f end,
        GetScript = function(self, s) return self.scripts[s] end,
        RegisterEvent = function(self, e) self.events[e] = true end,
        UnregisterEvent = function(self, e) self.events[e] = nil end,
        CreateFontString = function() return newObj(client) end,
        CreateTexture = function() return newObj(client) end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, v) self.shown = v and true or false end,
        IsShown = function(self) return self.shown end,
        IsVisible = function(self) return self.shown end,
        SetText = function(self, t) self.text = t end,
        GetText = function(self) return self.text end,
        GetName = function(self) return self.name end,
        GetParent = function(self) return self.parent end,
        GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
        GetChecked = function(self) return self.checked end,
        SetChecked = function(self, v) self.checked = v end,
    }
    return setmetatable(o, { __index = function(_, k)
        return methods[k] or function() end
    end })
end

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
local World = {}
World.__index = World

function M.NewWorld(seed)
    math.randomseed(seed or 1)
    return setmetatable({
        t = 0, -- GetTime()
        members = {}, -- array of { name, guid, rankName, rankIndex, client }
        timers = {},
        clients = {},
        log = {}, -- every addon message sent { from, msg }
        tooLong = 0,
        throttled = 0,
        errors = {},
        latency = 0.1,
    }, World)
end

function World:ServerTime()
    return M.START + math.floor(self.t)
end

function World:AddMember(name, guid, rankName, rankIndex)
    local m = { name = name, guid = guid, rankName = rankName or "Member", rankIndex = rankIndex or 4 }
    self.members[#self.members + 1] = m
    return m
end

function World:Member(name)
    for _, m in ipairs(self.members) do
        if m.name == name then
            return m
        end
    end
end

function World:After(client, delay, fn)
    self.timers[#self.timers + 1] = { at = self.t + math.max(0, delay or 0), fn = fn, client = client,
        seq = #self.timers }
end

-- Advance the clock; runs due timers in order.
function World:Advance(seconds, step)
    step = step or 0.1
    local target = self.t + seconds
    while self.t < target - 1e-9 do
        self.t = math.min(target, self.t + step)
        while true do
            local due, dueIndex
            for i, tm in ipairs(self.timers) do
                if tm.at <= self.t + 1e-9 and (not due or tm.at < due.at or (tm.at == due.at and tm.seq < due.seq)) then
                    due, dueIndex = tm, i
                end
            end
            if not due then
                break
            end
            table.remove(self.timers, dueIndex)
            if not due.client or due.client.alive then
                local ok, err = pcall(due.fn)
                if not ok then
                    self.errors[#self.errors + 1] = tostring(err)
                end
            end
        end
    end
end

function World:Broadcast(sender, prefix, msg)
    if #msg > 255 then
        self.tooLong = self.tooLong + 1
    end
    self.log[#self.log + 1] = { from = sender.name, msg = msg, t = self.t }
    self:After(nil, self.latency, function()
        for _, c in ipairs(self.clients) do
            if c.alive and not c.deaf then
                c:Fire("CHAT_MSG_ADDON", prefix, msg, "GUILD", sender.name)
            end
        end
    end)
end

-- Count logged messages of a type ("N", "H", "D", "R", "E") since index `from`.
function World:Count(msgType, from)
    local n = 0
    for i = from or 1, #self.log do
        if self.log[i].msg:match("^%d+~(%u)") == msgType then
            n = n + 1
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------
local Client = {}
Client.__index = Client

function Client:Fire(event, ...)
    for _, f in ipairs(self.frames) do
        if f.events[event] and f.scripts.OnEvent then
            local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
            if not ok then
                self.world.errors[#self.world.errors + 1] = tostring(err)
            end
        end
    end
end

function Client:Slash(msg)
    local ok, err = pcall(self.env.SlashCmdList.SPAETI, msg)
    if not ok then
        self.world.errors[#self.world.errors + 1] = tostring(err)
    end
end

function Client:ChatText()
    return table.concat(self.chat, "\n")
end

function Client:ClearChat()
    self.chat = {}
end

function Client:Logout()
    self.alive = false
    self.member.client = nil
    self:Fire("PLAYER_LOGOUT")
end

local function buildEnv(world, client, member)
    local env = {
        string = string, table = table, math = math, pairs = pairs, ipairs = ipairs, type = type,
        tostring = tostring, tonumber = tonumber, select = select, pcall = pcall, error = error,
        setmetatable = setmetatable, getmetatable = getmetatable, next = next, unpack = unpack,
        rawget = rawget, rawset = rawset, assert = assert, print = function() end,
    }
    env._G = env
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strlower, env.strupper, env.format = string.lower, string.upper, string.format
    env.tinsert, env.tremove = table.insert, table.remove
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.date, env.time = os.date, os.time
    env.GetTime = function() return world.t end
    env.GetServerTime = function() return world:ServerTime() end
    env.geterrorhandler = function()
        return function(err) world.errors[#world.errors + 1] = tostring(err) end
    end
    env.issecretvalue = function() return false end
    env.Ambiguate = function(name) return name end

    client.chat = {}
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) client.chat[#client.chat + 1] = text end }
    env.CreateFrame = function(_, name)
        local f = newObj(client, name)
        client.frames[#client.frames + 1] = f
        return f
    end
    env.UIParent, env.Minimap, env.GameTooltip = newObj(client), newObj(client), newObj(client)
    env.UISpecialFrames = {}
    env.SlashCmdList = {}
    env.SOUNDKIT = { TELL_MESSAGE = 3081, READY_CHECK = 8960 }
    env.PlaySound = function(id) client.sounds[#client.sounds + 1] = id end
    env.GetBuildInfo = function() return "1.60.1", "71037", "Nov 18 2026", 16001 end
    env.GetLocale = function() return client.locale or "deDE" end
    env.C_AddOns = { GetAddOnMetadata = function() return "test" end }
    env.InCombatLockdown = function() return false end
    env.IsInInstance = function() return false, "none" end
    env.IsLoggedIn = function() return true end

    env.C_Timer = {
        After = function(d, fn) world:After(client, d, fn) end,
        NewTicker = function(d, fn)
            local ticker = { cancelled = false }
            local function loop()
                if not ticker.cancelled then
                    fn(ticker)
                    world:After(client, d, loop)
                end
            end
            world:After(client, d, loop)
            ticker.Cancel = function(self) self.cancelled = true end
            return ticker
        end,
    }

    -- Identity + guild
    local first, last = member.name:match("^(%S+)%s+(.+)$")
    env.UnitName = function() return first or member.name, last end
    env.UnitFullName = env.UnitName
    env.UnitGUID = function(unit) return unit == "player" and member.guid or nil end
    env.IsInGuild = function() return true end
    env.GetGuildInfo = function() return "Spätifreunde Spandau", member.rankName, member.rankIndex end
    env.IsGuildLeader = function() return member.rankIndex == 0 end
    env.GetNumGuildMembers = function() return #world.members end
    env.GetGuildRosterInfo = function(i)
        local m = world.members[i]
        if not m then
            return nil
        end
        local online = m.client ~= nil and m.client.alive
        return m.name, m.rankName, m.rankIndex, 60, "Krieger", "Spandau", "", "", online, 0,
            "WARRIOR", 0, 0, false, false, 0, m.guid
    end
    env.C_GuildInfo = {
        GuildRoster = function() world:After(client, 0.1, function() client:Fire("GUILD_ROSTER_UPDATE") end) end,
    }
    env.C_Club = { GetGuildClubId = function() return 215755322 end }

    -- Addon messages with the confirmed Forever throttle: burst 10, then +1/s.
    client.bucket, client.bucketAt = 10, world.t
    env.Enum = { AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3,
        Map = 4, Chat = 5 }, SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 } }
    env.C_RestrictedActions = {
        IsAddOnRestrictionActive = function(kind) return kind == 5 and client.restricted or false end,
    }
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return 0 end,
        InChatMessagingLockdown = function() return client.restricted or false end,
        AreOutgoingAddonChatMessagesRestricted = function() return client.restricted or false end,
        SendAddonMessage = function(prefix, msg, channel)
            if client.restricted then
                return 11
            end
            client.bucket = math.min(10, client.bucket + (world.t - client.bucketAt))
            client.bucketAt = world.t
            if client.bucket < 1 then
                world.throttled = world.throttled + 1
                client.throttled = client.throttled + 1
                return 3
            end
            client.bucket = client.bucket - 1
            client.sentCount = client.sentCount + 1
            assert(channel == "GUILD", "unexpected channel " .. tostring(channel))
            world:Broadcast(member, prefix, msg)
            return 0
        end,
    }
    env.SendChatMessage = function() client.postedToChat = true end
    return env
end

-- Create (or re-create after logout) the client of a member and log in.
-- savedVars: SpaetiFreundeDB table to restore (simulates SavedVariables).
function World:Login(name, savedVars, opts)
    local member = assert(self:Member(name), "unknown member " .. name)
    local client = setmetatable({ world = self, member = member, name = name, frames = {}, sounds = {},
        alive = true, throttled = 0, sentCount = 0 }, Client)
    if opts and opts.restricted then
        client.restricted = true
    end
    local env = buildEnv(self, client, member)
    client.env = env
    env.SpaetiFreundeDB = savedVars
    local ns = {}
    client.ns = ns
    for _, file in ipairs(tocFiles()) do
        local chunk = assert(loadfile(file))
        setfenv(chunk, env)
        chunk("SpaetiFreunde", ns)
    end
    member.client = client
    self.clients[#self.clients + 1] = client
    client:Fire("ADDON_LOADED", "SpaetiFreunde")
    client:Fire("PLAYER_LOGIN")
    client:Fire("PLAYER_ENTERING_WORLD", true, false)
    -- Everybody else's roster refreshes on their own ticker; nudge them now.
    for _, c in ipairs(self.clients) do
        if c.alive and c ~= client then
            c:Fire("GUILD_ROSTER_UPDATE")
        end
    end
    return client
end

-- Saved variables of a client (to pass into a later Login).
function Client:Saved()
    return self.env.SpaetiFreundeDB
end

function M.Summary(name)
    print(("%s: %d checks, %d failures"):format(name, M.checks, M.failures))
    return M.failures
end

return M
