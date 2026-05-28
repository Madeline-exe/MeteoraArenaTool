local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local UI = MAT.UI
local Skin = ns.Skin

-- ============================================================
-- Custom main window. Owns Build/Toggle/Refresh/OpenTab on UI.
-- Loaded last in the TOC so it overrides any stubs.
-- v0.1: only the "Feed" tab is populated; the other tabs render
-- a "coming soon" placeholder so the tab bar layout is final.
-- ============================================================

local main, titleBar, titleFS, closeBtn, resizer
local tabBar, contentArea, statusBar, statusFS, versionFS
local tabButtons = {}
local currentTab = "feed"

local MIN_WIDTH, MIN_HEIGHT = 760, 460

local TABS = {
    { value = "feed",     labelKey = "tab_feed"     },
    { value = "lfg",      labelKey = "tab_lfg"      },
    { value = "stats",    labelKey = "tab_stats"    },
    { value = "cd",       labelKey = "tab_cd"       },
    { value = "settings", labelKey = "tab_settings" },
}

-- ------------------------------------------------------------
-- Tab visuals
-- ------------------------------------------------------------

local function setTabActive(button, isActive)
    if isActive then
        button:SetBackdropColor(Skin.color.bgActive[1], Skin.color.bgActive[2],
                                Skin.color.bgActive[3], Skin.color.bgActive[4])
        button:SetBackdropBorderColor(Skin.color.accent[1], Skin.color.accent[2],
                                      Skin.color.accent[3], Skin.color.accent[4])
        local fs = button:GetFontString()
        if fs then fs:SetTextColor(unpack(Skin.color.accent)) end
    else
        button:SetBackdropColor(Skin.color.bgAlt[1], Skin.color.bgAlt[2],
                                Skin.color.bgAlt[3], Skin.color.bgAlt[4])
        button:SetBackdropBorderColor(Skin.color.border[1], Skin.color.border[2],
                                      Skin.color.border[3], Skin.color.border[4])
        local fs = button:GetFontString()
        if fs then fs:SetTextColor(unpack(Skin.color.textFg)) end
    end
end

local function savePosition()
    if not main then return end
    local point, _, relPoint, x, y = main:GetPoint(1)
    MAT.db.profile.ui = MAT.db.profile.ui or {}
    MAT.db.profile.ui.mainFramePoint = { point, "UIParent", relPoint, x, y }
    MAT.db.profile.ui.width  = main:GetWidth()
    MAT.db.profile.ui.height = main:GetHeight()
end

local function restorePosition()
    local ui = MAT.db.profile.ui or {}
    local p = ui.mainFramePoint
    main:ClearAllPoints()
    if p and p[1] then
        main:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
    else
        main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    local w = math.max(ui.width  or 820, MIN_WIDTH)
    local h = math.max(ui.height or 520, MIN_HEIGHT)
    main:SetSize(w, h)
end

-- ------------------------------------------------------------
-- Build root window
-- ------------------------------------------------------------

