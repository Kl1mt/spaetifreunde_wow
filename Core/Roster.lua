-- Core/Roster.lua: guild roster cache keyed by GUID, online/offline diff, officer check.
local _, ns = ...

local Util = ns.Util
local Roster = {}
ns.Roster = Roster

local OFFICER_RANK_NAME = "Officer" -- guild decision: GM + rank named "Officer"
local REQUEST_THROTTLE = 20 -- seconds between roster requests
local REFRESH_INTERVAL = 60 -- periodic refresh while in a guild

Roster.members = {} -- guid -> entry
Roster.numTotal = 0
Roster.numOnline = 0
Roster.ready = false -- true after the first (baseline) scan
Roster.lastOnline = nil -- guid of the most recent member who came online

local lastRequest = -math.huge
local pendingRequest = false

local function now()
    return GetTime and GetTime() or 0
end

-- Ask the server for fresh roster data (throttled; re-queued if too early).
function Roster:Request()
    if not (IsInGuild and IsInGuild()) then
        return
    end
    local wait = lastRequest + REQUEST_THROTTLE - now()
    if wait > 0 then
        if not pendingRequest and C_Timer then
            pendingRequest = true
            C_Timer.After(wait, function()
                pendingRequest = false
                Roster:Request()
            end)
        end
        return
    end
    lastRequest = now()
    -- VERIFY IN-GAME: C_GuildInfo.GuildRoster on Forever (global GuildRoster as fallback).
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        C_GuildInfo.GuildRoster()
    elseif type(GuildRoster) == "function" then
        GuildRoster()
    end
end

-- Scan GetGuildRosterInfo into a fresh table; returns members, total, online.
local function scan()
    local members, online = {}, 0
    local total = GetNumGuildMembers and GetNumGuildMembers() or 0
    total = tonumber(Util.SafeText(total)) or 0
    for i = 1, total do
        -- name, rankName, rankIndex, level, classDisplayName, zone, publicNote,
        -- officerNote, isOnline, status, class, achPoints, achRank, isMobile, canSoR, rep, guid
        local name, rankName, rankIndex, level, classDisplayName, zone, _, _, isOnline,
            _, class, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
        guid = Util.SafeText(guid)
        name = Util.SafeText(name)
        if guid and name then
            local entry = {
                guid = guid,
                name = name,
                display = Util.DisplayName(name),
                rankName = Util.SafeText(rankName),
                rankIndex = tonumber(Util.SafeText(rankIndex)),
                level = tonumber(Util.SafeText(level)),
                className = Util.SafeText(classDisplayName),
                class = Util.SafeText(class),
                zone = Util.SafeText(zone),
                -- Mobile (app) users count as offline for greetings.
                online = (isOnline == true) and (isMobile ~= true),
                index = i,
            }
            members[guid] = entry
            if entry.online then
                online = online + 1
            end
        end
    end
    -- Officer notes are deliberately never stored.
    return members, total, online
end

function Roster:OnRosterUpdate()
    if not (IsInGuild and IsInGuild()) then
        self.members, self.numTotal, self.numOnline = {}, 0, 0
        return
    end
    local members, total, online = scan()
    if total > 0 and next(members) == nil then
        return -- data not loaded yet; keep old cache
    end
    local old = self.members
    local wasReady = self.ready
    self.members, self.numTotal, self.numOnline = members, total, online
    self.ready = true

    local myGuid = UnitGUID and Util.SafeText(UnitGUID("player"))
    if wasReady then
        local cameOnline = {}
        for guid, entry in pairs(members) do
            local before = old[guid]
            if guid ~= myGuid and entry.online and before and not before.online then
                cameOnline[#cameOnline + 1] = entry
            end
        end
        for guid, before in pairs(old) do
            local entry = members[guid]
            if before.online and entry and not entry.online then
                ns:Fire("SF_MEMBER_OFFLINE", guid, entry)
            end
        end
        if #cameOnline > 0 then
            self.lastOnline = cameOnline[#cameOnline].guid
            ns:Fire("SF_MEMBERS_ONLINE", cameOnline)
        end
    end
    -- The first scan is only a baseline and fires no online events.
    ns:Fire("SF_ROSTER_UPDATED", not wasReady)
end

function Roster:Get(guid)
    return self.members[guid]
end

-- Own guild name (nil if not in a guild).
function Roster:GuildName()
    if not (IsInGuild and IsInGuild()) or not GetGuildInfo then
        return nil
    end
    local name = GetGuildInfo("player")
    return Util.SafeText(name)
end

-- Own rank name and index.
function Roster:PlayerRank()
    if not (IsInGuild and IsInGuild()) or not GetGuildInfo then
        return nil, nil
    end
    local _, rankName, rankIndex = GetGuildInfo("player")
    return Util.SafeText(rankName), tonumber(Util.SafeText(rankIndex))
end

-- Is the given member (or the player when guid is nil) an officer?
-- Officer = guild master (rank index 0) OR rank named "Officer".
function Roster:IsOfficer(guid)
    local rankName, rankIndex
    if guid == nil then
        if not (IsInGuild and IsInGuild()) then
            return false
        end
        if IsGuildLeader and IsGuildLeader() then
            return true
        end
        rankName, rankIndex = self:PlayerRank()
    else
        local entry = self.members[guid]
        if not entry then
            return false
        end
        rankName, rankIndex = entry.rankName, entry.rankIndex
    end
    if rankIndex == 0 then
        return true
    end
    return rankName ~= nil and Util.Lower(rankName) == Util.Lower(OFFICER_RANK_NAME)
end

ns:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    Roster:OnRosterUpdate()
end)

ns:RegisterEvent("PLAYER_GUILD_UPDATE", function()
    Roster:Request()
end)

-- System messages often announce logins; we only use them as a hint to refresh,
-- never parse the (possibly secret) text.
ns:RegisterEvent("CHAT_MSG_SYSTEM", function()
    Roster:Request()
end)

ns:On("SF_LOGIN", function()
    Roster:Request()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(REFRESH_INTERVAL, function()
            Roster:Request()
        end)
    end
end)
