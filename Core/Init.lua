-- Core/Init.lua: namespace, event dispatcher, internal messages, print helper.
local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.SCHEMA_VERSION = 1

-- Version from TOC metadata (C_AddOns in modern clients, global fallback).
do
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local v = getMeta and getMeta(ADDON_NAME, "Version")
    if not v or v == "" or v:find("@", 1, true) then
        v = "dev"
    end
    ns.VERSION = v
end

-- Call a handler without letting one failing module break the others.
local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        end
    end
end
ns.SafeCall = safeCall

---------------------------------------------------------------------------
-- WoW events: ns:RegisterEvent(event, fn) — several handlers per event.
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns:RegisterEvent(event, fn)
    local list = eventHandlers[event]
    if not list then
        list = {}
        eventHandlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then
        return
    end
    for i = 1, #list do
        safeCall(list[i], event, ...)
    end
end)

---------------------------------------------------------------------------
-- Internal messages: ns:On("SF_MEMBER_ONLINE", fn) / ns:Fire(msg, ...)
--   SF_DB_READY, SF_LOGIN, SF_ROSTER_UPDATED, SF_MEMBER_ONLINE(guid, entry),
--   SF_MEMBER_OFFLINE(guid, entry), SF_SETTING_CHANGED(key, value)
---------------------------------------------------------------------------
local messageHandlers = {}

function ns:On(message, fn)
    local list = messageHandlers[message]
    if not list then
        list = {}
        messageHandlers[message] = list
    end
    list[#list + 1] = fn
end

function ns:Fire(message, ...)
    local list = messageHandlers[message]
    if not list then
        return
    end
    for i = 1, #list do
        safeCall(list[i], ...)
    end
end

---------------------------------------------------------------------------
-- Local output (own chat frame only, never sent to anyone).
---------------------------------------------------------------------------
function ns.Print(text)
    local L = ns.L
    local prefix = L and L.CHAT_PREFIX or "Späti:"
    local frame = DEFAULT_CHAT_FRAME
    if frame then
        frame:AddMessage(prefix .. " " .. tostring(text))
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
ns:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then
        return
    end
    ns.DB:Init()
    ns:Fire("SF_DB_READY")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    ns:Fire("SF_LOGIN")
end)
