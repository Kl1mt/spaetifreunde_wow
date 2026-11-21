-- UI/PointsTab.lua: "Punkte" tab – own points/rank/progress, leaderboard,
-- Stammkunde des Monats, recent thanks (with officer void), thank box, sync status.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local PD = ns.PointsData

local ROWS = 11
local ROW_H = 18
local LIST_TOP = -100
local COL_LEFT, COL_RIGHT = 12, 256
local COL_W = 236
local VOID_CONFIRM_SECONDS = 4

local function esc(s)
    return (tostring(s or "?"):gsub("|", "||"))
end

local function berlinStamp(t)
    local d = ns.Time.BerlinDate(t)
    return ("%02d.%02d. %02d:%02d"):format(d.day, d.month, d.hour, d.min)
end

-- Small scrollable list with a fixed number of row widgets (mouse wheel + buttons).
local function newList(parent, x, width, makeRow, fillRow)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", x, LIST_TOP)
    box:SetSize(width, ROWS * ROW_H)
    box:EnableMouseWheel(true)
    local list = { offset = 0, data = {}, rows = {} }
    for i = 1, ROWS do
        local row = makeRow(box, width - 20)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        list.rows[i] = row
    end
    function list.Update()
        local maxOffset = math.max(0, #list.data - ROWS)
        if list.offset > maxOffset then
            list.offset = maxOffset
        end
        for i = 1, ROWS do
            local item = list.data[list.offset + i]
            local row = list.rows[i]
            if item then
                fillRow(row, item, list.offset + i)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    local function scroll(delta)
        list.offset = math.max(0, list.offset - delta)
        list.Update()
    end
    box:SetScript("OnMouseWheel", function(_, delta)
        scroll(delta * 3)
    end)
    -- VERIFY IN-GAME: scroll button templates on Forever; plain buttons as fallback.
    local function arrow(template, fallbackText, delta, anchor, yOff)
        local ok, b = pcall(CreateFrame, "Button", nil, box, template)
        if not ok or not b then
            b = UI.NewButton(box, fallbackText, 18)
        end
        b:SetSize(18, 18)
        b:SetPoint(anchor, box, anchor, 0, yOff)
        b:SetScript("OnClick", function() scroll(delta * ROWS) end)
        return b
    end
    arrow("UIPanelScrollUpButtonTemplate", "^", 1, "TOPRIGHT", 0)
    arrow("UIPanelScrollDownButtonTemplate", "v", -1, "BOTTOMRIGHT", 0)
    return list
end

function UI.BuildPoints(p)
    local nameBox -- EditBox, created further down

    local mine = UI.NewText(p, "GameFontNormalLarge")
    mine:SetPoint("TOPLEFT", COL_LEFT + 4, -8)

    local bar = CreateFrame("StatusBar", nil, p)
    bar:SetPoint("TOPLEFT", COL_LEFT + 4, -34)
    bar:SetSize(220, 14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.91, 0.64, 0.24)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0, 0, 0, 0.5)

    local nextText = UI.NewText(p, "GameFontHighlight")
    nextText:SetPoint("LEFT", bar, "RIGHT", 8, 0)

    local month = UI.NewText(p, "GameFontNormal")
    month:SetPoint("TOPLEFT", COL_LEFT + 4, -56)

    local headLeft = UI.NewText(p, "GameFontNormal")
    headLeft:SetPoint("TOPLEFT", COL_LEFT + 4, LIST_TOP + 20)
    headLeft:SetText(L.POINTS_LEADERBOARD)
    local headRight = UI.NewText(p, "GameFontNormal")
    headRight:SetPoint("TOPLEFT", COL_RIGHT, LIST_TOP + 20)
    headRight:SetText(L.POINTS_RECENT)

    -- Leaderboard: click a name to put it into the thank box.
    local board = newList(p, COL_LEFT, COL_W, function(box, w)
        local row = CreateFrame("Button", nil, box)
        row:SetSize(w, ROW_H)
        row.text = UI.NewText(row, "GameFontHighlight")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetWidth(w - 4)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnClick", function(self)
            if self.name and nameBox then
                nameBox:SetText(self.name)
            end
        end)
        return row
    end, function(row, item, pos)
        row.name = item.name
        row.text:SetText(L.POINTS_ROW:format(pos, esc(item.name), item.points))
    end)

    -- Recent thanks; officers get a two-click "Storno" button per row.
    local recent = newList(p, COL_RIGHT, COL_W, function(box, w)
        local row = CreateFrame("Frame", nil, box)
        row:SetSize(w, ROW_H)
        row.text = UI.NewText(row, "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 0, 0)
        row.text:SetWidth(w - 56)
        row.void = UI.NewButton(row, L.POINTS_VOID, 54, function(self)
            local id = self:GetParent().id
            if not id then
                return
            end
            if self.armed == id then
                self.armed = nil
                ns.Points:Void(id)
            else
                self.armed = id
                self:SetText(L.POINTS_VOID_CONFIRM)
                C_Timer.After(VOID_CONFIRM_SECONDS, function()
                    if self.armed == id then
                        self.armed = nil
                        self:SetText(L.POINTS_VOID)
                    end
                end)
            end
        end)
        row.void:SetHeight(ROW_H)
        row.void:SetPoint("RIGHT", 0, 0)
        row.void:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.POINTS_VOID, 1, 1, 1)
            GameTooltip:AddLine(L.POINTS_VOID_TT, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        row.void:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return row
    end, function(row, item)
        local e = item.e
        row.id = item.id
        row.text:SetText(berlinStamp(e.t) .. "  " .. L.POINTS_RECENT_LINE:format(
            esc(ns.Points.NameOf(e.a)), esc(ns.Points.NameOf(e.b))))
        if row.void.armed ~= item.id then
            row.void.armed = nil
            row.void:SetText(L.POINTS_VOID)
        end
        row.void:SetShown(ns.Roster:IsOfficer())
    end)

    local recentEmpty = UI.NewText(p, "GameFontDisable")
    recentEmpty:SetPoint("TOPLEFT", COL_RIGHT, LIST_TOP)
    recentEmpty:SetText(L.POINTS_RECENT_EMPTY)

    -- Thank box
    local label = UI.NewText(p, "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", COL_LEFT + 4, 40)
    label:SetText(L.POINTS_THANK_LABEL)

    nameBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    nameBox:SetSize(170, 20)
    nameBox:SetPoint("LEFT", label, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(48)

    local function doThank()
        local text = nameBox:GetText()
        if ns.Points:Thank(text) then
            nameBox:SetText("")
        end
        nameBox:ClearFocus()
    end
    nameBox:SetScript("OnEnterPressed", doThank)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local thankBtn = UI.NewButton(p, L.POINTS_THANK_BUTTON, 80, doThank)
    thankBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)

    local left = UI.NewText(p, "GameFontHighlightSmall")
    left:SetPoint("LEFT", thankBtn, "RIGHT", 8, 0)

    local hint = UI.NewText(p, "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", COL_LEFT + 4, 24)
    hint:SetText(L.POINTS_PICK_HINT)

    local sync = UI.NewText(p, "GameFontDisableSmall")
    sync:SetPoint("BOTTOMLEFT", COL_LEFT + 4, 8)

    UI.AddRefresher(function()
        local Points = ns.Points
        if not (IsInGuild and IsInGuild()) then
            mine:SetText(L.POINTS_NO_GUILD)
            return
        end
        local pts, idx, nextNeed = Points:MyStanding()
        mine:SetText(L.POINTS_MINE:format(pts, Points.RankName(idx)))
        local floorNeed = PD.RANK_THRESHOLDS[idx]
        if nextNeed then
            bar:SetMinMaxValues(floorNeed, nextNeed)
            bar:SetValue(pts)
            nextText:SetText(L.POINTS_NEXT:format(nextNeed - pts, Points.RankName(idx + 1)))
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            nextText:SetText(L.POINTS_TOP)
        end

        local d = Points.derived
        if d and d.monthWinner then
            month:SetText(L.POINTS_MONTH:format(esc(Points.NameOf(d.monthWinner)), d.monthWinnerCount))
        else
            month:SetText(L.POINTS_MONTH_NONE)
        end

        board.data = Points:Leaderboard()
        board.Update()
        recent.data = d and d.accepted or {}
        recent.Update()
        recentEmpty:SetShown(#recent.data == 0)
        left:SetText(L.POINTS_LEFT_TODAY:format(Points:ThanksLeftToday()))

        local st = ns.Sync.Status()
        local state
        if st.paused then
            state = L.SYNC_PAUSED
        elseif st.queued > 0 then
            state = L.SYNC_QUEUE:format(st.queued)
        elseif st.lastHello then
            state = L.SYNC_OK
        else
            state = L.SYNC_WAITING
        end
        local text = L.SYNC_STATUS:format(state, st.entries)
        local last = st.lastData or st.lastHello
        if last then
            text = text .. " · " .. L.SYNC_LAST:format(berlinStamp(last))
        end
        sync:SetText(text)
    end)
end