local function build()
    if main then return end

    main = CreateFrame("Frame", "MeteoraArenaToolMain", UIParent, "BackdropTemplate")
    Skin:ApplyDark(main)
    main:SetSize(820, 520)
    main:SetMovable(true)
    main:SetResizable(true)
    if main.SetMinResize then main:SetMinResize(MIN_WIDTH, MIN_HEIGHT) end
    main:SetClampedToScreen(true)
    main:SetFrameStrata("MEDIUM")
    main:EnableMouse(true)
    main:Hide()
    tinsert(UISpecialFrames, "MeteoraArenaToolMain")

    main:SetScript("OnHide", savePosition)

    titleBar = CreateFrame("Frame", nil, main, "BackdropTemplate")
    Skin:ApplyDark(titleBar, Skin.color.bgAlt, Skin.color.borderLight)
    titleBar:SetPoint("TOPLEFT",  main, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() main:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        main:StopMovingOrSizing(); savePosition()
    end)

    titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleFS:SetTextColor(unpack(Skin.color.accent))
    titleFS:SetText("Meteora Arena Tool")

    closeBtn = Skin:CreateButton(titleBar, "X", 24, 22)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    local cfs = closeBtn:GetFontString()
    if cfs then cfs:SetTextColor(unpack(Skin.color.danger)) end
    closeBtn:SetScript("OnClick", function() main:Hide() end)

    tabBar = CreateFrame("Frame", nil, main)
    tabBar:SetPoint("TOPLEFT",  titleBar, "BOTTOMLEFT",  4, -4)
    tabBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -4, -4)
    tabBar:SetHeight(24)

    local x = 0
    for _, tab in ipairs(TABS) do
        local label = L[tab.labelKey] or tab.value
        local btn = Skin:CreateButton(tabBar, label, 110, 22)
        btn:SetPoint("LEFT", tabBar, "LEFT", x, 0)
        btn:SetScript("OnClick", function() UI:OpenTab(tab.value) end)
        tabButtons[tab.value] = btn
        x = x + 112
    end

    contentArea = CreateFrame("Frame", nil, main, "BackdropTemplate")
    Skin:ApplyDark(contentArea, Skin.color.bg, Skin.color.border)
    contentArea:SetPoint("TOPLEFT",     tabBar, "BOTTOMLEFT",  0, -4)
    contentArea:SetPoint("BOTTOMRIGHT", main,   "BOTTOMRIGHT", -4, 20)

    statusBar = CreateFrame("Frame", nil, main)
    statusBar:SetPoint("BOTTOMLEFT",  main, "BOTTOMLEFT",  4, 2)
    statusBar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -22, 2)
    statusBar:SetHeight(16)

    statusFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusFS:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
    statusFS:SetText(L["status_ready"] or "")

    versionFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionFS:SetPoint("RIGHT", statusBar, "RIGHT", 0, 0)
    versionFS:SetText("v" .. (MAT.version or "?"))

    resizer = CreateFrame("Button", nil, main)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function() main:StartSizing("BOTTOMRIGHT") end)
    resizer:SetScript("OnMouseUp",   function() main:StopMovingOrSizing(); savePosition() end)

    restorePosition()
end

-- ------------------------------------------------------------
-- Feed tab — list of matches
-- ------------------------------------------------------------

local CLASS_COLOR_HEX = {
    WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST  = "FFFFFF", DEATHKNIGHT = "C41F3B", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", MONK = "00FF96", DRUID = "FF7D0A",
}

local function colorClass(name, classFile)
    if not name then return "?" end
    local hex = classFile and CLASS_COLOR_HEX[classFile]
    if hex then return "|cff" .. hex .. name .. "|r" end
    return name
end

local function shortDuration(sec)
    sec = sec or 0
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function whenStr(ts)
    if not ts then return "?" end
    return date("%d.%m %H:%M", ts)
end

local function resultColored(result, delta)
    local label
    if result == "win" then
        label = "|cff4fdd4f" .. (L["result_win"] or "Win") .. "|r"
    elseif result == "loss" then
        label = "|cffee4040" .. (L["result_loss"] or "Loss") .. "|r"
    elseif result == "draw" then
        label = "|cffcccc55" .. (L["result_draw"] or "Draw") .. "|r"
    else
        label = "?"
    end
    if delta then
        local sign = delta >= 0 and "+" or ""
        local col  = delta >= 0 and "|cff4fdd4f" or "|cffee4040"
        label = label .. " " .. col .. sign .. delta .. "|r"
    end
    return label
end

local function enemyShort(team)
    if not team or #team == 0 then return "?" end
    local parts = {}
    for _, p in ipairs(team) do
        local s = colorClass(p.name or "?", p.classFile)
        if p.spec and p.spec ~= "" then
            s = s .. " |cff999999(" .. p.spec .. ")|r"
        end
        table.insert(parts, s)
    end
    return table.concat(parts, ", ")
end

local feedScroll, feedChild, feedEmpty
local feedRows = {}  -- pool

