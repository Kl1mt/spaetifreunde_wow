-- Modules/Greeting.lua: login greeting + local online notices.
-- Everything here is shown only in your own chat frame; nothing is posted to guild chat.
local _, ns = ...

local L = ns.L
local Util = ns.Util
local Greeting = {}
ns.Greeting = Greeting

local LOGIN_DELAY = 6 -- seconds, so the line isn't buried under login spam
local MAX_SINGLE_LINES = 3 -- more arrivals at once are summarised in one line

local greetedThisSession = false
local lastOnlineLine

local function settingOn(key)
    return ns.DB:Get(key) and true or false
end

local function muted()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if not settingOn("greetInInstances") and IsInInstance then
        local inInstance = IsInInstance()
        if inInstance then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Login greeting (local only)
---------------------------------------------------------------------------
function Greeting.LoginGreeting()
    if greetedThisSession or not settingOn("loginGreeting") then
        return
    end
    greetedThisSession = true
    local line = Util.RandomPick(L.LOGIN_GREETINGS)
    if line then
        ns.Print(line)
    end
    if not (IsInGuild and IsInGuild()) then
        ns.Print(L.LOGIN_NO_GUILD)
        return
    end
    local roster = ns.Roster
    if roster.ready then
        local others = math.max(0, roster.numOnline - 1)
        if others == 1 then
            ns.Print(L.LOGIN_ONLINE_COUNT_ONE)
        elseif others > 1 then
            ns.Print(L.LOGIN_ONLINE_COUNT:format(others))
        else
            ns.Print(L.LOGIN_ONLINE_ALONE)
        end
    end
end

ns:On("SF_LOGIN", function()
    if C_Timer then
        C_Timer.After(LOGIN_DELAY, Greeting.LoginGreeting)
    else
        Greeting.LoginGreeting()
    end
end)

---------------------------------------------------------------------------
-- Online notices (local only)
---------------------------------------------------------------------------
ns:On("SF_MEMBERS_ONLINE", function(list)
    if not settingOn("onlineGreeting") or muted() then
        return
    end
    if #list > MAX_SINGLE_LINES then
        local last = list[#list]
        local text = L.ONLINE_MANY:format((last.display:gsub("|", "||")), #list - 1)
        ns.Print(text)
        return
    end
    for _, entry in ipairs(list) do
        local fmt, idx = Util.RandomPick(L.ONLINE_LINES, lastOnlineLine)
        lastOnlineLine = idx
        -- Escape "|" in names so they can't inject UI codes into our own chat frame.
        local name = entry.display:gsub("|", "||")
        local text = fmt:format(name)
        ns.Print(text)
    end
end)
