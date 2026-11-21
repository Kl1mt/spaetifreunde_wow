-- Modules/Greeting.lua: login greeting + local online notices with click-to-welcome.
-- Nothing here posts automatically; the welcome post only happens on a click/slash.
local ADDON_NAME, ns = ...

local L = ns.L
local Util = ns.Util
local Greeting = {}
ns.Greeting = Greeting

local LOGIN_DELAY = 6 -- seconds, so the line isn't buried under login spam
local MAX_SINGLE_LINES = 3 -- more arrivals at once are summarised in one line
local LINK_TYPE = "welcome"

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
-- Click-to-welcome link
---------------------------------------------------------------------------
-- VERIFY IN-GAME: "addon:" hyperlinks + EventRegistry "SetItemRef" callback on Forever.
local linksSupported = EventRegistry and type(EventRegistry.RegisterCallback) == "function"

local function welcomeLink(guid)
    return ("|cff66ccff|Haddon:%s:%s:%s|h%s|h|r"):format(ADDON_NAME, LINK_TYPE, guid, L.WELCOME_LINK)
end

-- Posts a welcome for guid to guild chat. Must run inside Chat.RunUserAction.
function Greeting.Welcome(guid)
    local entry = guid and ns.Roster:Get(guid)
    if not entry then
        ns.Print(L.WELCOME_NONE)
        return
    end
    if not entry.online then
        ns.Print(L.WELCOME_GONE:format(entry.display))
        return
    end
    local line = Util.RandomPick(L.WELCOME_POSTS)
    ns.Chat.SendGuild(line:format(entry.display))
end

-- Welcome the member who came online most recently (for /spaeti willkommen).
function Greeting.WelcomeLast()
    Greeting.Welcome(ns.Roster.lastOnline)
end

if linksSupported then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link)
        if type(link) ~= "string" then
            return
        end
        local addon, kind, rest = strsplit(":", link, 3)
        -- link = "addon:SpaetiFreunde:welcome:<guid>"
        if addon == "addon" and kind == ADDON_NAME then
            local action, target = strsplit(":", rest or "", 2)
            if action == LINK_TYPE and target then
                -- The hyperlink click is the user action.
                ns.Chat.RunUserAction(Greeting.Welcome, target)
            end
        end
    end, Greeting)
end

---------------------------------------------------------------------------
-- Online notices (local only)
---------------------------------------------------------------------------
ns:On("SF_MEMBERS_ONLINE", function(list)
    if not settingOn("onlineGreeting") or muted() then
        return
    end
    local withLink = linksSupported and settingOn("welcomeLink")
    if #list > MAX_SINGLE_LINES then
        local last = list[#list]
        local text = L.ONLINE_MANY:format((last.display:gsub("|", "||")), #list - 1)
        if withLink then
            text = text .. " " .. welcomeLink(last.guid)
        end
        ns.Print(text)
        return
    end
    for _, entry in ipairs(list) do
        local fmt, idx = Util.RandomPick(L.ONLINE_LINES, lastOnlineLine)
        lastOnlineLine = idx
        -- Escape "|" in names so they can't inject UI codes into our own chat frame.
        local name = entry.display:gsub("|", "||")
        local text = fmt:format(name)
        if withLink then
            text = text .. " " .. welcomeLink(entry.guid)
        end
        ns.Print(text)
    end
end)
