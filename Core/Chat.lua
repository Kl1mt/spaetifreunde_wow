-- Core/Chat.lua: the ONLY place that sends chat messages.
-- Rules (Forever/Midnight): guild posts only synchronously from a click or slash
-- handler, never from timers or events; respect chat messaging lockdown.
local _, ns = ...

local Chat = {}
ns.Chat = Chat

local userActionDepth = 0

-- Run fn as a direct user action (OnClick / slash handler). Only inside this
-- wrapper may Chat.SendGuild send anything.
function Chat.RunUserAction(fn, ...)
    userActionDepth = userActionDepth + 1
    local ok, err = pcall(fn, ...)
    userActionDepth = userActionDepth - 1
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        end
    end
end

-- true / false / nil (= API not available).
-- VERIFY IN-GAME: C_ChatInfo.InChatMessagingLockdown exists on Forever.
function Chat.IsLockedDown()
    if C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function" then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok then
            return locked and true or false
        end
    end
    return nil
end

local function resolveSend()
    -- VERIFY IN-GAME: which of the two exists / is allowed on Forever 1.60.1.
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        return C_ChatInfo.SendChatMessage
    end
    if type(SendChatMessage) == "function" then
        return SendChatMessage
    end
    return nil
end

-- Post text to GUILD. Returns true on success; prints a local German notice otherwise.
function Chat.SendGuild(text)
    if userActionDepth <= 0 then
        ns.Print(ns.L.CHAT_NOT_USER_ACTION)
        return false
    end
    if not (IsInGuild and IsInGuild()) then
        ns.Print(ns.L.CHAT_NOT_IN_GUILD)
        return false
    end
    if Chat.IsLockedDown() then
        ns.Print(ns.L.CHAT_LOCKDOWN)
        return false
    end
    local msg = ns.Util.SanitizeChat(text, 255)
    if not msg then
        ns.Print(ns.L.CHAT_EMPTY)
        return false
    end
    local send = resolveSend()
    if not send then
        ns.Print(ns.L.CHAT_UNAVAILABLE)
        return false
    end
    local ok = pcall(send, msg, "GUILD")
    if not ok then
        ns.Print(ns.L.CHAT_FAILED)
        return false
    end
    return true
end
