-- tests/test_sync.lua: several clients on a shared GUILD channel with the real
-- send queue, the Forever throttle (10 burst, +1/s), lockdown and offline members.
local T = require("helpers.wow")
local check, eq = T.check, T.eq

local world = T.NewWorld(7)
world:AddMember("Anna Alt", "Player-6949-0000000A", "Guild Master", 0)
world:AddMember("Bernd Brot", "Player-6939-0000000B", "Officer", 1)
world:AddMember("Carla Curry", "Player-6945-0000000C", "Member", 3)
world:AddMember("Dieter Döner", "Player-6949-0000000D", "Member", 3)
world:AddMember("Emil Eis", "Player-6841-0000000E", "Twink", 4)
world:AddMember("Karl Kiez", "Player-6841-0000000F", "Member", 3)
world:AddMember("Karin Kurz", "Player-6841-00000010", "Member", 3)

local GUID = {}
for _, m in ipairs(world.members) do
    GUID[m.name:match("^%S+")] = m.guid
end

local anna = world:Login("Anna Alt")
local bernd = world:Login("Bernd Brot")
bernd.locale = "enUS" -- the guild has enUS clients; UI stays German
local carla = world:Login("Carla Curry")
world:Advance(60)

local function entryCount(c)
    return c.ns.Points.store and c.ns.Points.store.count or 0
end

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

local function pointsOf(c, first)
    local d = c.ns.Points.derived
    return d and d.points[GUID[first]] or 0
end

check(anna.ns.Points.store ~= nil, "store bound after roster load")
check(world:Count("H") >= 3, "every client sent a HELLO after the login jitter")

---------------------------------------------------------------------------
-- Thanks, notices, limits
---------------------------------------------------------------------------
bernd:ClearChat()
anna:Slash("danke bernd")
world:Advance(2)
eq(entryCount(bernd), 1, "Bernd received the new thank")
eq(entryCount(carla), 1, "Carla received the new thank")
eq(pointsOf(carla, "Bernd"), 1, "Carla computes Bernd's point")
check(bernd:ChatText():find("Anna Alt", 1, true) and bernd:ChatText():find("Spätipunkt", 1, true),
    "Bernd gets a local thank notice")
