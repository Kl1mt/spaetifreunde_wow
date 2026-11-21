-- Core/DB.lua: SavedVariables (SpaetiFreundeDB) with defaults, schema version, migrations.
local _, ns = ...

local DB = {}
ns.DB = DB

DB.defaults = {
    settings = {
        loginGreeting = true,
        onlineGreeting = true,
        greetInInstances = false,
        showMinimap = true,
    },
    minimap = { angle = 200 },
    window = {}, -- point, relativePoint, x, y
    guilds = {}, -- per-guild data (S3+), keyed by guild key
}

-- migrations[n] upgrades a table from schema n-1 to schema n.
-- Each migration receives a *copy* of the data; it is only committed if all succeed.
DB.migrations = {
    [1] = function(_)
        -- 0 -> 1: first schema; nothing to convert yet.
    end,
}

local function deepCopy(v)
    if type(v) ~= "table" then
        return v
    end
    local out = {}
    for k, val in pairs(v) do
        out[k] = deepCopy(val)
    end
    return out
end
DB.DeepCopy = deepCopy

-- Fill missing keys from defaults (never overwrites existing values).
local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = deepCopy(v)
        elseif type(v) == "table" and type(target[k]) == "table" then
            applyDefaults(target[k], v)
        end
    end
end

local function migrate(data)
    local from = tonumber(data.schema) or 0
    local work = deepCopy(data)
    for version = from + 1, ns.SCHEMA_VERSION do
        local fn = DB.migrations[version]
        if fn then
            fn(work)
        end
        work.schema = version
    end
    return work
end

function DB:Init()
    if type(SpaetiFreundeDB) ~= "table" then
        SpaetiFreundeDB = { schema = ns.SCHEMA_VERSION }
    end
    local saved = SpaetiFreundeDB
    local schema = tonumber(saved.schema) or 0
    self.readOnly = false

    if schema > ns.SCHEMA_VERSION then
        -- Data from a newer addon version: don't touch it, work on a copy.
        self.readOnly = true
        self.data = deepCopy(saved)
        ns.Print(ns.L.DB_NEWER_SCHEMA)
    elseif schema < ns.SCHEMA_VERSION then
        local ok, result = pcall(migrate, saved)
        if ok then
            SpaetiFreundeDB = result
            self.data = result
        else
            -- Keep the original untouched; run this session on a throwaway copy.
            self.readOnly = true
            self.data = deepCopy(saved)
            self.migrationError = tostring(result)
            ns.Print(ns.L.DB_MIGRATION_FAILED)
        end
    else
        self.data = saved
    end

    applyDefaults(self.data, self.defaults)
    self.data.schema = self.data.schema or ns.SCHEMA_VERSION
end

function DB:Get(key)
    return self.data and self.data.settings[key]
end

function DB:Set(key, value)
    if not self.data then
        return
    end
    self.data.settings[key] = value
    ns:Fire("SF_SETTING_CHANGED", key, value)
end
