-- tests/test_storm.lua: sync efficiency with many peers (real throttle, real queue).
--   1. 12 peers with a large identical history + 1 fresh client, run past HELLO_INTERVAL:
--      the entries must be sent about once, not once per peer HELLO.
--   2. Mass login of 13 clients with slightly different data: no duplicate REQ/dumps.
--   3. /reload within 60 s of a DAYS answer: the new HELLO is answered again.
local T = require("helpers.wow")
local check, eq = T.check, T.eq

local START = 1813053600 -- 2027-06-15 10:00 UTC: about 7 months of history possible

local function sameEntries(c1, c2)
    local e1, e2 = c1.ns.Points.store.entries, c2.ns.Points.store.entries
    for id in pairs(e1) do
        if not e2[id] then
            return false
        end
    end
    for id in pairs(e2) do
        if not e1[id] then
            return false
        end
    end
    return true
end

local function addMembers(world, n)
    local guids = {}
    for i = 1, n do
        local guid = ("Player-6949-%08X"):format(0x100 + i)
        local rank = (i == 1) and "Guild Master" or "Member"
        world:AddMember(("Peer%02d Spandau"):format(i), guid, rank, i == 1 and 0 or 3)
        guids[i] = guid
    end
    return guids
end

-- Minimum number of E chunks needed to send `entries` once (packed per month like SendEntries).
local function minChunks(c, entries)
    local Codec, PD = c.ns.Codec, c.ns.PointsData
    local byMonth = {}
    for id, e in pairs(entries) do
        local mk = PD.MonthDay(e.t)
        byMonth[mk] = byMonth[mk] or {}
        table.insert(byMonth[mk], id)
    end
    local n = 0
    for _, ids in pairs(byMonth) do
        table.sort(ids)
        local items = {}
        for _, id in ipairs(ids) do
            items[#items + 1] = Codec.EncodeEntry(id, entries[id])
        end
        n = n + #Codec.Pack(Codec.Build("E"), items)
    end
    return n
end

local function countTypes(world, from)
    return world:Count("H", from), world:Count("D", from), world:Count("R", from), world:Count("E", from)
end

---------------------------------------------------------------------------
-- 1. Sync storm during a long catch-up
---------------------------------------------------------------------------
do
    local world = T.NewWorld(11, { start = START })
    local guids = addMembers(world, 13)
    local peers = {}
    for i = 1, 12 do
        peers[i] = world:Login(world.members[i].name)
    end
    world:Advance(1)
    local Codec, PD = peers[1].ns.Codec, peers[1].ns.PointsData
    local history = {}
    local n, t = 0, PD.EPOCH + 3600
    while n < 7000 do
        local g = guids[(n % 12) + 1]
        local r = guids[((n * 7 + 3) % 13) + 1]
        if r ~= g then
            local id = Codec.MakeId(g, t, n % 46656)
            history[id] = { k = "T", a = g, b = r, t = t }
            n = n + 1
        end
        t = t + 2700 -- ~32 per day
    end
    check(t < START, "history ends before now")
    for _, c in ipairs(peers) do
        for id, e in pairs(history) do
            c.ns.Points:Ingest(id, e, "local")
        end
    end
    world:Advance(60) -- peers' login HELLOs (identical data -> quiet)
    local minimum = minChunks(peers[1], history)
    local logBefore = #world.log
    local fresh = world:Login(world.members[13].name)
    local elapsed, converged = 0, nil
    while elapsed < 6000 do
        world:Advance(100, 0.25)
        elapsed = elapsed + 100
        if not converged and fresh.ns.Points.store.count == 7000 then
            converged = elapsed
        end
        if converged and elapsed >= converged + 1000 and elapsed > fresh.ns.Sync.HELLO_INTERVAL * 2 then
            break
        end
    end
    local h, d, r, e = countTypes(world, logBefore + 1)
    T.stormStats = T.stormStats or {}
    T.stormStats.storm = ("12 peers, 7000 entries: converged after %s s; H %d, D %d, R %d, E %d (minimum %d)")
        :format(tostring(converged), h, d, r, e, minimum)
    print("  " .. T.stormStats.storm)
    check(converged ~= nil, "fresh client converged")
    check(sameEntries(fresh, peers[1]), "fresh client has the same entries")
    check(e <= minimum * 1.3, ("E stays near the minimum (%d <= 1.3 x %d)"):format(e, minimum))
    eq(world.throttled, 0, "no throttle results")
    check(#world.errors == 0, "no Lua errors: " .. table.concat(world.errors, " | "))
end

---------------------------------------------------------------------------
-- 2. Mass login: 13 clients, shared history plus a few own entries each
---------------------------------------------------------------------------
do
    local world = T.NewWorld(12, { start = START })
    local guids = addMembers(world, 13)
    local clients = {}
    for i = 1, 13 do
        clients[i] = world:Login(world.members[i].name)
    end
    world:Advance(0.5) -- bound, HELLO jitter (10-40 s) still pending
    local Codec, PD = clients[1].ns.Codec, clients[1].ns.PointsData
    local all, base = {}, PD.EPOCH + 7200
    for k = 1, 300 do
        local g, r = guids[(k % 13) + 1], guids[((k + 5) % 13) + 1]
        local t = base + k * 50000
        all[Codec.MakeId(g, t, k)] = { k = "T", a = g, b = r, t = t }
    end
    for _, c in ipairs(clients) do
        for id, e in pairs(all) do
            c.ns.Points:Ingest(id, e, "local")
        end
    end
    -- Each client has 4 entries nobody else has yet (spread over the months).
    local unique = 0
    for i, c in ipairs(clients) do
        for k = 1, 4 do
            local g, r = guids[i], guids[(i % 13) + 1]
            local t = base + (i * 4 + k) * 1100000 + i
            local id = Codec.MakeId(g, t, 999 + k)
            local e = { k = "T", a = g, b = r, t = t }
            c.ns.Points:Ingest(id, e, "local")
            all[id] = e
            unique = unique + 1
        end
    end
    local logBefore = #world.log
    local elapsed, converged = 0, nil
    while elapsed < 4000 do
        world:Advance(50, 0.25)
        elapsed = elapsed + 50
        local ok = true
        for _, c in ipairs(clients) do
            if c.ns.Points.store.count ~= 300 + unique then
                ok = false
            end
        end
        if ok then
            converged = elapsed
            break
        end
    end
    local h, d, r, e = countTypes(world, logBefore + 1)
    T.stormStats.mass = ("mass login 13 clients, %d missing entries each: converged after %s s; H %d, D %d, R %d, E %d")
        :format(unique - 4, tostring(converged), h, d, r, e)
    print("  " .. T.stormStats.mass)
    check(converged ~= nil, "mass login converged")
    check(r <= 60, ("few REQ messages (%d)"):format(r))
    check(e <= 200, ("few E messages (%d)"):format(e))
    eq(world.throttled, 0, "no throttle results (mass login)")
    check(#world.errors == 0, "no Lua errors: " .. table.concat(world.errors, " | "))
end

---------------------------------------------------------------------------
-- 3. /reload right after a DAYS answer: the new HELLO is answered again
---------------------------------------------------------------------------
do
    local world = T.NewWorld(13, { start = START })
    local guids = addMembers(world, 3)
    local a = world:Login(world.members[1].name)
    local b = world:Login(world.members[2].name)
    world:Advance(60)
    local Codec, PD = a.ns.Codec, a.ns.PointsData
    for k = 1, 20 do
        local t = PD.EPOCH + k * 86400
        local id = Codec.MakeId(guids[1], t, k)
        for _, c in ipairs({ a, b }) do
            c.ns.Points:Ingest(id, { k = "T", a = guids[1], b = guids[2], t = t }, "local")
        end
    end
    world:Advance(1)
    local x = world:Login(world.members[3].name)
    x.deaf = true -- HELLO goes out, the answers are lost (UI reload in between)
    world:Advance(50, 0.25)
    check(world:Count("D") > 0, "DAYS answered the first HELLO")
    local saved = x:Saved()
    x:Logout()
    x = world:Login(world.members[3].name, saved)
    world:Advance(80)
    eq(x.ns.Points.store.count, 20, "reloaded client caught up right away")
    check(#world.errors == 0, "no Lua errors: " .. table.concat(world.errors, " | "))
end

---------------------------------------------------------------------------
-- 4. Catch-up notices: one summary + only the final rank; sound setting on its own
---------------------------------------------------------------------------
do
    local world = T.NewWorld(14, { start = START })
    local guids = addMembers(world, 13)
    local peer = world:Login(world.members[1].name)
    world:Advance(60)
    local Codec, PD = peer.ns.Codec, peer.ns.PointsData
    local me = guids[13]
    local day = 0
    local function thankMe(n)
        for _ = 1, n do
            day = day + 1
            local g = guids[((day - 1) % 12) + 1]
            local t = PD.EPOCH + day * 86400 + 3600
            peer.ns.Points:Ingest(Codec.MakeId(g, t, day), { k = "T", a = g, b = me, t = t }, "local")
            -- filler from others, so the catch-up takes many chunks
            for k = 1, 3 do
                local g2, r2 = guids[((day + k) % 12) + 1], guids[((day + k + 4) % 12) + 1]
                if g2 ~= r2 then
                    peer.ns.Points:Ingest(Codec.MakeId(g2, t + k, day * 10 + k), { k = "T", a = g2, b = r2,
                        t = t + k }, "local")
                end
            end
        end
    end
    local function count(text, pattern)
        return select(2, text:gsub(pattern, ""))
    end

    -- Fresh install: 30 thanks in the history -> one summary line, no rank-up, one sound.
    thankMe(30)
    world:Advance(1)
    local x = world:Login(world.members[13].name)
    world:Advance(400)
    eq(x.ns.Points:MyStanding(), 30, "fresh client has its 30 points")
    local text = x:ChatText()
    eq(count(text, "Uffjestiegen"), 0, "fresh install: no rank-up notices for old history")
    eq(count(text, "neue Dankeschöns"), 1, "fresh install: one summary line")
    check(#x.sounds <= 1, "fresh install: at most one sound (" .. #x.sounds .. ")")
    local saved = x:Saved()
    x:Logout()

    -- Long absence: 30 more thanks (Stammkunde -> Kiezgröße) -> exactly one rank-up line.
    thankMe(30)
    world:Advance(1)
    x = world:Login(world.members[13].name, saved)
    world:Advance(400)
    eq(x.ns.Points:MyStanding(), 60, "returning client has 60 points")
    text = x:ChatText()
    eq(count(text, "Uffjestiegen"), 1, "returning: one rank-up notice")
    check(text:find("Kiezgröße", 1, true), "returning: final rank announced")
    check(not text:find("„Stammkunde“", 1, true), "returning: no intermediate rank")
    eq(count(text, "neue Dankeschöns"), 1, "returning: one summary line")
    check(#x.sounds <= 2, "returning: at most two sounds (" .. #x.sounds .. ")")

    -- Sound without text: notices off, sound on.
    x.ns.DB:Set("thanksNotice", false)
    x.ns.DB:Set("thanksSound", true)
    x:ClearChat()
    local sounds = #x.sounds
    peer:Slash("danke " .. world.members[13].name)
    world:Advance(3)
    eq(#x.sounds, sounds + 1, "sound plays with notices off")
    check(not x:ChatText():find("Spätipunkt", 1, true), "no notice text with notices off")
    check(#world.errors == 0, "no Lua errors: " .. table.concat(world.errors, " | "))
end
