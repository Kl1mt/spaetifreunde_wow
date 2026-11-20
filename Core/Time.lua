-- Core/Time.lua: Berlin local date from a UTC epoch (EU DST rule).
-- Pure Lua, no WoW API except GetServerTime() as default clock.
local _, ns = ...

local Time = {}
ns.Time = Time

local floor = math.floor

-- Days since 1970-01-01 -> y, m, d (proleptic Gregorian, H. Hinnant's algorithm).
local function civilFromDays(z)
    z = z + 719468
    local era = floor(z / 146097)
    local doe = z - era * 146097
    local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
    local mp = floor((5 * doy + 2) / 153)
    local d = doy - floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then
        y = y + 1
    end
    return y, m, d
end

-- y, m, d -> days since 1970-01-01.
local function daysFromCivil(y, m, d)
    if m <= 2 then
        y = y - 1
    end
    local era = floor(y / 400)
    local yoe = y - era * 400
    local mp = m > 2 and m - 3 or m + 9
    local doy = floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end
Time.DaysFromCivil = daysFromCivil

-- Weekday 1=Monday .. 7=Sunday for a day number.
local function weekday(days)
    return (days + 3) % 7 + 1 -- 1970-01-01 was a Thursday
end

-- UTC epoch of 01:00 UTC on the last Sunday of the given month.
local function lastSundayOneUTC(y, m)
    local nextY, nextM = y, m + 1
    if nextM > 12 then
        nextY, nextM = y + 1, 1
    end
    local lastDay = daysFromCivil(nextY, nextM, 1) - 1
    local sunday = lastDay - (weekday(lastDay) % 7) -- weekday 7 -> offset 0
    return sunday * 86400 + 3600
end

-- CEST (UTC+2) from last Sunday of March 01:00 UTC until last Sunday of October 01:00 UTC.
function Time.IsBerlinDST(utc)
    local y = civilFromDays(floor(utc / 86400))
    return utc >= lastSundayOneUTC(y, 3) and utc < lastSundayOneUTC(y, 10)
end

-- Returns a table with Berlin local date parts and keys for daily/monthly resets.
function Time.BerlinDate(utc)
    utc = utc or (GetServerTime and GetServerTime()) or 0
    local dst = Time.IsBerlinDST(utc)
    local localT = utc + (dst and 7200 or 3600)
    local days = floor(localT / 86400)
    local secs = localT - days * 86400
    local y, m, d = civilFromDays(days)
    return {
        year = y,
        month = m,
        day = d,
        hour = floor(secs / 3600),
        min = floor((secs % 3600) / 60),
        wday = weekday(days), -- 1 = Montag
        dst = dst,
        dayNumber = days,
        dayKey = string.format("%04d-%02d-%02d", y, m, d),
        monthKey = string.format("%04d-%02d", y, m),
    }
end

-- Convenience: today's Berlin day key ("2026-11-20").
function Time.BerlinDayKey(utc)
    return Time.BerlinDate(utc).dayKey
end
