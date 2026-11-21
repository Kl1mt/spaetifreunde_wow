-- Modules/Sync.lua: guild sync of Spätipunkte entries over hidden addon messages.
-- Protocol (see docs/PROTOCOL.md):
--   N  new entry, broadcast once by its author (accepted only if sender == author)
--   H  HELLO: per-month summaries (count + hash of ids), sent on login and every 15 min
--   D  DAYS: per-day summaries of one month, sent by peers whose month summary differs
--   R  REQ: "send me your entries of these days"
--   E  ENTRIES: chunks of entries (relayed; accepted from any guild member)
-- Cheat-resistant, not cheat-proof: relayed entries are trusted structurally, limits
-- and officer checks are applied at derivation time on every client.
local _, ns = ...

local Codec = ns.Codec
local Comm = ns.Comm
local PD = ns.PointsData

local Sync = {}
ns.Sync = Sync

Sync.HELLO_JITTER_MIN = 10
Sync.HELLO_JITTER_MAX = 40
Sync.HELLO_INTERVAL = 900 -- periodic HELLO (15 min) plus jitter
Sync.REPLY_JITTER_MIN = 1
Sync.REPLY_JITTER_MAX = 5
Sync.SEEN_TTL = 60 -- seconds a DAYS part from someone else suppresses our identical one

Sync.lastHello = nil -- server time of our last HELLO
Sync.lastData = nil -- server time we last received sync entries
Sync.lastNew = nil -- server time we last received a new entry

local pendingDays = {} -- target .. mk -> true
local seenDays = {} -- raw DAYS message -> GetTime()
local pushed = {} -- mk .. "/" .. day -> Comm ticket of the last chunk queued for that day
local helloLoopStarted = false

local function serverNow()
    return GetServerTime and GetServerTime() or 0
end

local function clock()
    return GetTime and GetTime() or 0
end

