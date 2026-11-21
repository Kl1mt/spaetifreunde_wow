-- Core/Codec.lua: compact text codec for addon messages (pure Lua, no WoW API).
-- Format and message types are documented in docs/PROTOCOL.md.
--
-- Why plain text and not C_EncodingUtil (CBOR/compression/base64)? Our entries are
-- tiny, the text form is deterministic on every client (needed for the summary
-- hashes and for comparing DAYS parts), easy to debug, and works even if the
-- encoding API differs between client builds. C_EncodingUtil stays an option for a
-- future protocol version.
local _, ns = ...

local Codec = {}
ns.Codec = Codec

Codec.PROTOCOL = 1
Codec.MAX_LEN = 255 -- addon message limit in bytes
Codec.FIELD_SEP = "~"
Codec.LIST_SEP = ","
Codec.SUB_SEP = ":"

local floor = math.floor
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

-- Non-negative integer -> base36 string.
function Codec.ToBase36(n)
    n = floor(tonumber(n) or 0)
    if n <= 0 then
        return "0"
    end
    local out = {}
    while n > 0 do
        local r = n % 36
        out[#out + 1] = DIGITS:sub(r + 1, r + 1)
        n = floor(n / 36)
    end
    return string.reverse(table.concat(out))
end

-- base36 string -> integer, or nil for anything that isn't [0-9a-z]+.
function Codec.FromBase36(s)
    if type(s) ~= "string" or s == "" or #s > 10 or s:find("[^0-9a-z]") then
        return nil
    end
    return tonumber(s, 36)
end

-- 32-bit string hash (djb2). Pure arithmetic, identical on every client.
function Codec.Hash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return h
end

-- "Player-6949-0A1B2C3D" <-> "6949-0A1B2C3D" (saves 7 bytes per GUID on the wire).
function Codec.ShortGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local short = guid:match("^Player%-(%d+%-%x+)$")
    return short
end

function Codec.LongGUID(short)
    if type(short) ~= "string" or not short:match("^%d+%-%x+$") then
        return nil
    end
    return "Player-" .. short
end

function Codec.IsGUID(guid)
    return Codec.ShortGUID(guid) ~= nil
end

-- Entry ids: "<last 6 hex of author GUID>.<time36>.<rand36>", e.g. "a1b2c3.t5k2ab.x3f".
local ID_PATTERN = "^[0-9a-z]+%.[0-9a-z]+%.[0-9a-z]+$"

function Codec.IsId(id)
    return type(id) == "string" and #id <= 32 and id:match(ID_PATTERN) ~= nil
end

function Codec.MakeId(authorGuid, t, rand)
    local hex = (authorGuid or ""):match("(%x+)$") or "0"
    hex = hex:lower():sub(-6)
    return hex .. "." .. Codec.ToBase36(t) .. "." .. Codec.ToBase36(rand)
end

---------------------------------------------------------------------------
-- Entries
--   Thank: { k = "T", a = giverGUID,   b = receiverGUID, t = serverTime }
--   Void:  { k = "V", a = officerGUID, b = targetId,     t = serverTime }
-- Wire: "T:<id>:<giverShort>:<receiverShort>:<t36>" / "V:<id>:<officerShort>:<targetId>:<t36>"
---------------------------------------------------------------------------
function Codec.EncodeEntry(id, e)
    local a = Codec.ShortGUID(e.a)
    local b
    if e.k == "T" then
        b = Codec.ShortGUID(e.b)
    elseif e.k == "V" then
        b = e.b
    end
    if not (a and b and Codec.IsId(id)) then
        return nil
    end
    return table.concat({ e.k, id, a, b, Codec.ToBase36(e.t) }, ":")
end

-- Returns id, entry; or nil for malformed input or unknown kinds (future versions).
function Codec.DecodeEntry(s)
    if type(s) ~= "string" then
        return nil
    end
    local k, id, a, b, t36 = s:match("^(%u):([^:]+):([^:]+):([^:]+):([^:]+)")
    if not k or not Codec.IsId(id) then
        return nil
    end
    local t = Codec.FromBase36(t36)
    local giver = Codec.LongGUID(a)
    if not (t and giver) then
        return nil
    end
    if k == "T" then
        local receiver = Codec.LongGUID(b)
        if not receiver then
            return nil
        end
        return id, { k = "T", a = giver, b = receiver, t = t }
    elseif k == "V" then
        if not Codec.IsId(b) then
            return nil
        end
        return id, { k = "V", a = giver, b = b, t = t }
    end
    return nil
end

---------------------------------------------------------------------------
-- Messages: "<proto>~<type>~<field>~<field>..."
---------------------------------------------------------------------------
function Codec.Build(msgType, ...)
    local parts = { tostring(Codec.PROTOCOL), msgType }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    return table.concat(parts, Codec.FIELD_SEP)
end

-- Plain (non-pattern) split that keeps empty fields.
local function split(s, sep)
    local out, pos = {}, 1
    while true do
        local i = s:find(sep, pos, true)
        if not i then
            out[#out + 1] = s:sub(pos)
            return out
        end
        out[#out + 1] = s:sub(pos, i - 1)
        pos = i + #sep
    end
end
Codec.Split = split

-- Returns proto (number), type (string), fields (array); or nil for garbage.
function Codec.Parse(msg)
    if type(msg) ~= "string" or msg == "" or #msg > Codec.MAX_LEN then
        return nil
    end
    local fields = split(msg, Codec.FIELD_SEP)
    local proto = tonumber(fields[1])
    local msgType = fields[2]
    if not proto or not msgType or not msgType:match("^%u$") then
        return nil
    end
    local rest = {}
    for i = 3, #fields do
        rest[#rest + 1] = fields[i]
    end
    return proto, msgType, rest
end

-- Pack items into as few messages as possible: header .. FIELD_SEP .. item,item,...
-- Each resulting message is <= MAX_LEN bytes. Items that can never fit are skipped.
function Codec.Pack(header, items)
    local out = {}
    local budget = Codec.MAX_LEN - #header - #Codec.FIELD_SEP
    local current, size = {}, 0
    for _, item in ipairs(items) do
        local add = #item + (#current > 0 and 1 or 0)
        if #item <= budget then
            if size + add > budget then
                out[#out + 1] = header .. Codec.FIELD_SEP .. table.concat(current, Codec.LIST_SEP)
                current, size = {}, 0
                add = #item
            end
            current[#current + 1] = item
            size = size + add
        end
    end
    if #current > 0 then
        out[#out + 1] = header .. Codec.FIELD_SEP .. table.concat(current, Codec.LIST_SEP)
    end
    return out
end

-- Pack range-keyed summary items. `slots` is an ordered array of keys (e.g. months
-- or days); `itemFor(key)` returns the item string or nil for an empty slot.
-- Every message names the slot range it covers: header~<from>~<to>~item,item
-- Slots inside the range but missing from the list mean "empty" (count 0).
-- Deterministic: the same data always yields the same messages.
function Codec.PackRanges(header, slots, itemFor)
    local out = {}
    local i, n = 1, #slots
    while i <= n do
        local from = slots[i]
        local items, size = {}, 0
        local to = from
        local j = i
        while j <= n do
            local key = slots[j]
            local item = itemFor(key)
            local add = item and (#item + (#items > 0 and 1 or 0)) or 0
            local fixed = #header + 3 * #Codec.FIELD_SEP + #tostring(from) + #tostring(key)
            if item and fixed + size + add > Codec.MAX_LEN and #items > 0 then
                break
            end
            if item then
                items[#items + 1] = item
                size = size + add
            end
            to = key
            j = j + 1
        end
        out[#out + 1] = table.concat({ header, tostring(from), tostring(to),
            table.concat(items, Codec.LIST_SEP) }, Codec.FIELD_SEP)
        i = j
    end
    return out
end
