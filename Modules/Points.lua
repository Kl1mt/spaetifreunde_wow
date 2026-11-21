-- Modules/Points.lua: Spätipunkte – thanking, officer voids, derived totals, local notices.
-- Everything visible appears only in your own chat frame / window. Other members
-- learn about thanks only through hidden addon messages (Modules/Sync.lua).
local _, ns = ...

local L = ns.L
local Util = ns.Util
local Codec = ns.Codec
local PD = ns.PointsData

local Points = {}
ns.Points = Points

local RECOMPUTE_DELAY = 0.5
local NOTICE_SINGLE_MAX = 2 -- more new thanks at once are summarised
local MAX_CANDIDATES = 8

Points.store = nil -- PD store, bound once the guild key is known
Points.derived = nil
Points.guild = nil -- saved per-guild table

local pendingNotices = {} -- ids of newly received thanks for me
local recomputeScheduled = false

local function serverNow()
    return GetServerTime and GetServerTime() or 0
end

local function esc(s)
    return (tostring(s or "?"):gsub("|", "||"))
end

function Points.NameOf(guid)
    local entry = ns.Roster:Get(guid)
    if entry then
        return entry.display
    end
    local names = Points.guild and Points.guild.names
    return names and names[guid] or L.POINTS_UNKNOWN_MEMBER
end

function Points.RankName(idx)
    return L.RANKS[idx] or "?"
end

---------------------------------------------------------------------------
-- Binding to the guild's saved data
---------------------------------------------------------------------------
function Points:Bind()
    if self.store then
        return true
    end
    local key = ns.Roster:GuildKey()
    if not key or not ns.DB.data then
        return false
    end
    local guilds = ns.DB.data.guilds
    local g = guilds[key]
    if type(g) ~= "table" then
        g = {}
        guilds[key] = g
    end
    g.entries = type(g.entries) == "table" and g.entries or {}
    g.names = type(g.names) == "table" and g.names or {}
    g.lastRank = type(g.lastRank) == "table" and g.lastRank or {}
    self.guild = g
    self.store = PD.NewStore(g.entries)
    self:Recompute(true)
    ns:Fire("SF_POINTS_BOUND")
    return true
end

-- Remember display names, so people who left the guild still have a name.
local function rememberNames()
    local g = Points.guild
    if not g then
        return
    end
    for guid, entry in pairs(ns.Roster.members) do
        g.names[guid] = entry.display
    end
end

---------------------------------------------------------------------------
-- Derivation + notices
---------------------------------------------------------------------------
local function playSound(kind)
    if not ns.DB:Get("thanksSound") or type(PlaySound) ~= "function" or not SOUNDKIT then
        return
    end
    -- VERIFY IN-GAME: SOUNDKIT ids on Forever; any missing id is simply skipped.
    local candidates = kind == "rank"
        and { "UI_EPICACHIEVEMENTUNLOCKED", "LEVELUPSOUND", "READY_CHECK" }
        or { "TELL_MESSAGE", "IG_QUEST_LIST_COMPLETE", "READY_CHECK" }
    for _, name in ipairs(candidates) do
        local id = SOUNDKIT[name]
        if id then
            pcall(PlaySound, id)
            return
        end
    end
end

