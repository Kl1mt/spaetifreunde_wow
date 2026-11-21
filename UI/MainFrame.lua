-- UI/MainFrame.lua: main window shell with tabs (Start, Punkte, Online, Info).
local _, ns = ...

local L = ns.L
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 440, 330
local frame
local tabs, panels = {}, {}
local refreshers = {}

local function savePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local w = ns.DB.data.window
    w.point, w.relativePoint, w.x, w.y = point, relativePoint, x, y
end

local function restorePosition()
    local w = ns.DB.data.window
    frame:ClearAllPoints()
    if w.point then
        frame:SetPoint(w.point, UIParent, w.relativePoint or w.point, w.x or 0, w.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function newText(parent, font, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if width then
        fs:SetWidth(width)
    end
    return fs
end

local function newButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end
UI.NewButton = newButton

-- Checkbox bound to a DB setting.
local function newCheckbox(parent, key, label, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = newText(cb, "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
        ns.SetSetting(key, self:GetChecked() and true or false)
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    cb.Refresh = function(self)
        self:SetChecked(ns.DB:Get(key) and true or false)
    end
    return cb
end

---------------------------------------------------------------------------
-- Tab contents
---------------------------------------------------------------------------
local function buildStart(p)
    local head = newText(p, "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText(L.START_HEADLINE)

    local text = newText(p, "GameFontHighlight", WIDTH - 50)
    text:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
    text:SetText(L.START_TEXT)

    local online = newText(p, "GameFontNormal")
    online:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)

    local b1 = newButton(p, L.START_BTN_SPRUCH, 140, function()
        ns.Sprueche.ShowLocal()
    end)
    b1:SetPoint("TOPLEFT", online, "BOTTOMLEFT", 0, -20)

    refreshers[#refreshers + 1] = function()
        if IsInGuild and IsInGuild() then
            online:SetText(L.START_ONLINE:format(ns.Roster.numOnline, ns.Roster.numTotal))
        else
            online:SetText(L.START_ONLINE_NO_GUILD)
        end
    end
end

local function buildPlaceholder(p, body)
    local head = newText(p, "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText(L.COMING_SOON)
    local text = newText(p, "GameFontHighlight", WIDTH - 50)
    text:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
    text:SetText(body)
end

local function buildInfo(p)
    local head = newText(p, "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 16, -12)
    head:SetText(L.ADDON_NAME)

    local ver = newText(p, "GameFontNormal")
    ver:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    ver:SetText(L.INFO_VERSION:format(ns.VERSION))

    local text = newText(p, "GameFontHighlight", WIDTH - 50)
    text:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -8)
    text:SetText(L.INFO_TEXT)

    local optHead = newText(p, "GameFontNormal")
    optHead:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    optHead:SetText(L.INFO_SETTINGS)

    local anchor = optHead
    local boxes = {}
    for _, opt in ipairs(ns.SettingsList) do
        local cb = newCheckbox(p, opt.key, L[opt.label], L[opt.tooltip])
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == optHead and -4 or 0, -2)
        anchor = cb
        boxes[#boxes + 1] = cb
    end
    refreshers[#refreshers + 1] = function()
        for _, cb in ipairs(boxes) do
            cb:Refresh()
        end
    end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
function UI.SelectTab(index)
    for i, panel in ipairs(panels) do
        panel:SetShown(i == index)
        if i == index then
            tabs[i]:LockHighlight()
        else
            tabs[i]:UnlockHighlight()
        end
    end
    UI.selected = index
end

function UI.Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    for _, fn in ipairs(refreshers) do
        fn()
    end
end

local function create()
    -- VERIFY IN-GAME: BasicFrameTemplateWithInset exists on Forever; fallback is a plain backdrop.
    local ok, f = pcall(CreateFrame, "Frame", "SpaetiFreundeMainFrame", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not f then
        f = CreateFrame("Frame", "SpaetiFreundeMainFrame", UIParent, "BackdropTemplate")
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
        end
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    frame = f
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:SetScript("OnShow", UI.Refresh)
    frame:Hide()
    restorePosition()
    tinsert(UISpecialFrames, frame:GetName()) -- close with ESC

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -6)
    title:SetText(L.WINDOW_TITLE)

    local defs = {
        { L.TAB_START, buildStart },
        { L.TAB_POINTS, function(p) buildPlaceholder(p, L.POINTS_TEXT) end },
        { L.TAB_ONLINE, function(p) buildPlaceholder(p, L.ONLINE_TEXT) end },
        { L.TAB_INFO, buildInfo },
    }
    local tabWidth = (WIDTH - 40) / #defs
    for i, def in ipairs(defs) do
        local tab = newButton(frame, def[1], tabWidth - 4, function()
            UI.SelectTab(i)
        end)
        tab:SetPoint("TOPLEFT", 18 + (i - 1) * tabWidth, -30)
        tabs[i] = tab

        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 8, -58)
        panel:SetPoint("BOTTOMRIGHT", -8, 8)
        def[2](panel)
        panels[i] = panel
    end
    UI.SelectTab(1)
end

function UI.Toggle(tabIndex)
    if not frame then
        create()
    end
    if frame:IsShown() and not tabIndex then
        frame:Hide()
    else
        if tabIndex then
            UI.SelectTab(tabIndex)
        end
        frame:Show()
        UI.Refresh()
    end
end

UI.TAB_INFO = 4

ns:On("SF_ROSTER_UPDATED", UI.Refresh)
ns:On("SF_SETTING_CHANGED", UI.Refresh)