local function after(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
    else
        fn()
    end
end

local function jitter(lo, hi)
    return lo + math.random() * (hi - lo)
end

local function store()
    return ns.Points.store
end

-- Parse "key:count:hash,key:count:hash" -> key -> "count:hash"
local function parseSummaries(list)
    local out = {}
    if not list or list == "" then
        return out
    end
    for _, item in ipairs(Codec.Split(list, Codec.LIST_SEP)) do
        local key, count, hash = item:match("^(%w+):(%d+):(%w+)$")
        if key then
            out[key] = count .. ":" .. hash
        end
    end
    return out
end

local function sumString(s)
    return s and (s.count .. ":" .. s.hash) or nil
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
function Sync.SendHello()
    local s = store()
    if not s then
        return
    end
    local sums = s:MonthSummaries()
    local months = PD.MonthRange(serverNow())
    if #months == 0 then
        return
    end
    local msgs = Codec.PackRanges(Codec.Build("H"), months, function(mk)
        local sum = sums[mk]
        return sum and (mk .. ":" .. sumString(sum)) or nil
    end)
    for _, msg in ipairs(msgs) do
        Comm.Send(msg)
    end
    Sync.lastHello = serverNow()
    ns:Fire("SF_SYNC_STATE")
end

-- All DAYS messages describing our data of month mk, addressed to target.
local function buildDays(targetGuid, mk)
    local sums = store():DaySummaries(mk)
    local slots = {}
    for d = 1, 31 do
        slots[d] = d
    end
    local header = Codec.Build("D", Codec.ShortGUID(targetGuid), mk)
    return Codec.PackRanges(header, slots, function(d)
        local sum = sums[d]
        return sum and (d .. ":" .. sumString(sum)) or nil
    end)
end
Sync.BuildDays = buildDays

-- Push our entries of the given days (bulk queue). Days whose entries are still
-- waiting in our queue are skipped: that broadcast will reach everyone anyway.
function Sync.SendEntries(mk, days)
    local s = store()
    local wanted = {}
    for d in pairs(days) do
        if not Comm.IsPending(pushed[mk .. "/" .. d]) then
            wanted[d] = true
        end
    end
    local items = {}
    for _, id in ipairs(s:IdsForDays(mk, wanted)) do
        local item = Codec.EncodeEntry(id, s:Get(id))
        if item then
            items[#items + 1] = item
        end
    end
    local ticket
    for _, msg in ipairs(Codec.Pack(Codec.Build("E"), items)) do
        ticket = Comm.Send(msg, true) or ticket
    end
    for d in pairs(wanted) do
        pushed[mk .. "/" .. d] = ticket
    end
end

local function scheduleDays(targetGuid, mk)
    local key = targetGuid .. mk
    if pendingDays[key] then
        return
    end
    pendingDays[key] = true
    after(jitter(Sync.REPLY_JITTER_MIN, Sync.REPLY_JITTER_MAX), function()
        pendingDays[key] = nil
        if not store() then
            return
        end
        local t = clock()
        for _, msg in ipairs(buildDays(targetGuid, mk)) do
            local seen = seenDays[msg]
            -- Someone with identical data already answered this part -> stay quiet.
            if not (seen and t - seen < Sync.SEEN_TTL) then
                seenDays[msg] = t
                Comm.Send(msg)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function onHello(sender, fields)
    local s = store()
    if not s then
        return
    end
    local from, to, list = fields[1], fields[2], fields[3]
    if not (from and to and from:match("^%d%d%d%d$") and to:match("^%d%d%d%d$")) or from > to then
        return
    end
    local theirs = parseSummaries(list)
    local mine = s:MonthSummaries()
    local mk, guard = from, 0
    while mk <= to and guard < 1200 do
        if sumString(mine[mk]) ~= theirs[mk] then
            scheduleDays(sender, mk)
        end
        mk = PD.NextMonth(mk)
        guard = guard + 1
    end
end

local function onDays(sender, fields, _, raw)
    local s = store()
    if not s then
        return
    end
    local target = Codec.LongGUID(fields[1])
    local mk = fields[2]
    local from, to = tonumber(fields[3]), tonumber(fields[4])
    if not (target and mk and mk:match("^%d%d%d%d$") and from and to) then
        return
    end
    if target ~= ns.Roster:MyGUID() then
        -- Remember for suppression of our own identical answer.
        seenDays[raw] = clock()
        return
    end
    local theirs = parseSummaries(fields[5])
    local mine = s:DaySummaries(mk)
    local push, req, anyReq = {}, {}, false
    for d = math.max(1, from), math.min(31, to) do
        local m, th = sumString(mine[d]), theirs[tostring(d)]
        if m ~= th then
            if m then
                push[d] = true
            end
            if th then
                req[#req + 1] = d
                anyReq = true
            end
        end
    end
    if next(push) then
        Sync.SendEntries(mk, push)
    end
    if anyReq then
        local header = Codec.Build("R", Codec.ShortGUID(sender), mk)
        local items = {}
        for _, d in ipairs(req) do
            items[#items + 1] = tostring(d)
        end
        for _, msg in ipairs(Codec.Pack(header, items)) do
            Comm.Send(msg)
        end
    end
end

local function onRequest(_, fields)
    local s = store()
    if not s then
        return
    end
    local target = Codec.LongGUID(fields[1])
    local mk = fields[2]
    if target ~= ns.Roster:MyGUID() or not (mk and mk:match("^%d%d%d%d$")) then
        return
    end
    local days = {}
    for _, d in ipairs(Codec.Split(fields[3] or "", Codec.LIST_SEP)) do
        d = tonumber(d)
        if d and d >= 1 and d <= 31 then
            days[d] = true
        end
    end
    if next(days) then
        Sync.SendEntries(mk, days)
    end
end

local function onEntries(_, fields)
    if not store() then
        return
    end
    local added = 0
    for _, item in ipairs(Codec.Split(fields[1] or "", Codec.LIST_SEP)) do
        local id, e = Codec.DecodeEntry(item)
        if id and ns.Points:Ingest(id, e, "sync") then
            added = added + 1
        end
    end
    Sync.lastData = serverNow()
    if added > 0 then
        ns:Fire("SF_SYNC_STATE")
    end
end

local function onNew(sender, fields)
    if not store() then
        return
    end
    local id, e = Codec.DecodeEntry(fields[1])
    -- A direct broadcast must come from the entry's author.
    if not id or e.a ~= sender then
        return
    end
    if ns.Points:Ingest(id, e, "direct") then
        Sync.lastNew = serverNow()
        ns:Fire("SF_SYNC_STATE")
    end
end

Comm.Register("H", onHello)
Comm.Register("D", onDays)
Comm.Register("R", onRequest)
Comm.Register("E", onEntries)
Comm.Register("N", onNew)

---------------------------------------------------------------------------
-- HELLO schedule: 10–40 s after login, then every ~15 min.
---------------------------------------------------------------------------
local function helloLoop()
    Sync.SendHello()
    after(Sync.HELLO_INTERVAL + jitter(0, 60), helloLoop)
end

ns:On("SF_POINTS_BOUND", function()
    if helloLoopStarted then
        return
    end
    helloLoopStarted = true
    after(jitter(Sync.HELLO_JITTER_MIN, Sync.HELLO_JITTER_MAX), helloLoop)
end)

-- Status for the UI: "pausiert", queue size, last activity.
function Sync.Status()
    return {
        paused = Comm.paused,
        queued = Comm.QueueSize(),
        entries = store() and store().count or 0,
        lastHello = Sync.lastHello,
        lastData = Sync.lastData or Sync.lastNew,
    }
end