local function showNotices(derived, myGuid)
    local list = {}
    for _, id in ipairs(pendingNotices) do
        local e = Points.store:Get(id)
        if e and derived.acceptedIds[id] and e.b == myGuid then
            list[#list + 1] = e
        end
    end
    pendingNotices = {}
    if #list == 0 or not ns.DB:Get("thanksNotice") then
        return
    end
    if #list > NOTICE_SINGLE_MAX then
        ns.Print(L.POINTS_NOTICE_MANY:format(#list))
    else
        for _, e in ipairs(list) do
            local fmt = Util.RandomPick(L.POINTS_NOTICE_LINES) or "%s"
            ns.Print(fmt:format(esc(Points.NameOf(e.a))))
        end
    end
    playSound("thanks")
end

local function checkRankUp(derived, myGuid, silent)
    local g = Points.guild
    local mine = derived.points[myGuid] or 0
    local idx = PD.RankFor(mine)
    local before = g.lastRank[myGuid]
    g.lastRank[myGuid] = idx
    if silent or not before or idx <= before then
        return
    end
    if ns.DB:Get("thanksNotice") then
        ns.Print(L.POINTS_RANK_UP:format(Points.RankName(idx)))
        playSound("rank")
    end
end

function Points:Recompute(silent)
    if not self.store then
        return
    end
    recomputeScheduled = false
    local derived = PD.Derive(self.store.entries, {
        isOfficer = function(guid) return ns.Roster:IsOfficer(guid) end,
        now = serverNow(),
    })
    self.derived = derived
    local myGuid = ns.Roster:MyGUID()
    if myGuid then
        showNotices(derived, myGuid)
        checkRankUp(derived, myGuid, silent)
    end
    ns:Fire("SF_POINTS_UPDATED")
end

local function scheduleRecompute()
    if recomputeScheduled then
        return
    end
    recomputeScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(RECOMPUTE_DELAY, function()
            if recomputeScheduled then
                Points:Recompute()
            end
        end)
    else
        Points:Recompute()
    end
end

-- Add an entry from any source ("local", "direct", "sync"). Returns true if new.
function Points:Ingest(id, e, source)
    if not self.store then
        return false
    end
    local added = self.store:Add(id, e, serverNow())
    if added then
        if source ~= "local" and e.k == "T" and e.b == ns.Roster:MyGUID() then
            pendingNotices[#pendingNotices + 1] = id
        end
        scheduleRecompute()
    end
    return added
end

---------------------------------------------------------------------------
-- Public state for UI / slash
---------------------------------------------------------------------------
-- points, rank index, next threshold (nil at top)
function Points:MyStanding()
    local guid = ns.Roster:MyGUID()
    local p = (self.derived and guid and self.derived.points[guid]) or 0
    local idx, nextNeed = PD.RankFor(p)
    return p, idx, nextNeed
end

-- Roster members sorted by points (desc), then name.
function Points:Leaderboard()
    local list = {}
    local pts = self.derived and self.derived.points or {}
    for _, entry in ipairs(ns.Roster:List()) do
        list[#list + 1] = { guid = entry.guid, name = entry.display, points = pts[entry.guid] or 0 }
    end
    table.sort(list, function(a, b)
        if a.points ~= b.points then
            return a.points > b.points
        end
        return a.name < b.name
    end)
    return list
end

function Points:ThanksLeftToday()
    local guid = ns.Roster:MyGUID()
    if not (self.derived and guid) then
        return PD.MAX_PER_DAY
    end
    local _, _, dayNumber = PD.MonthDay(serverNow())
    return PD.MAX_PER_DAY - (self.derived.perGiverDay[guid .. "@" .. dayNumber] or 0)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function broadcast(id, e)
    local item = Codec.EncodeEntry(id, e)
    if item then
        ns.Comm.Send(Codec.Build("N", item))
        if ns.Comm.IsRestricted() then
            ns.Print(L.SYNC_QUEUED)
        end
    end
end

local function newId(author, t)
    for _ = 1, 10 do
        local id = Codec.MakeId(author, t, math.random(0, 46655))
        if not Points.store:Get(id) then
            return id
        end
    end
    return nil
end

-- Resolve a typed name against the roster. Prints problems; returns the member or nil.
function Points:ResolveName(query)
    local status, result = PD.MatchName(query, ns.Roster:List())
    if status == "ok" then
        return result
    elseif status == "ambiguous" then
        local names = {}
        for i = 1, math.min(#result, MAX_CANDIDATES) do
            names[#names + 1] = esc(result[i].display)
        end
        if #result > MAX_CANDIDATES then
            names[#names + 1] = "…"
        end
        ns.Print(L.THANKS_AMBIGUOUS:format(table.concat(names, ", ")))
    else
        ns.Print(L.THANKS_NOT_FOUND:format(esc(query)))
    end
    return nil
end

-- /spaeti danke <Name>. Returns true when a thank was created.
function Points:Thank(query)
    query = Util.SafeText(query) or ""
    if not (IsInGuild and IsInGuild()) then
        ns.Print(L.THANKS_NO_GUILD)
        return false
    end
    if not self:Bind() then
        ns.Print(L.THANKS_NOT_READY)
        return false
    end
    if strtrim(query) == "" then
        ns.Print(L.THANKS_USAGE)
        return false
    end
    local member = self:ResolveName(query)
    if not member then
        return false
    end
    local me = ns.Roster:MyGUID()
    if not me then
        ns.Print(L.THANKS_NOT_READY)
        return false
    end
    if member.guid == me then
        ns.Print(L.THANKS_SELF)
        return false
    end
    self:Recompute()
    local t = serverNow()
    local ok, reason = PD.CanThank(self.derived, me, member.guid, t)
    if not ok then
        if reason == "pair" then
            ns.Print(L.THANKS_LIMIT_PAIR:format(esc(member.display)))
        else
            ns.Print(L.THANKS_LIMIT_DAY:format(PD.MAX_PER_DAY))
        end
        return false
    end
    local id = newId(me, t)
    local e = { k = "T", a = me, b = member.guid, t = t }
    if not id or not self:Ingest(id, e, "local") then
        ns.Print(L.THANKS_FAILED)
        return false
    end
    broadcast(id, e)
    self:Recompute()
    ns.Print(L.THANKS_DONE:format(esc(member.display), self:ThanksLeftToday()))
    return true
end

-- Officer: void a thank entry by id.
function Points:Void(targetId)
    if not self.store then
        return false
    end
    if not ns.Roster:IsOfficer() then
        ns.Print(L.VOID_NOT_OFFICER)
        return false
    end
    local target = self.store:Get(targetId)
    if not target or target.k ~= "T" then
        ns.Print(L.VOID_NOT_FOUND)
        return false
    end
    if self.derived and self.derived.voided[targetId] then
        ns.Print(L.VOID_ALREADY)
        return false
    end
    local me = ns.Roster:MyGUID()
    local t = serverNow()
    local id = me and newId(me, t)
    local e = { k = "V", a = me, b = targetId, t = t }
    if not id or not self:Ingest(id, e, "local") then
        ns.Print(L.THANKS_FAILED)
        return false
    end
    broadcast(id, e)
    self:Recompute()
    ns.Print(L.VOID_DONE:format(esc(Points.NameOf(target.a)), esc(Points.NameOf(target.b))))
    return true
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
ns:On("SF_ROSTER_UPDATED", function()
    if Points:Bind() then
        rememberNames()
        -- Officer ranks may have changed -> voids may count differently now.
        scheduleRecompute()
    end
end)

ns:On("SF_LOGIN", function()
    -- Day/month rollover (Berlin midnight) without any new data.
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(300, function()
            if Points.store then
                Points:Recompute()
            end
        end)
    end
end)
