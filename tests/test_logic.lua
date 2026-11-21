-- tests/test_logic.lua: pure logic – codec, summaries, derivation, limits, ranks, names.
local T = require("helpers.wow")
local check, eq = T.check, T.eq

local world = T.NewWorld(42)
world:AddMember("Anna Alt", "Player-6949-0000000A", "Guild Master", 0)
local client = world:Login("Anna Alt")
local ns = client.ns
local Codec, PD = ns.Codec, ns.PointsData

local A, B, C, D, E = "Player-6949-0000000A", "Player-6939-0000000B", "Player-6945-0000000C",
    "Player-6949-0000000D", "Player-6841-0000000E"
local DAY = 86400
local T0 = T.START -- 2026-11-21 11:00 Berlin

---------------------------------------------------------------------------
-- Codec
---------------------------------------------------------------------------
for _, n in ipairs({ 0, 1, 35, 36, 46655, T0, 4294967295 }) do
    eq(Codec.FromBase36(Codec.ToBase36(n)), n, "base36 round trip " .. n)
end
check(Codec.FromBase36("A1") == nil and Codec.FromBase36("") == nil and Codec.FromBase36("-1") == nil,
    "base36 rejects garbage")
eq(Codec.ShortGUID(B), "6939-0000000B", "short guid")
eq(Codec.LongGUID("6939-0000000B"), B, "long guid")
check(Codec.ShortGUID("Creature-0-1-2") == nil and Codec.LongGUID("x-y") == nil, "guid validation")

