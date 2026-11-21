-- luacheck config for SpaetiFreunde (WoW: Forever, Lua 5.1)
std = "lua51"
max_line_length = false
codes = true

exclude_files = {
    "tools/",
    "Libs/",
    ".release/",
    "build/",
}

ignore = {
    "212/self", -- unused self in methods
}

-- Globals we write
globals = {
    "SpaetiFreundeDB",
    "SLASH_SPAETI1", "SLASH_SPAETI2",
    "SLASH_SPAETISPRUCH1",
    "SlashCmdList",
    "SpaetiFreunde_OnCompartmentClick",
    "SpaetiFreunde_OnCompartmentEnter",
    "SpaetiFreunde_OnCompartmentLeave",
    "UISpecialFrames",
}

-- WoW API we read (maintained by hand)
read_globals = {
    -- Lua extensions provided by WoW
    "strsplit", "strtrim", "strlower", "strupper", "strjoin", "tinsert", "tremove", "wipe",
    "date", "time", "format",
    -- Frames / UI
    "CreateFrame", "UIParent", "Minimap", "GameTooltip", "DEFAULT_CHAT_FRAME",
    "GameFontNormal", "GameFontHighlight", "GameFontNormalLarge",
    "PlaySound", "SOUNDKIT", "GetCursorPosition",
    "Settings", "AddonCompartmentFrame", "EventRegistry",
    -- Game state
    "GetBuildInfo", "GetLocale", "GetServerTime", "GetTime",
    "InCombatLockdown", "IsInInstance", "IsLoggedIn",
    "UnitGUID", "UnitName", "UnitFullName",
    "C_AddOns", "GetAddOnMetadata",
    "C_Timer", "C_ChatInfo", "SendChatMessage", "C_RestrictedActions", "Enum", "C_Club",
    -- Guild
    "IsInGuild", "GetGuildInfo", "IsGuildLeader", "GetNumGuildMembers", "GetGuildRosterInfo",
    "C_GuildInfo", "GuildRoster", "Ambiguate",
    -- Secret values (Midnight / Forever)
    "issecretvalue",
    "geterrorhandler",
}
