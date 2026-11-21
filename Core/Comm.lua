-- Core/Comm.lua: hidden addon messages on GUILD (prefix "SpaetiFreunde").
-- Own send queue with a token bucket (burst budget 10 per prefix on Forever, then
-- result 3 = AddonMessageThrottle; we stay below it), paused while chat/addon
-- messages are restricted. Never sends to visible chat.
local _, ns = ...

local Util = ns.Util
local Comm = {}
ns.Comm = Comm

Comm.PREFIX = "SpaetiFreunde"
Comm.BURST = 8 -- tokens (server allows 10; keep 2 spare)
Comm.RATE = 1 -- tokens per second
Comm.PUMP_INTERVAL = 0.25
Comm.PAUSE_RETRY = 5 -- seconds between checks while restricted

local RESULT_SUCCESS = 0
local RESULT_THROTTLE = 3
local RESULT_LOCKDOWN = 11

Comm.high = {} -- small control messages (new thanks, HELLO, DAYS, REQ)
Comm.bulk = {} -- sync entry chunks
Comm.handlers = {} -- msgType -> fn(senderGuid, fields, proto, rawText)
Comm.stats = { sent = 0, received = 0, throttled = 0, dropped = 0 }
Comm.paused = false
Comm.bulkQueued = 0 -- bulk messages ever queued (tickets)
Comm.bulkDone = 0 -- bulk messages sent or dropped

local tokens = Comm.BURST
local lastRefill
local pumpScheduled = false

local function now()
    return GetTime and GetTime() or 0
end

-- Is sending addon messages restricted right now? Every check is guarded:
-- a missing API counts as "not restricted".
-- VERIFY IN-GAME: lockdown inside dungeons/boss fights is still unconfirmed.
function Comm.IsRestricted()
    if ns.Chat.IsLockedDown() then
        return true
    end
    if C_ChatInfo and type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) == "function" then
        local ok, restricted = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
        if ok and restricted then
            return true
        end
    end
    if C_RestrictedActions and type(C_RestrictedActions.IsAddOnRestrictionActive) == "function"
        and Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Chat then
        local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, Enum.AddOnRestrictionType.Chat)
        if ok and active then
            return true
        end
    end
    return false
end

function Comm.QueueSize()
    return #Comm.high + #Comm.bulk
end

local function refill()
    local t = now()
    if lastRefill then
        tokens = math.min(Comm.BURST, tokens + (t - lastRefill) * Comm.RATE)
    end
    lastRefill = t
end

local function rawSend(msg)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then
        return "drop"
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Comm.PREFIX, msg, "GUILD")
    if not ok then
        return "drop"
    end
    -- Older clients return a boolean, newer ones an Enum.SendAddonMessageResult.
    if result == nil or result == true or result == RESULT_SUCCESS then
        return "ok"
    elseif result == RESULT_THROTTLE then
        return "throttle"
    elseif result == RESULT_LOCKDOWN then
        return "lockdown"
    end
    return "drop"
end

local schedulePump