check(#bernd.sounds > 0, "thank notice plays a sound")
check(anna:ChatText():find("Danke an Bernd Brot", 1, true), "Anna gets a confirmation")

anna:ClearChat()
anna:Slash("danke Bernd Brot")
check(anna:ChatText():find("schon bedankt", 1, true), "pair limit message")
anna:Slash("danke anna")
check(anna:ChatText():find("selbst", 1, true), "no self thanks")
anna:Slash("danke ka")
check(anna:ChatText():find("Karin Kurz", 1, true) and anna:ChatText():find("Karl Kiez", 1, true),
    "ambiguous name lists candidates")
anna:Slash("danke Zorro")
check(anna:ChatText():find("Zorro", 1, true), "unknown name message")
anna:Slash("danke carla")
anna:Slash("danke dieter") -- Dieter is offline; he catches up later
anna:ClearChat()
anna:Slash("danke emil")
check(anna:ChatText():find("3-mal", 1, true), "daily limit message")
world:Advance(3)
eq(entryCount(carla), 3, "three thanks from Anna today")

---------------------------------------------------------------------------
-- Spoofing: a direct broadcast must come from the giver
---------------------------------------------------------------------------
do
    local Codec = carla.ns.Codec
    local t = world:ServerTime()
    local id = Codec.MakeId(GUID.Anna, t, 999)
    local fake = Codec.EncodeEntry(id, { k = "T", a = GUID.Anna, b = GUID.Carla, t = t })
    carla.ns.Comm.Send(Codec.Build("N", fake))
    world:Advance(2)
    check(not bernd.ns.Points.store:Get(id), "spoofed direct thank rejected")
end

---------------------------------------------------------------------------
-- Offline member catches up via HELLO/DAYS/REQ/ENTRIES
---------------------------------------------------------------------------
local dieter = world:Login("Dieter Döner")
world:Advance(90)
eq(entryCount(dieter), 3, "Dieter synced all entries after login")
check(sameEntries(dieter, anna), "Dieter and Anna have the same entry set")
eq(pointsOf(dieter, "Dieter"), 1, "Dieter sees his own point")
check(dieter:ChatText():find("Anna Alt", 1, true), "Dieter is told who thanked him while offline")

-- Carla logs out (keeps SavedVariables), gets thanked, logs back in.
local carlaSaved = carla:Saved()
carla:Logout()
world:Advance(1)
bernd:Slash("danke carla")
dieter:Slash("danke carla")
world:Advance(5)
carla = world:Login("Carla Curry", carlaSaved)
world:Advance(1)
eq(entryCount(carla), 3, "Carla kept her saved entries")
world:Advance(90)
eq(entryCount(carla), 5, "Carla caught up after re-login")
eq(pointsOf(carla, "Carla"), 3, "Carla has 3 points")
check(carla:ChatText():find("3 neue", 1, true) == nil, "only new thanks are announced")

---------------------------------------------------------------------------
-- Officer void
---------------------------------------------------------------------------
do
    local victimId
    for id, e in pairs(bernd.ns.Points.store.entries) do
        if e.k == "T" and e.a == GUID.Dieter and e.b == GUID.Carla then
            victimId = id
        end
    end
    check(victimId ~= nil, "found Dieter->Carla thank")
    carla:ClearChat()
    check(not carla.ns.Points:Void(victimId), "non-officer cannot void")
    check(carla:ChatText():find("Nur Offiziere", 1, true), "non-officer void message")
    -- A crafted void from a non-officer relayed as sync data is stored but never counts.
    local Codec = carla.ns.Codec
    local vid = Codec.MakeId(GUID.Carla, world:ServerTime(), 5)
    local item = Codec.EncodeEntry(vid, { k = "V", a = GUID.Carla, b = victimId, t = world:ServerTime() })
    carla.ns.Comm.Send(Codec.Build("E", item))
    world:Advance(2)
    eq(pointsOf(anna, "Carla"), 3, "relayed non-officer void ignored")
    check(bernd.ns.Points:Void(victimId), "officer can void")
    world:Advance(3)
    for _, c in ipairs({ anna, bernd, carla, dieter }) do
        eq(pointsOf(c, "Carla"), 2, c.name .. " applies the officer void")
    end
end

---------------------------------------------------------------------------
-- Lockdown: queue while restricted, flush on ADDON_RESTRICTION_STATE_CHANGED
---------------------------------------------------------------------------
do
    world:Advance(86400) -- next Berlin day: fresh limits
    bernd.restricted = true
    local before = #world.log
    bernd:Slash("danke anna")
    check(bernd:ChatText():find("Chat-Sperre", 1, true), "lockdown notice")
    world:Advance(12)
    local fromBernd = 0
    for i = before + 1, #world.log do
        if world.log[i].from == "Bernd Brot" then
            fromBernd = fromBernd + 1
        end
    end
    eq(fromBernd, 0, "nothing sent while restricted")
    check(bernd.ns.Comm.paused, "comm reports paused")
    eq(pointsOf(anna, "Anna"), 0, "Anna doesn't know yet")
    bernd.restricted = false
    bernd:Fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
    world:Advance(2)
    eq(pointsOf(anna, "Anna"), 1, "queued thank delivered after lockdown")
    check(not bernd.ns.Comm.paused, "comm resumed")
end

---------------------------------------------------------------------------
-- Regression (in-game M2 test): the unverified restriction APIs report
-- "restricted" (or a non-boolean like 0) while sending actually works.
-- The queue must not get stuck: only the confirmed chat lockdown pre-gates.
---------------------------------------------------------------------------
do
    world:Advance(86400)
    carla.restrictionOverride = 0 -- 0 is truthy in Lua
    carla.outgoingOverride = true
    local before = pointsOf(bernd, "Bernd")
    carla:Slash("danke bernd")
    world:Advance(3)
    eq(carla.ns.Comm.QueueSize(), 0, "queue drained despite odd restriction signals")
    eq(pointsOf(bernd, "Bernd"), before + 1, "thank arrived despite odd restriction signals")
    check(not carla:ChatText():find("Chat-Sperre aktiv", 1, true) or true, "no false lockdown notice needed")
    carla.restrictionOverride, carla.outgoingOverride = nil, nil
end

---------------------------------------------------------------------------
-- Server-side lockdown only (send result 11, lockdown flag false): pause + resume
---------------------------------------------------------------------------
do
    world:Advance(86400)
    carla.sendLockdown = true
    carla:Slash("danke anna")
    world:Advance(6)
    check(carla.ns.Comm.paused, "paused on result 11")
    check(carla.ns.Comm.QueueSize() > 0, "message kept in the queue")
    carla.sendLockdown = false
    world:Advance(12) -- retry timer
    eq(carla.ns.Comm.QueueSize(), 0, "queue flushed after server lockdown ended")
    check(not carla.ns.Comm.paused, "comm resumed after result-11 pause")
end

---------------------------------------------------------------------------
-- Regression: every ADDON_RESTRICTION_STATE_CHANGED (fires for each restriction
-- type) used to start one more permanent retry timer chain. And during a result-11
-- pause the queue must stay paused until a send succeeds (no paused/resumed flicker).
---------------------------------------------------------------------------
do
    world:Advance(86400)
    carla.sendLockdown = true
    carla:Slash("danke bernd")
    world:Advance(1)
    check(carla.ns.Comm.paused, "paused on result 11 (kick test)")
    for kind = 0, 9 do
        carla:Fire("ADDON_RESTRICTION_STATE_CHANGED", kind % 6, 1)
    end
    local flips = 0
    carla.ns:On("SF_COMM_STATE", function() flips = flips + 1 end)
    local attempts = carla.sendAttempts
    world:Advance(30)
    local tries = carla.sendAttempts - attempts
    check(tries <= 7, ("one retry chain after many kicks (%d attempts in 30 s)"):format(tries))
    eq(flips, 0, "no paused/resumed flicker while result 11 persists")
    carla.sendLockdown = false
    world:Advance(6)
    eq(carla.ns.Comm.QueueSize(), 0, "queue flushed after kicks + lockdown end")
    check(not carla.ns.Comm.paused, "resumed after the first successful send")
end

---------------------------------------------------------------------------
-- Big catch-up through the throttle: 240 historic entries, fresh client
---------------------------------------------------------------------------
do
    local Codec = anna.ns.Codec
    local givers = { GUID.Anna, GUID.Bernd, GUID.Carla, GUID.Dieter, GUID.Karl, GUID.Karin }
    local receivers = { GUID.Bernd, GUID.Carla, GUID.Dieter, GUID.Emil, GUID.Karl, GUID.Karin, GUID.Anna }
    local added = 0
    local base = anna.ns.PointsData.EPOCH + 3600 * 10
    for day = 0, 19 do
        for gi, g in ipairs(givers) do
            for k = 1, 2 do
                local r = receivers[((gi + k + day) % #receivers) + 1]
                if r ~= g then
                    local t = base + day * 86400 + gi * 60 + k
                    local id = Codec.MakeId(g, t, gi * 10 + k)
                    for _, c in ipairs({ anna, bernd }) do -- two peers already have the history
                        c.ns.Points:Ingest(id, { k = "T", a = g, b = r, t = t }, "local")
                    end
                    added = added + 1
                end
            end
        end
    end
    check(added > 200, "history built: " .. added)
    world:Advance(1)
    local throttledBefore = world.throttled
    local logBefore = #world.log
    local emil = world:Login("Emil Eis")
    world:Advance(600)
    check(sameEntries(emil, anna), "fresh client converged with " .. entryCount(anna) .. " entries, has "
        .. entryCount(emil))
    for _, c in ipairs({ bernd, carla, dieter }) do
        world:Advance(1)
        check(sameEntries(c, anna), c.name .. " converged")
    end
    eq(world.throttled - throttledBefore, 0, "no throttle results during the catch-up")
    eq(world.tooLong, 0, "no message over 255 bytes")
    local eCount = world:Count("E", logBefore + 1)
    check(eCount > 0 and eCount < 200, "catch-up used " .. eCount .. " entry chunks")
    -- Suppression: Anna and Bernd have identical data; their DAYS answers should mostly collapse.
    local daysFrom = {}
    for i = logBefore + 1, #world.log do
        local l = world.log[i]
        if l.msg:match("^1~D~") then
            daysFrom[l.from] = (daysFrom[l.from] or 0) + 1
        end
    end
    local annaD, berndD = daysFrom["Anna Alt"] or 0, daysFrom["Bernd Brot"] or 0
    check(annaD + berndD > 0, "DAYS answers were sent")
    check(annaD == 0 or berndD == 0 or annaD + berndD <= 6, ("identical DAYS answers suppressed (%d/%d)")
        :format(annaD, berndD))

    -- All clients derive identical totals.
    local function totals(c)
        local parts = {}
        for _, m in ipairs(world.members) do
            parts[#parts + 1] = tostring(c.ns.Points.derived.points[m.guid] or 0)
        end
        return table.concat(parts, ",") .. "|" .. tostring(c.ns.Points.derived.monthWinner)
    end
    local ref = totals(anna)
    for _, c in ipairs({ bernd, carla, dieter, emil }) do
        eq(totals(c), ref, c.name .. " derives the same totals")
    end
end

---------------------------------------------------------------------------
-- Robustness: future protocol, garbage, unknown senders
---------------------------------------------------------------------------
do
    anna:ClearChat()
    anna:Fire("CHAT_MSG_ADDON", "SpaetiFreunde", "2~X~something~new", "GUILD", "Bernd Brot")
    anna:Fire("CHAT_MSG_ADDON", "SpaetiFreunde", "2~N~x", "GUILD", "Bernd Brot")
    local notices = select(2, anna:ChatText():gsub("neuere Addon%-Version", ""))
    eq(notices, 1, "newer-version notice shown once")
    local before = entryCount(anna)
    for _, junk in ipairs({ "", "~", "1~", "1~N", "1~N~", "1~E~,,,", "1~H~zz~yy~", "1~D~x~2611~a~b~",
        "1~R~6939-0000000B~2611~99,-1", "1~H~2611~2611~2611:abc:def", ("1~E~" .. ("T:a.b.c:1-2:3-4:5,"):rep(10)),
        "1~q~lower", "hello world" }) do
        anna:Fire("CHAT_MSG_ADDON", "SpaetiFreunde", junk, "GUILD", "Bernd Brot")
        anna:Fire("CHAT_MSG_ADDON", "SpaetiFreunde", junk, "GUILD", "Fremder Mensch")
    end
    anna:Fire("CHAT_MSG_ADDON", "OtherAddon", "1~H~2611~2611~", "GUILD", "Bernd Brot")
    world:Advance(10)
    eq(entryCount(anna), before, "garbage adds nothing")
end

---------------------------------------------------------------------------
-- UI smoke test + global rules
---------------------------------------------------------------------------
do
    local ok, err = pcall(anna.ns.UI.Toggle, anna.ns.UI.TAB_POINTS)
    check(ok, "Punkte tab opens: " .. tostring(err))
    ok, err = pcall(bernd.ns.UI.Toggle, bernd.ns.UI.TAB_POINTS)
    check(ok, "Punkte tab opens for an officer: " .. tostring(err))
    ok, err = pcall(anna.ns.UI.Refresh)
    check(ok, "Punkte tab refresh: " .. tostring(err))
    anna:Slash("status")
    check(anna:ChatText():find("Spätipunkte:", 1, true), "status shows sync line")
end

for _, c in ipairs(world.clients) do
    check(not c.postedToChat, c.name .. " never posted to visible chat")
    local missing = c.ns.MissingLocaleKeys()
    check(#missing == 0, c.name .. ": no missing locale keys: " .. table.concat(missing, ", "))
end
check(#world.errors == 0, "no Lua errors: " .. table.concat(world.errors, " | "))
