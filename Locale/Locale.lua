-- Locale/Locale.lua: string table with missing-key fallback.
-- Only German exists; it is loaded for every client language on purpose.
local _, ns = ...

local missing = {}

ns.L = setmetatable({}, {
    __index = function(_, key)
        if not missing[key] then
            missing[key] = true
            -- Visible but harmless: shows the key so testers can report it.
        end
        return "[" .. tostring(key) .. "]"
    end,
})

-- Missing keys seen this session (for /spaeti status debugging).
function ns.MissingLocaleKeys()
    local list = {}
    for key in pairs(missing) do
        list[#list + 1] = tostring(key)
    end
    table.sort(list)
    return list
end