local function ensureFeedRow(i, parent)
    if feedRows[i] then return feedRows[i] end
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(22)
    Skin:ApplyDark(row, Skin.color.bgAlt, Skin.color.border)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(Skin.color.bgHover[1], Skin.color.bgHover[2],
                              Skin.color.bgHover[3], Skin.color.bgHover[4])
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(Skin.color.bgAlt[1], Skin.color.bgAlt[2],
                              Skin.color.bgAlt[3], Skin.color.bgAlt[4])
    end)

    row.when    = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.when:SetPoint("LEFT", row, "LEFT", 6, 0); row.when:SetWidth(86); row.when:SetJustifyH("LEFT")

    row.bracket = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.bracket:SetPoint("LEFT", row.when, "RIGHT", 4, 0); row.bracket:SetWidth(64); row.bracket:SetJustifyH("LEFT")

    row.map     = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.map:SetPoint("LEFT", row.bracket, "RIGHT", 4, 0); row.map:SetWidth(140); row.map:SetJustifyH("LEFT")

    row.result  = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.result:SetPoint("LEFT", row.map, "RIGHT", 4, 0); row.result:SetWidth(110); row.result:SetJustifyH("LEFT")

    row.duration = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.duration:SetPoint("LEFT", row.result, "RIGHT", 4, 0); row.duration:SetWidth(54); row.duration:SetJustifyH("LEFT")

    row.enemy   = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.enemy:SetPoint("LEFT", row.duration, "RIGHT", 4, 0); row.enemy:SetPoint("RIGHT", row, "RIGHT", -6, 0); row.enemy:SetJustifyH("LEFT")

    feedRows[i] = row
    return row
end

local function buildFeedContent(container)
    -- Header strip
    local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
    Skin:ApplyDark(header, Skin.color.bgAlt, Skin.color.borderLight)
    header:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -4)
    header:SetHeight(20)

    local function hCol(text, left, width)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", header, "LEFT", left, 0)
        fs:SetWidth(width); fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(unpack(Skin.color.accent))
        return fs
    end
    hCol(L["col_when"]    or "When",    6,   86)
    hCol(L["col_bracket"] or "Bracket", 96,  64)
    hCol(L["col_map"]     or "Map",     164, 140)
    hCol(L["col_result"]  or "Result",  308, 110)
    hCol(L["col_duration"] or "Dur",    422, 54)
    hCol(L["col_enemy"]   or "Enemy",   480, 220)

    feedScroll = CreateFrame("ScrollFrame", "MATFeedScroll", container, "UIPanelScrollFrameTemplate")
    feedScroll:SetPoint("TOPLEFT",     header, "BOTTOMLEFT", 0, -2)
    feedScroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 4)

    feedChild = CreateFrame("Frame", nil, feedScroll)
    feedChild:SetSize(1, 1)
    feedScroll:SetScrollChild(feedChild)

    feedEmpty = container:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    feedEmpty:SetPoint("CENTER", feedScroll, "CENTER", 0, 0)
    feedEmpty:SetText(L["no_matches"] or "")
end

function UI:RefreshFeed()
    if not feedChild then return end
    local matches = MAT.Match and MAT.Match:GetAll() or {}

    -- Render newest first.
    local n = #matches
    feedEmpty:SetShown(n == 0)

    local rowH = 22
    local pad  = 2
    local width = feedScroll:GetWidth()
    feedChild:SetSize(math.max(width, 1), math.max(n * (rowH + pad), 1))

    for i = 1, n do
        local rec = matches[n - i + 1]
        local row = ensureFeedRow(i, feedChild)
        row:Show()
        row:SetPoint("TOPLEFT",  feedChild, "TOPLEFT",  0, -((i - 1) * (rowH + pad)))
        row:SetPoint("TOPRIGHT", feedChild, "TOPRIGHT", 0, -((i - 1) * (rowH + pad)))

        row.when:SetText(whenStr(rec.ts))
        row.bracket:SetText(rec.bracket or "?")
        row.map:SetText(rec.map or "?")
        row.result:SetText(resultColored(rec.result, rec.ratingDelta))
        row.duration:SetText(shortDuration(rec.durationSec))
        local enemy = enemyShort(rec.enemyTeam)
        if rec.note and rec.note ~= "" then enemy = enemy .. "  |cffffd200*|r" end
        row.enemy:SetText(enemy)

        row:SetScript("OnClick", function()
            if UI.OpenNoteFor then UI:OpenNoteFor(rec.id) end
        end)
    end

    for i = n + 1, #feedRows do
        if feedRows[i] then feedRows[i]:Hide() end
    end
