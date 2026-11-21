-- Modules/PointsData.lua: Spätipunkte data model (pure Lua; only ns.Time and ns.Codec).
--
-- Entries are immutable and stored as a set keyed by id (union merge, idempotent).
-- All rules (daily limits, officer voids) are applied at *derivation* time, so every
-- client with the same entry set and the same roster computes the same totals.
local _, ns = ...

local Codec = ns.Codec
local Time = ns.Time

local PD = {}
ns.PointsData = PD

PD.MAX_PER_DAY = 3 -- thanks per giver per Berlin day
PD.MAX_PER_PAIR = 1 -- thanks per giver -> receiver per Berlin day
PD.EPOCH = 1793487600 -- 2026-11-01 00:00 Berlin (CET); nothing older is accepted
PD.EPOCH_MONTH = "2611"
PD.FUTURE_SLACK = 3600 -- entries more than 1 h in the future are rejected (clock skew)

-- Rank thresholds (guild decision). Names live in Locale (L.RANKS, same order).
PD.RANK_THRESHOLDS = { 0, 5, 20, 50, 100, 250 }

-- Returns rank index (1-based), next threshold or nil at the top rank.
function PD.RankFor(points)
    local idx = 1
    for i, need in ipairs(PD.RANK_THRESHOLDS) do
        if points >= need then
            idx = i
        end
    end
    return idx, PD.RANK_THRESHOLDS[idx + 1]
end

-- Berlin month key "YYMM" and day of month for a server time.
function PD.MonthDay(t)
    local d = Time.BerlinDate(t)
    return string.format("%02d%02d", d.year % 100, d.month), d.day, d.dayNumber
end

-- Next month key after "YYMM".
function PD.NextMonth(mk)
    local y, m = tonumber(mk:sub(1, 2)), tonumber(mk:sub(3, 4))
    m = m + 1
    if m > 12 then
        y, m = y + 1, 1
    end
    return string.format("%02d%02d", y, m)
end

