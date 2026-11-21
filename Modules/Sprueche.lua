-- Modules/Sprueche.lua: Berlin sayings. Local display only.
local _, ns = ...

local Sprueche = {}
ns.Sprueche = Sprueche

local NO_REPEAT = 5
local recent = {} -- indices of the last shown sayings

function Sprueche.Random()
    local list = ns.L.SPRUECHE
    local n = #list
    if n == 0 then
        return nil
    end
    local avoid = math.min(NO_REPEAT, n - 1)
    local i
    for _ = 1, 20 do
        i = math.random(n)
        local seen = false
        for j = math.max(1, #recent - avoid + 1), #recent do
            if recent[j] == i then
                seen = true
                break
            end
        end
        if not seen then
            break
        end
    end
    recent[#recent + 1] = i
    if #recent > NO_REPEAT then
        table.remove(recent, 1)
    end
    return list[i]
end

-- Prints a saying in the own chat frame.
function Sprueche.ShowLocal()
    local text = Sprueche.Random()
    if text then
        ns.Print(ns.L.SPRUCH_LOCAL:format(text))
    end
end
