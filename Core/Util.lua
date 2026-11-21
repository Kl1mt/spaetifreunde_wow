-- Core/Util.lua: safe-text helpers for secret values, UTF-8 truncation, random pick.
local _, ns = ...

local Util = {}
ns.Util = Util

-- Midnight/Forever "secret values": must never be compared, concatenated or stored.
-- VERIFY IN-GAME: issecretvalue exists on Forever 1.60.1.
local issecret = type(issecretvalue) == "function" and issecretvalue or nil
Util.HAS_SECRET_API = issecret ~= nil

function Util.IsSecret(v)
    if not issecret then
        return false
    end
    local ok, result = pcall(issecret, v)
    -- If the check itself fails, treat the value as unsafe.
    return (not ok) or (result and true or false)
end

-- Returns a plain string, or nil for secrets / non-text values.
function Util.SafeText(v)
    if v == nil or Util.IsSecret(v) then
        return nil
    end
    local t = type(v)
    if t == "string" then
        return v
    elseif t == "number" then
        return tostring(v)
    end
    return nil
end

-- Truncate to maxBytes without splitting a UTF-8 character.
function Util.TruncateUTF8(s, maxBytes)
    if #s <= maxBytes then
        return s
    end
    local cut = maxBytes
    -- Step back over continuation bytes (10xxxxxx).
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then
            break
        end
        cut = cut - 1
    end
    return s:sub(1, cut)
end

-- Make text safe to send to chat: no secrets, no control bytes,
-- no UI escape sequences ("|" doubled), max 255 bytes.
function Util.SanitizeChat(v, maxBytes)
    local s = Util.SafeText(v)
    if not s then
        return nil
    end
    s = s:gsub("[%z\1-\31\127]", " ")
    s = s:gsub("|", "||")
    s = strtrim and strtrim(s) or s:match("^%s*(.-)%s*$")
    s = Util.TruncateUTF8(s, maxBytes or 255)
    -- Don't leave a dangling single "|" after truncation.
    local pipes = s:match("|*$")
    if pipes and #pipes % 2 == 1 then
        s = s:sub(1, -2)
    end
    if s == "" then
        return nil
    end
    return s
end

-- Lowercase including German umlauts (strlower does not fold ÄÖÜ).
function Util.Lower(s)
    s = s:lower()
    return (s:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end

-- Random element; avoids repeating `last` index when possible.
function Util.RandomPick(list, last)
    local n = #list
    if n == 0 then
        return nil, nil
    end
    local i = math.random(n)
    if n > 1 and i == last then
        i = (i % n) + 1
    end
    return list[i], i
end

-- Short display name: strips a "-Realm" suffix if the client adds one.
-- VERIFY IN-GAME: Forever name format (no realms, surnames).
function Util.DisplayName(name)
    name = Util.SafeText(name)
    if not name then
        return "?"
    end
    if type(Ambiguate) == "function" then
        local ok, short = pcall(Ambiguate, name, "guild")
        if ok and type(short) == "string" and short ~= "" then
            return short
        end
    end
    return name
end