-- All month keys from EPOCH_MONTH up to the month of `now` (inclusive).
function PD.MonthRange(now)
    local last = PD.MonthDay(now)
    local list, mk = {}, PD.EPOCH_MONTH
    if last < mk then
        return list
    end
    while true do
        list[#list + 1] = mk
        if mk == last or #list > 1200 then
            break
        end
        mk = PD.NextMonth(mk)
    end
    return list
end

-- Structural check of an entry (no roster knowledge). Returns ok, reason.
function PD.Validate(id, e, now)
    if not Codec.IsId(id) or type(e) ~= "table" then
        return false, "id"
    end
    if e.k ~= "T" and e.k ~= "V" then
        return false, "kind"
    end
    if not Codec.IsGUID(e.a) then
        return false, "author"
    end
    if type(e.t) ~= "number" or e.t < PD.EPOCH or (now and e.t > now + PD.FUTURE_SLACK) then
        return false, "time"
    end
    if e.k == "T" then
        if not Codec.IsGUID(e.b) then
            return false, "receiver"
        end
        if e.a == e.b then
            return false, "self"
        end
    elseif not Codec.IsId(e.b) then
        return false, "target"
    end
    return true
end

---------------------------------------------------------------------------
-- Store: wraps the saved `entries` table (id -> {k,a,b,t}) with caches.
---------------------------------------------------------------------------
local Store = {}
Store.__index = Store

function PD.NewStore(entries)
    local s = setmetatable({ entries = entries or {}, meta = {}, version = 0 }, Store)
    s:Rebuild()
    return s
end

function Store:Rebuild()
    self.meta = {}
    self.count = 0
    for id, e in pairs(self.entries) do
        local mk, day = PD.MonthDay(e.t)
        self.meta[id] = { mk = mk, day = day }
        self.count = self.count + 1
    end
    self.version = self.version + 1
end

function Store:Get(id)
    return self.entries[id]
end

-- Adds a validated entry. Returns true if it was new.
function Store:Add(id, e, now)
    if self.entries[id] then
        return false
    end
    if not PD.Validate(id, e, now) then
        return false
    end
    self.entries[id] = { k = e.k, a = e.a, b = e.b, t = e.t }
    local mk, day = PD.MonthDay(e.t)
    self.meta[id] = { mk = mk, day = day }
    self.count = self.count + 1
    self.version = self.version + 1
    return true
end

-- Order-independent summary of a list of ids: count, hash (base36).
local function summarize(ids)
    local sum = 0
    for _, id in ipairs(ids) do
        sum = (sum + Codec.Hash(id)) % 4294967296
    end
    return #ids, Codec.ToBase36(sum)
end
PD.Summarize = summarize

-- month key -> { count, hash }
function Store:MonthSummaries()
    if self.monthCache and self.monthCacheVersion == self.version then
        return self.monthCache
    end
    local byMonth = {}
    for id, m in pairs(self.meta) do
        local list = byMonth[m.mk]
        if not list then
            list = {}
            byMonth[m.mk] = list
        end
        list[#list + 1] = id
    end
    local out = {}
    for mk, ids in pairs(byMonth) do
        local c, h = summarize(ids)
        out[mk] = { count = c, hash = h }
    end
    self.monthCache, self.monthCacheVersion = out, self.version
    return out
end

-- day (1..31) -> { count, hash } for one month.
function Store:DaySummaries(mk)
    local byDay = {}
    for id, m in pairs(self.meta) do
        if m.mk == mk then
            local list = byDay[m.day]
            if not list then
                list = {}
                byDay[m.day] = list
            end
            list[#list + 1] = id
        end
    end
    local out = {}
    for day, ids in pairs(byDay) do
        local c, h = summarize(ids)
        out[day] = { count = c, hash = h }
    end
    return out
end

-- Ids of a month restricted to a set of days ({[day]=true}), sorted for determinism.
function Store:IdsForDays(mk, days)
    local out = {}
    for id, m in pairs(self.meta) do
        if m.mk == mk and days[m.day] then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

---------------------------------------------------------------------------
-- Derivation
--   opts.isOfficer(guid) -> bool (current roster), opts.now (server time)
-- Returns:
--   points[guid], monthPoints[guid], monthKey, monthWinner, monthWinnerCount,
--   accepted (array of {id, e} newest first), acceptedIds{}, voided{}, byDay
---------------------------------------------------------------------------
function PD.Derive(entries, opts)
    opts = opts or {}
    local isOfficer = opts.isOfficer or function() return false end
    local now = opts.now or 0
    local currentMonth = PD.MonthDay(now)

    -- 1. Voids count only when written by someone who is an officer *now*.
    local voided = {}
    for _, e in pairs(entries) do
        if e.k == "V" and isOfficer(e.a) then
            voided[e.b] = true
        end
    end

    -- 2. Valid thanks in a fixed order (time, then id).
    local thanks = {}
    for id, e in pairs(entries) do
        if e.k == "T" and not voided[id] and e.a ~= e.b then
            thanks[#thanks + 1] = { id = id, e = e }
        end
    end
    table.sort(thanks, function(x, y)
        if x.e.t ~= y.e.t then
            return x.e.t < y.e.t
        end
        return x.id < y.id
    end)

    -- 3. Daily limits, first come first served.
    local perGiverDay, perPairDay = {}, {}
    local points, monthPoints, reachedAt = {}, {}, {}
    local accepted, acceptedIds = {}, {}
    for _, th in ipairs(thanks) do
        local e = th.e
        local mk, _, dayNumber = PD.MonthDay(e.t)
        local gk = e.a .. "@" .. dayNumber
        local pk = e.a .. ">" .. e.b .. "@" .. dayNumber
        local used = perGiverDay[gk] or 0
        if used < PD.MAX_PER_DAY and (perPairDay[pk] or 0) < PD.MAX_PER_PAIR then
            perGiverDay[gk] = used + 1
            perPairDay[pk] = (perPairDay[pk] or 0) + 1
            points[e.b] = (points[e.b] or 0) + 1
            if mk == currentMonth then
                monthPoints[e.b] = (monthPoints[e.b] or 0) + 1
                reachedAt[e.b] = e.t
            end
            accepted[#accepted + 1] = th
            acceptedIds[th.id] = true
        end
    end

    -- 4. Stammkunde des Monats: most thanks this month; tie -> earliest to reach it.
    local winner, best, bestAt
    for guid, c in pairs(monthPoints) do
        local at = reachedAt[guid]
        if not winner or c > best or (c == best and (at < bestAt or (at == bestAt and guid < winner))) then
            winner, best, bestAt = guid, c, at
        end
    end

    -- Newest first for display.
    local recent = {}
    for i = #accepted, 1, -1 do
        recent[#recent + 1] = accepted[i]
    end

    return {
        points = points,
        monthPoints = monthPoints,
        monthKey = currentMonth,
        monthWinner = winner,
        monthWinnerCount = best or 0,
        accepted = recent,
        acceptedIds = acceptedIds,
        voided = voided,
        perGiverDay = perGiverDay,
        perPairDay = perPairDay,
    }
end

-- Would a new thank giver -> receiver at time t be accepted? Returns ok, reason.
-- Uses a derived state (same rules as Derive).
function PD.CanThank(derived, giver, receiver, t)
    if giver == receiver then
        return false, "self"
    end
    local _, _, dayNumber = PD.MonthDay(t)
    if (derived.perPairDay[giver .. ">" .. receiver .. "@" .. dayNumber] or 0) >= PD.MAX_PER_PAIR then
        return false, "pair"
    end
    local used = derived.perGiverDay[giver .. "@" .. dayNumber] or 0
    if used >= PD.MAX_PER_DAY then
        return false, "day"
    end
    return true, nil, PD.MAX_PER_DAY - used - 1
end

---------------------------------------------------------------------------
-- Name matching against the roster.
--   members: array of { guid = ..., name = "Vorname Nachname" }
-- Returns "ok", member | "none" | "ambiguous", candidates (sorted by name)
---------------------------------------------------------------------------
local function norm(s)
    local lower = ns.Util and ns.Util.Lower or string.lower
    s = lower(s or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return s
end
PD.NormName = norm

local function startsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

-- Tiers: exact full name -> exact whole word (first name or surname) -> prefix of
-- the full name or of any word. Within a tier more than one hit is ambiguous.
function PD.MatchName(query, members)
    local q = norm(query)
    if q == "" then
        return "none"
    end
    local exact, word, prefix = {}, {}, {}
    for _, m in ipairs(members) do
        local n = norm(m.name)
        if n == q then
            exact[#exact + 1] = m
        else
            local isWord, isPrefix = false, startsWith(n, q)
            for w in n:gmatch("%S+") do
                if w == q then
                    isWord = true
                elseif startsWith(w, q) then
                    isPrefix = true
                end
            end
            if isWord then
                word[#word + 1] = m
            elseif isPrefix then
                prefix[#prefix + 1] = m
            end
        end
    end
    for _, group in ipairs({ exact, word, prefix }) do
        if #group == 1 then
            return "ok", group[1]
        elseif #group > 1 then
            table.sort(group, function(x, y) return x.name < y.name end)
            return "ambiguous", group
        end
    end
    return "none"
end