end

-- ------------------------------------------------------------
-- Placeholder tabs
-- ------------------------------------------------------------

local function buildPlaceholderContent(container, msgKey)
    local fs = container:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    fs:SetPoint("CENTER", container, "CENTER", 0, 0)
    fs:SetText(L[msgKey] or L["coming_soon"] or "Coming soon")
end

-- ------------------------------------------------------------
-- Tab switching — build each tab's content frame exactly once
-- and just show/hide on switch. The earlier "wipe + rebuild on
-- every switch" pattern (a) orphaned the row pool because
-- SetParent(nil) on cached rows leaves feedRows pointing at
-- detached frames, and (b) stacked FontStrings across switches
-- because container:CreateFontString attaches a Region (not a
-- child), so GetChildren()/SetParent(nil) doesn't reach it.
-- ------------------------------------------------------------

local tabContents   = {}  -- [tabValue] = Frame (lazy-built once)
local tabRefreshers = {}  -- [tabValue] = function() refresh data end

local function getTabContent(tabValue)
    if tabContents[tabValue] then return tabContents[tabValue] end

    local f = CreateFrame("Frame", nil, contentArea)
    f:SetAllPoints(contentArea)
    f:Hide()
    tabContents[tabValue] = f

    if tabValue == "feed" then
        buildFeedContent(f)
        tabRefreshers[tabValue] = function() UI:RefreshFeed() end
    elseif tabValue == "lfg" and UI.LFGPanel then
        UI.LFGPanel:Build(f)
        tabRefreshers[tabValue] = function() UI.LFGPanel:Refresh() end
    elseif tabValue == "settings" and UI.SettingsPanel then
        UI.SettingsPanel:Build(f)
        tabRefreshers[tabValue] = function() UI.SettingsPanel:Refresh() end
    elseif tabValue == "stats" and UI.StatsPanel then
        UI.StatsPanel:Build(f)
        tabRefreshers[tabValue] = function() UI.StatsPanel:Refresh() end
    else
        buildPlaceholderContent(f, "coming_soon")
    end
    return f
end

local function showTab(tabValue)
    if not main then build() end
    currentTab = tabValue
    for value, btn in pairs(tabButtons) do setTabActive(btn, value == tabValue) end

    for _, f in pairs(tabContents) do f:Hide() end

    local ok, err = pcall(function()
        local content = getTabContent(tabValue)
        content:Show()
        if tabRefreshers[tabValue] then tabRefreshers[tabValue]() end
    end)
    if not ok then MAT:Print("|cffff5555[Tab " .. tabValue .. "]|r " .. tostring(err)) end
end

-- ------------------------------------------------------------
-- UI module API
-- ------------------------------------------------------------

function UI:Build() build(); return main end

function UI:Toggle()
    build()
    if main:IsShown() then main:Hide()
    else main:Show(); showTab(currentTab) end
end

function UI:Refresh()
    if main and main:IsShown() then showTab(currentTab) end
end

local refreshPending = false
function UI:RefreshLater()
    if not main or not main:IsShown() then return end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.1, function()
        refreshPending = false
        if main and main:IsShown() then UI:Refresh() end
    end)
end

function UI:OpenTab(tabValue)
    build()
    if not main:IsShown() then main:Show() end
    showTab(tabValue)
end
