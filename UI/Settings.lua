-- UI/Settings.lua: options in the game's Settings panel (guarded) + shared option list.
local _, ns = ...

local L = ns.L

-- Shared by the Settings panel and the checkboxes in the Info tab.
ns.SettingsList = {
    { key = "loginGreeting", label = "OPT_LOGIN", tooltip = "OPT_LOGIN_TT" },
    { key = "onlineGreeting", label = "OPT_ONLINE", tooltip = "OPT_ONLINE_TT" },
    { key = "greetInInstances", label = "OPT_INSTANCE", tooltip = "OPT_INSTANCE_TT" },
    { key = "showMinimap", label = "OPT_MINIMAP", tooltip = "OPT_MINIMAP_TT" },
    { key = "thanksNotice", label = "OPT_THANKS", tooltip = "OPT_THANKS_TT" },
    { key = "thanksSound", label = "OPT_THANKS_SOUND", tooltip = "OPT_THANKS_SOUND_TT" },
}

local category
local settingObjects = {} -- key -> Settings setting object

-- VERIFY IN-GAME: Settings API (11.x signatures) on Forever 1.60.1.
local function register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
        and Settings.RegisterAddOnCategory) then
        return
    end
    local createCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
    if not createCheckbox then
        return
    end
    local ok, err = pcall(function()
        local cat = Settings.RegisterVerticalLayoutCategory(L.ADDON_NAME)
        local varType = (Settings.VarType and Settings.VarType.Boolean) or "boolean"
        local store = ns.DB.data.settings
        for _, opt in ipairs(ns.SettingsList) do
            local setting = Settings.RegisterAddOnSetting(cat, "SpaetiFreunde_" .. opt.key, opt.key,
                store, varType, L[opt.label], ns.DB.defaults.settings[opt.key])
            settingObjects[opt.key] = setting
            if setting and setting.SetValueChangedCallback then
                setting:SetValueChangedCallback(function(_, value)
                    ns.DB:Set(opt.key, value and true or false)
                end)
            end
            createCheckbox(cat, setting, L[opt.tooltip])
        end
        Settings.RegisterAddOnCategory(cat)
        category = cat
    end)
    if not ok then
        ns.settingsError = tostring(err)
    end
end

ns:On("SF_DB_READY", register)

-- Change a setting from our own UI. Goes through the Settings object when there is
-- one, so an open options panel updates too; its callback then calls DB:Set.
function ns.SetSetting(key, value)
    local setting = settingObjects[key]
    if setting and setting.SetValue then
        local ok = pcall(setting.SetValue, setting, value)
        if ok then
            -- DB:Set is idempotent; makes sure the DB is right even if no callback fired.
            ns.DB:Set(key, value)
            return
        end
    end
    ns.DB:Set(key, value)
end

function ns.HasSettingsPanel()
    return category ~= nil
end

-- Opens our settings category, or falls back to the Info tab of the main window.
function ns.OpenSettings()
    if category and Settings.OpenToCategory then
        local id = category.GetID and category:GetID() or category.ID
        local ok = pcall(Settings.OpenToCategory, id)
        if ok then
            return
        end
    end
    ns.Print(L.SETTINGS_UNAVAILABLE)
    ns.UI.Toggle(ns.UI.TAB_INFO)
end
