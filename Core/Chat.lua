-- Core/Chat.lua: chat lockdown check.
-- The addon never posts to guild, say or yell chat (guild decision); everything
-- it shows appears only in your own chat frame. Lockdown state is still needed
-- for /spaeti status and, later, for addon-message sync (Spätipunkte).
local _, ns = ...

local Chat = {}
ns.Chat = Chat

-- true / false / nil (= API not available).
-- VERIFY IN-GAME: C_ChatInfo.InChatMessagingLockdown exists on Forever.
function Chat.IsLockedDown()
    if C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function" then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and not (ns.Util.IsSecret and ns.Util.IsSecret(locked)) then
            return locked == true
        end
    end
    return nil
end