local function pump()
    pumpScheduled = false
    if Comm.QueueSize() == 0 then
        return
    end
    if not (IsInGuild and IsInGuild()) then
        Comm.bulkDone = Comm.bulkQueued
        Comm.high, Comm.bulk = {}, {}
        return
    end
    if Comm.IsRestricted() then
        if not Comm.paused then
            Comm.paused = true
            ns:Fire("SF_COMM_STATE")
        end
        schedulePump(Comm.PAUSE_RETRY)
        return
    end
    if Comm.paused then
        Comm.paused = false
        ns:Fire("SF_COMM_STATE")
    end
    refill()
    while tokens >= 1 and Comm.QueueSize() > 0 do
        local queue = (#Comm.high > 0) and Comm.high or Comm.bulk
        local result = rawSend(queue[1])
        local isBulk = queue == Comm.bulk
        if result == "ok" then
            table.remove(queue, 1)
            if isBulk then
                Comm.bulkDone = Comm.bulkDone + 1
            end
            tokens = tokens - 1
            Comm.stats.sent = Comm.stats.sent + 1
        elseif result == "throttle" then
            Comm.stats.throttled = Comm.stats.throttled + 1
            tokens = 0
            break
        elseif result == "lockdown" then
            Comm.paused = true
            ns:Fire("SF_COMM_STATE")
            schedulePump(Comm.PAUSE_RETRY)
            return
        else
            table.remove(queue, 1)
            Comm.stats.dropped = Comm.stats.dropped + 1
            if isBulk then
                Comm.bulkDone = Comm.bulkDone + 1
            end
        end
    end
    if Comm.QueueSize() > 0 then
        local wait = math.max(Comm.PUMP_INTERVAL, (1 - tokens) / Comm.RATE)
        schedulePump(wait)
    end
end

function schedulePump(delay)
    if pumpScheduled then
        return
    end
    pumpScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, pump)
    else
        pump()
    end
end

-- Queue a message. bulk = true for sync data (sent after control messages).
-- For bulk messages returns a ticket; Comm.IsPending(ticket) is true until it left.
function Comm.Send(msg, bulk)
    if type(msg) ~= "string" or #msg > 255 then
        Comm.stats.dropped = Comm.stats.dropped + 1
        return nil
    end
    local ticket
    if bulk then
        Comm.bulk[#Comm.bulk + 1] = msg
        Comm.bulkQueued = Comm.bulkQueued + 1
        ticket = Comm.bulkQueued
    else
        Comm.high[#Comm.high + 1] = msg
    end
    schedulePump(0)
    return ticket
end

function Comm.IsPending(ticket)
    return ticket ~= nil and Comm.bulkDone < ticket
end

function Comm.Register(msgType, fn)
    Comm.handlers[msgType] = fn
end

---------------------------------------------------------------------------
-- Receive
---------------------------------------------------------------------------
local newerNoticeShown = false

function Comm.OnAddonMessage(prefix, text, channel, sender)
    prefix = Util.SafeText(prefix)
    if prefix ~= Comm.PREFIX or Util.SafeText(channel) ~= "GUILD" then
        return
    end
    text = Util.SafeText(text)
    sender = Util.SafeText(sender)
    if not text or not sender then
        return
    end
    -- Sender is "Vorname Nachname" = roster name (confirmed). Unknown senders are ignored.
    local guid = ns.Roster:GuidByName(sender)
    if not guid or guid == ns.Roster:MyGUID() then
        return -- not in our roster cache, or our own echo
    end
    local proto, msgType, fields = ns.Codec.Parse(text)
    if not proto then
        return
    end
    if proto > ns.Codec.PROTOCOL then
        if not newerNoticeShown then
            newerNoticeShown = true
            ns.Print(ns.L.SYNC_NEWER_VERSION)
        end
        return
    end
    Comm.stats.received = Comm.stats.received + 1
    local fn = Comm.handlers[msgType]
    if fn then
        fn(guid, fields, proto, text)
    end
end

ns:RegisterEvent("CHAT_MSG_ADDON", function(_, ...)
    Comm.OnAddonMessage(...)
end)

-- VERIFY IN-GAME: payload of ADDON_RESTRICTION_STATE_CHANGED; we only use it as a wake-up.
-- Pump right away (don't wait for the pending retry timer); a stale timer firing
-- later just runs one extra, harmless pump.
function Comm.Kick()
    if Comm.QueueSize() > 0 then
        pump()
    end
end

local okEvent = pcall(ns.RegisterEvent, ns, "ADDON_RESTRICTION_STATE_CHANGED", function()
    Comm.Kick()
end)
Comm.hasRestrictionEvent = okEvent

-- Register the prefix as early as possible (confirmed: result 0 = Success).
if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Comm.PREFIX)
    Comm.prefixResult = ok and result or "error"
end