local id1 = Codec.MakeId(A, T0, 1234)
check(Codec.IsId(id1), "MakeId produces a valid id: " .. id1)
local item = Codec.EncodeEntry(id1, { k = "T", a = A, b = B, t = T0 })
check(item and #item < 64, "thank entry encodes compactly: " .. tostring(item))
local rid, re = Codec.DecodeEntry(item)
check(rid == id1 and re.k == "T" and re.a == A and re.b == B and re.t == T0, "thank entry round trip")
local vid = Codec.MakeId(B, T0 + 5, 7)
local vItem = Codec.EncodeEntry(vid, { k = "V", a = B, b = id1, t = T0 + 5 })
local vid2, ve = Codec.DecodeEntry(vItem)
check(vid2 == vid and ve.k == "V" and ve.b == id1, "void entry round trip")
for _, bad in ipairs({ "", "T", "T:x:y:z:w", "X:" .. id1 .. ":6949-A:6949-B:abc", "T:" .. id1 .. ":6949-A:zz:abc",
    "T:" .. id1 .. ":6949-0A:6949-0B:A_B", 42 }) do
    check(Codec.DecodeEntry(bad) == nil, "decode rejects " .. tostring(bad))
end

local proto, mtype, fields = Codec.Parse("1~N~" .. item)
check(proto == 1 and mtype == "N" and fields[1] == item, "parse N")
local p2 = Codec.Parse("2~Z~future~stuff")
eq(p2, 2, "parse keeps future protocol number")
check(Codec.Parse("hello") == nil and Codec.Parse(("x"):rep(300)) == nil and Codec.Parse(nil) == nil,
    "parse rejects garbage")
local f3 = select(3, Codec.Parse("1~H~2611~2612~"))
check(f3[1] == "2611" and f3[2] == "2612" and f3[3] == "", "parse keeps empty fields")

-- Pack: every item exactly once, every message <= 255 bytes.
do
    local items = {}
    for i = 1, 40 do
        items[i] = Codec.EncodeEntry(Codec.MakeId(A, T0 + i, i), { k = "T", a = A, b = C, t = T0 + i })
    end
    local msgs = Codec.Pack(Codec.Build("E"), items)
    local seen, ok = 0, true
    for _, m in ipairs(msgs) do
        ok = ok and #m <= 255
        local _, _, f = Codec.Parse(m)
        seen = seen + #Codec.Split(f[1], ",")
    end
    check(ok, "pack: all messages <= 255 bytes")
    eq(seen, 40, "pack: all items present")
    check(#msgs >= 9 and #msgs <= 12, "pack: about 4 entries per message, got " .. #msgs .. " messages")
end

-- PackRanges: contiguous ranges covering all slots, deterministic, <= 255 bytes.
do
    local slots = {}
    for d = 1, 31 do
        slots[d] = d
    end
    local function itemFor(d)
        return (d % 3 ~= 0) and (d .. ":" .. (d * 7) .. ":" .. Codec.ToBase36(Codec.Hash("x" .. d))) or nil
    end
    local a = Codec.PackRanges("1~D~6949-0000000A~2611", slots, itemFor)
    local b = Codec.PackRanges("1~D~6949-0000000A~2611", slots, itemFor)
    eq(table.concat(a, "\n"), table.concat(b, "\n"), "pack ranges deterministic")
    check(#a >= 2, "pack ranges split into parts")
    local expectFrom, ok = 1, true
    for _, m in ipairs(a) do
        local _, _, f = Codec.Parse(m)
        ok = ok and #m <= 255 and tonumber(f[3]) == expectFrom
        expectFrom = tonumber(f[4]) + 1
    end
    check(ok and expectFrom == 32, "pack ranges contiguous over 1..31")
end

-- Summaries are order independent.
do
    local c1, h1 = PD.Summarize({ "a.1.1", "b.2.2", "c.3.3" })
    local c2, h2 = PD.Summarize({ "c.3.3", "a.1.1", "b.2.2" })
    check(c1 == 3 and c1 == c2 and h1 == h2, "summary order independent")
    local _, h3 = PD.Summarize({ "a.1.1", "b.2.2", "c.3.4" })
    check(h3 ~= h1, "summary changes with ids")
end

---------------------------------------------------------------------------
-- Time keys
---------------------------------------------------------------------------
eq(PD.MonthDay(T0), "2611", "month key")
eq(PD.MonthDay(PD.EPOCH), "2611", "epoch is November 2026 in Berlin")
eq(PD.MonthDay(PD.EPOCH - 1), "2610", "one second before epoch is October")
eq(PD.NextMonth("2612"), "2701", "next month over new year")
eq(#PD.MonthRange(T0 + 60 * DAY), 3, "month range Nov..Jan")

---------------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------------
check(PD.Validate(id1, { k = "T", a = A, b = B, t = T0 }, T0), "valid thank")
check(not PD.Validate(id1, { k = "T", a = A, b = A, t = T0 }, T0), "self thank invalid")
check(not PD.Validate(id1, { k = "T", a = A, b = B, t = T0 + 7200 }, T0), "future thank invalid")
check(not PD.Validate(id1, { k = "T", a = A, b = B, t = PD.EPOCH - 10 }, T0), "pre-epoch thank invalid")
check(not PD.Validate("bad id", { k = "T", a = A, b = B, t = T0 }, T0), "bad id invalid")
check(not PD.Validate(id1, { k = "Q", a = A, b = B, t = T0 }, T0), "unknown kind invalid")

---------------------------------------------------------------------------
-- Derivation and limits
---------------------------------------------------------------------------
local seq = 0
local function thank(entries, giver, receiver, t)
    seq = seq + 1
    local id = Codec.MakeId(giver, t, seq)
    entries[id] = { k = "T", a = giver, b = receiver, t = t }
    return id
end
local officers = { [A] = true }
local opts = { now = T0 + DAY * 2, isOfficer = function(g) return officers[g] or false end }

do -- 3 per giver per day; the 4th (latest) is dropped
    local es = {}
    thank(es, B, A, T0 + 1)
    thank(es, B, C, T0 + 2)
    thank(es, B, D, T0 + 3)
    local late = thank(es, B, E, T0 + 4)
    local d = PD.Derive(es, opts)
    eq(#d.accepted, 3, "daily limit: 3 accepted")
    check(not d.acceptedIds[late], "daily limit: 4th thank dropped")
    eq(d.points[E], nil, "daily limit: E got nothing")
end

do -- 1 per pair per day; next Berlin day is fine
    local es = {}
    thank(es, B, A, T0)
    thank(es, B, A, T0 + 60)
    thank(es, B, A, T0 + DAY)
    local d = PD.Derive(es, opts)
    eq(d.points[A], 2, "pair limit per day")
end

do -- Berlin midnight: 23:30 and 00:30 Berlin are different days (CET = UTC+1)
    local es = {}
    local evening = 1795300200 -- 2026-11-21 22:30 UTC = 23:30 Berlin
    thank(es, B, A, evening)
    thank(es, B, A, evening + 3600) -- 00:30 Berlin, next day
    local d = PD.Derive(es, opts)
    eq(d.points[A], 2, "reset at Berlin midnight")
    local es2 = {}
    thank(es2, B, A, evening - 3600) -- 22:30 Berlin same day
    thank(es2, B, A, evening)
    eq(PD.Derive(es2, opts).points[A], 1, "same Berlin day before midnight")
end

do -- officer void counts, non-officer void doesn't; a voided thank frees the slot
    local es = {}
    local x = thank(es, B, C, T0 + 1)
    thank(es, B, D, T0 + 2)
    thank(es, B, E, T0 + 3)
    local fourth = thank(es, B, A, T0 + 4)
    es[Codec.MakeId(C, T0 + 10, 1)] = { k = "V", a = C, b = x, t = T0 + 10 } -- C is no officer
    local d = PD.Derive(es, opts)
    eq(d.points[C], 1, "non-officer void ignored")
    check(not d.acceptedIds[fourth], "4th still over limit")
    es[Codec.MakeId(A, T0 + 11, 2)] = { k = "V", a = A, b = x, t = T0 + 11 } -- A is officer
    d = PD.Derive(es, opts)
    eq(d.points[C], nil, "officer void removes the point")
    check(d.voided[x], "voided set")
    check(d.acceptedIds[fourth], "voided thank no longer uses a daily slot")
    officers[A] = false -- A demoted: void no longer counts (checked against the current roster)
    eq(PD.Derive(es, opts).points[C], 1, "void of a former officer ignored")
    officers[A] = true
end

do -- same result for any insertion order
    local base = {}
    for i = 1, 60 do
        local givers = { A, B, C, D, E }
        local g = givers[(i % 5) + 1]
        local r = givers[((i * 3) % 5) + 1]
        if g ~= r then
            thank(base, g, r, T0 + (i % 7) * 3600 * 5 + i)
        end
    end
    local ids = {}
    for id in pairs(base) do
        ids[#ids + 1] = id
    end
    local function derivedString(order)
        local es = {}
        for _, id in ipairs(order) do
            es[id] = base[id]
        end
        local d = PD.Derive(es, opts)
        local parts = {}
        for _, g in ipairs({ A, B, C, D, E }) do
            parts[#parts + 1] = tostring(d.points[g] or 0)
        end
        return table.concat(parts, ",") .. "|" .. tostring(d.monthWinner)
    end
    local first = derivedString(ids)
    local stable = true
    for _ = 1, 20 do
        for i = #ids, 2, -1 do
            local j = math.random(i)
            ids[i], ids[j] = ids[j], ids[i]
        end
        stable = stable and derivedString(ids) == first
    end
    check(stable, "derivation independent of insertion order: " .. first)
end

do -- Stammkunde des Monats: most thanks; tie -> earliest to reach
    local es = {}
    thank(es, A, C, T0 + 10)
    thank(es, B, D, T0 + 20)
    thank(es, E, D, T0 + 30) -- D reaches 2 at +30
    thank(es, B, C, T0 + DAY + 5) -- C reaches 2 later
    local d = PD.Derive(es, opts)
    eq(d.monthWinner, D, "month winner tie -> earliest to reach")
    eq(d.monthWinnerCount, 2, "month winner count")
    thank(es, A, C, T0 + DAY + 50)
    eq(PD.Derive(es, opts).monthWinner, C, "month winner with most thanks")
    local nextMonth = { now = T0 + 12 * DAY, isOfficer = opts.isOfficer } -- 3 Dec
    eq(PD.Derive(es, nextMonth).monthWinner, nil, "new month starts empty")
    eq(PD.Derive(es, nextMonth).points[C], 3, "all-time points stay")
end

do -- CanThank mirrors the derivation rules
    local es = {}
    thank(es, A, B, T0)
    local d = PD.Derive(es, opts)
    check(not PD.CanThank(d, A, B, T0 + 5), "CanThank: pair limit")
    local ok, _, left = PD.CanThank(d, A, C, T0 + 5)
    check(ok and left == 1, "CanThank: ok, 1 left after this one")
    check(not PD.CanThank(d, A, A, T0), "CanThank: self")
end

---------------------------------------------------------------------------
-- Ranks
---------------------------------------------------------------------------
local rankCases = { { 0, 1, 5 }, { 4, 1, 5 }, { 5, 2, 20 }, { 19, 2, 20 }, { 20, 3, 50 }, { 50, 4, 100 },
    { 100, 5, 250 }, { 249, 5, 250 }, { 250, 6, nil }, { 999, 6, nil } }
for _, c in ipairs(rankCases) do
    local idx, nextNeed = PD.RankFor(c[1])
    check(idx == c[2] and nextNeed == c[3], ("rank for %d -> %d/%s, got %d/%s"):format(c[1], c[2],
        tostring(c[3]), idx, tostring(nextNeed)))
end
eq(#ns.L.RANKS, #PD.RANK_THRESHOLDS, "one rank name per threshold")
eq(ns.L.RANKS[3], "Stammkunde", "rank name 3")

---------------------------------------------------------------------------
-- Name matching
---------------------------------------------------------------------------
local members = {
    { guid = A, name = "Lava Lorenz" }, { guid = B, name = "Kalle Kiez" }, { guid = C, name = "Karin Kurz" },
    { guid = D, name = "Änne Müller" }, { guid = E, name = "Lavendel Fuchs" },
}
local function match(q)
    local status, r = PD.MatchName(q, members)
    if status == "ok" then
        return r.guid
    end
    return status, r
end
eq(match("Lava Lorenz"), A, "match full name")
eq(match("  lava   LORENZ "), A, "match case/space insensitive")
eq(match("lava"), A, "exact first name beats prefix of another first name")
eq(match("kalle"), B, "unique first name")
eq(match("kar"), C, "unique prefix")
eq(match("kurz"), C, "surname")
eq(match("ÄNNE"), D, "umlaut case folding")
eq(match("müll"), D, "surname prefix with umlaut")
local st, cands = match("ka")
check(st == "ambiguous" and #cands == 2 and cands[1].name == "Kalle Kiez", "ambiguous prefix lists candidates")
local st2 = match("lav")
eq(st2, "ambiguous", "lav is ambiguous")
eq(match("Zorro"), "none", "no match")
eq(match(""), "none", "empty query")

check(#world.errors == 0, "no Lua errors: " .. table.concat(world.errors, " | "))
