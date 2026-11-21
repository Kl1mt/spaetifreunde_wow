-- UI/Minimap.lua: small self-made minimap button + Addon Compartment callbacks.
local _, ns = ...

local L = ns.L
local ICON = "Interface\\Icons\\INV_Drink_05" -- VERIFY IN-GAME: icon exists on Forever
local RADIUS = 105 -- distance from minimap centre (round minimap)

local button

local function showTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME, 1, 0.64, 0.24)
    GameTooltip:AddLine(L.TOOLTIP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.TOOLTIP_RIGHT, 1, 1, 1)
    if owner == button then
        GameTooltip:AddLine(L.TOOLTIP_DRAG, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function onClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.OpenSettings()
    else
        ns.UI.Toggle()
    end
end

local function updatePosition()
    local angle = math.rad(ns.DB.data.minimap.angle or 200)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function onDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.DB.data.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    updatePosition()
end

local function create()
    if button or not Minimap then
        return
    end
    button = CreateFrame("Button", "SpaetiFreundeMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        onClick(mouseButton)
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        showTooltip(self, "ANCHOR_LEFT")
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    updatePosition()
end

local function applyVisibility()
    if ns.DB:Get("showMinimap") then
        create()
        if button then
            button:Show()
        end
    elseif button then
        button:Hide()
    end
end

ns:On("SF_LOGIN", applyVisibility)
ns:On("SF_SETTING_CHANGED", function(key)
    if key == "showMinimap" then
        applyVisibility()
    end
end)

---------------------------------------------------------------------------
-- Addon Compartment (TOC: AddonCompartmentFunc*). VERIFY IN-GAME on Forever.
---------------------------------------------------------------------------
-- 11.0+ passes (addonName, menuInputData, menu) with menuInputData.buttonName;
-- older clients pass the button name string directly. Accept both.
function SpaetiFreunde_OnCompartmentClick(_, input)
    local mouseButton = type(input) == "table" and input.buttonName or input
    onClick(mouseButton)
end

function SpaetiFreunde_OnCompartmentEnter(_, menuButtonFrame)
    if menuButtonFrame then
        showTooltip(menuButtonFrame, "ANCHOR_LEFT")
    end
end

function SpaetiFreunde_OnCompartmentLeave()
    GameTooltip:Hide()
end
