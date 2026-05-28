local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local Skin = ns.Skin

-- ============================================================
-- HUD — small movable overlay inside arenas. Shows enemy comp
-- (live, fed by SpecGuess) and the top saves for MY class
-- against the categories that comp can dish out (CC, burst,
-- interrupt, dispel).
--
-- Visibility flow:
--   MAT_ARENA_ENTERED  -> show, refresh on a 2s ticker
--   MAT_ARENA_STARTED  -> refresh (spec data starts coming in)
--   MAT_ARENA_ENDED    -> hide after a brief delay
--   MAT_ARENA_RESET    -> hide immediately
--
-- Test mode: `/mat hud test` toggles visibility outside arenas
-- with a fake comp so the user can position the frame.
--
-- DB: MAT.db.profile.hud = {
--     hidden = false,  -- user disables HUD entirely
--     locked = true,   -- if true, mouse passes through (no drag)
--     point  = { "CENTER", x, y },
--     scale  = 1.0,
-- }
-- ============================================================

local Hud = MAT:NewModule("Hud", "AceEvent-3.0", "AceTimer-3.0")
MAT.Hud = Hud

local frame, headerFS, lockBtn, enemyArea, savesArea
local enemyRows, saveRows = {}, {}
local refreshTimer, hideTimer
local testMode = false

local MAX_ROWS = 5
local WIDTH    = 220
local ROW_H    = 14

local CLASS_COLOR_HEX = {
    WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST  = "FFFFFF", DEATHKNIGHT = "C41F3B", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", DRUID = "FF7D0A",
}

local SEVERITY_COLOR = {
    [3] = { 0.95, 0.30, 0.30, 1.00 },  -- red
    [2] = { 1.00, 0.55, 0.00, 1.00 },  -- amber
    [1] = { 1.00, 0.82, 0.00, 1.00 },  -- yellow
}

-- ------------------------------------------------------------
-- Persistence
-- ------------------------------------------------------------

local function db()
    MAT.db.profile.hud = MAT.db.profile.hud or {}
    local h = MAT.db.profile.hud
    if h.hidden == nil then h.hidden = false end
    if h.locked == nil then h.locked = true end
    if h.scale  == nil then h.scale  = 1.0  end
    return h
end

local function savePoint()
    if not frame then return end
    local point, _, _, x, y = frame:GetPoint(1)
    db().point = { point or "CENTER", x or 0, y or 0 }
end

local function restorePoint()
    local p = db().point
    frame:ClearAllPoints()
    if p and p[1] then
        frame:SetPoint(p[1], UIParent, p[1], p[2] or 0, p[3] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    end
end

-- ------------------------------------------------------------
-- Build
-- ------------------------------------------------------------

local function build()
    if frame then return end

    frame = CreateFrame("Frame", "MeteoraArenaToolHud", UIParent, "BackdropTemplate")
    Skin:ApplyDark(frame)
    frame:SetSize(WIDTH, 60)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not db().locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing(); savePoint()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
    title:SetText("MAT")
    title:SetTextColor(unpack(Skin.color.accent))

    headerFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerFS:SetPoint("LEFT", title, "RIGHT", 8, 0)
    headerFS:SetTextColor(unpack(Skin.color.textDim))
    headerFS:SetText("")

    lockBtn = Skin:CreateButton(frame, "[L]", 28, 16)
    lockBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    lockBtn:SetScript("OnClick", function()
        db().locked = not db().locked
        Hud:ApplyLock()
    end)

    enemyArea = CreateFrame("Frame", nil, frame)
    enemyArea:SetPoint("TOPLEFT",  frame, "TOPLEFT",  6, -22)
    enemyArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -22)
    enemyArea:SetHeight(ROW_H * MAX_ROWS)

    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(Skin.color.border[1], Skin.color.border[2],
                        Skin.color.border[3], 0.6)
    sep:SetPoint("TOPLEFT",  enemyArea, "BOTTOMLEFT",  0, -2)
    sep:SetPoint("TOPRIGHT", enemyArea, "BOTTOMRIGHT", 0, -2)
    sep:SetHeight(1)
    frame.sep = sep

    savesArea = CreateFrame("Frame", nil, frame)
    savesArea:SetPoint("TOPLEFT",  sep, "BOTTOMLEFT",  0, -4)
    savesArea:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -4)
    savesArea:SetHeight(ROW_H * MAX_ROWS)

    restorePoint()
end

local function ensureEnemyRow(i)
    if enemyRows[i] then return enemyRows[i] end
    local fs = enemyArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", enemyArea, "TOPLEFT", 0, -(i - 1) * ROW_H)
    fs:SetWidth(WIDTH - 12); fs:SetJustifyH("LEFT")
    enemyRows[i] = fs
    return fs
end

local function ensureSaveRow(i)
    if saveRows[i] then return saveRows[i] end
    local fs = savesArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", savesArea, "TOPLEFT", 0, -(i - 1) * ROW_H)
    fs:SetWidth(WIDTH - 12); fs:SetJustifyH("LEFT")
    saveRows[i] = fs
    return fs
end

-- ------------------------------------------------------------
-- Data → rows
-- ------------------------------------------------------------

local function colorClass(name, classFile)
    local hex = classFile and CLASS_COLOR_HEX[classFile]
    if hex then return "|cff" .. hex .. (name or "?") .. "|r" end
    return name or "?"
end

local function getEnemyComp()
    -- In test mode return a static comp for positioning the HUD.
    if testMode then
        return {
            { name = "TestRogue", classFile = "ROGUE",   spec = "Subtlety" },
            { name = "TestMage",  classFile = "MAGE",    spec = "Frost"    },
        }
    end
    if MAT.SpecGuess and MAT.SpecGuess.GetTeamSpecs then
        local team = MAT.SpecGuess:GetTeamSpecs()
        if team and #team > 0 then return team end
    end
    if MAT.EnemyScanner and MAT.EnemyScanner.GetTeam then
        return MAT.EnemyScanner:GetTeam() or {}
    end
    return {}
end

local function enemyCategorySet(enemy)
    local set = {}
    local Threats = ns.Data and ns.Data.Cooldowns and ns.Data.Cooldowns.Threats
    if not Threats then return set end
    -- For each enemy class present, any threat with severity >= 2 lights up
    -- its category. Severity 1 threats are situational; we don't broadcast
    -- saves for them on the HUD.
    local seen = {}
    for _, e in ipairs(enemy) do
        if e.classFile and not seen[e.classFile] then
            seen[e.classFile] = true
            for _, t in pairs(Threats) do
                if t.class == e.classFile and (t.severity or 0) >= 2 then
                    set[t.category] = true
                end
            end
        end
    end
    return set
end

local function pickSaves(myClass, categories)
    local list = ns.Data and ns.Data.Cooldowns
                 and ns.Data.Cooldowns.Saves and ns.Data.Cooldowns.Saves[myClass]
    if not list then return {} end
    local scored = {}
    for _, s in ipairs(list) do
        local hits = 0
        for _, cat in ipairs(s.vs or {}) do
            if categories[cat] then hits = hits + 1 end
        end
        if hits > 0 then
            table.insert(scored, { save = s, hits = hits })
        end
    end
    table.sort(scored, function(a, b)
        if (a.save.severity or 0) ~= (b.save.severity or 0) then
            return (a.save.severity or 0) > (b.save.severity or 0)
        end
        if a.hits ~= b.hits then return a.hits > b.hits end
        return (a.save.name or "") < (b.save.name or "")
    end)
    return scored
end

local function categoriesLabel(categories)
    local out = {}
    for _, k in ipairs({ "cc", "burst", "interrupt", "dispel" }) do
        if categories[k] then table.insert(out, k) end
    end
    if #out == 0 then return "no threats" end
    return table.concat(out, "/")
end

function Hud:Refresh()
    if not frame or not frame:IsShown() then return end

    local enemy = getEnemyComp()
    local categories = enemyCategorySet(enemy)

    -- Enemy rows
    for i = 1, MAX_ROWS do
        local fs = ensureEnemyRow(i)
        local e = enemy[i]
        if e then
            local text = colorClass(e.name, e.classFile)
            if e.spec and e.spec ~= "" then
                text = text .. " |cff999999(" .. e.spec .. ")|r"
            end
            fs:SetText(text); fs:Show()
        else
            fs:SetText(""); fs:Hide()
        end
    end

    headerFS:SetText(categoriesLabel(categories))

    -- Saves rows
    local _, myClass = UnitClass("player")
    local saves = pickSaves(myClass, categories)
    for i = 1, MAX_ROWS do
        local fs = ensureSaveRow(i)
        local entry = saves[i]
        if entry then
            local sev = entry.save.severity or 1
            local col = SEVERITY_COLOR[sev] or SEVERITY_COLOR[1]
            local hex = string.format("%02x%02x%02x",
                math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255))
            fs:SetText(string.format("|cff%s[%d]|r %s", hex, sev, entry.save.name or "?"))
            fs:Show()
        else
            fs:SetText(""); fs:Hide()
        end
    end

    -- Resize whole frame to fit rendered rows
    local enemyCount = math.min(#enemy, MAX_ROWS)
    local savesCount = math.min(#saves, MAX_ROWS)
    local enemyH = math.max(enemyCount, 1) * ROW_H
    local savesH = math.max(savesCount, 1) * ROW_H
    enemyArea:SetHeight(enemyH)
    savesArea:SetHeight(savesH)
    frame:SetHeight(22 + enemyH + 6 + savesH + 6)
end

-- ------------------------------------------------------------
-- Visibility / lock
-- ------------------------------------------------------------

function Hud:ApplyLock()
    if not frame then return end
    local locked = db().locked
    -- When locked, the HUD lets mouse clicks fall through to the world.
    frame:EnableMouse(not locked)
    if lockBtn then lockBtn:SetText(locked and "[L]" or "[U]") end
end

function Hud:ApplyScale()
    if not frame then return end
    frame:SetScale(db().scale or 1.0)
end

function Hud:ShowFrame()
    if db().hidden then return end
    build()
    frame:SetScale(db().scale or 1.0)
    self:ApplyLock()
    frame:Show()
    if refreshTimer then self:CancelTimer(refreshTimer); refreshTimer = nil end
    refreshTimer = self:ScheduleRepeatingTimer("Refresh", 2.0)
    self:Refresh()
end

function Hud:HideFrame()
    if frame then frame:Hide() end
    if refreshTimer then self:CancelTimer(refreshTimer); refreshTimer = nil end
end

-- ------------------------------------------------------------
-- Lifecycle / events
-- ------------------------------------------------------------

function Hud:OnEnable()
    self:RegisterMessage("MAT_ARENA_ENTERED", "OnArenaEntered")
    self:RegisterMessage("MAT_ARENA_STARTED", "OnArenaStarted")
    self:RegisterMessage("MAT_ARENA_ENDED",   "OnArenaEnded")
    self:RegisterMessage("MAT_ARENA_RESET",   "OnArenaReset")
end

function Hud:OnArenaEntered()
    if hideTimer then self:CancelTimer(hideTimer); hideTimer = nil end
    self:ShowFrame()
end

function Hud:OnArenaStarted() self:Refresh() end

function Hud:OnArenaEnded()
    -- Linger 5s so the final saves snapshot can be read post-bell.
    if hideTimer then self:CancelTimer(hideTimer); hideTimer = nil end
    hideTimer = self:ScheduleTimer(function()
        if not testMode then Hud:HideFrame() end
    end, 5.0)
end

function Hud:OnArenaReset()
    if hideTimer then self:CancelTimer(hideTimer); hideTimer = nil end
    if not testMode then self:HideFrame() end
end

-- ------------------------------------------------------------
-- Slash hooks (called from Core:OnSlashCommand)
-- ------------------------------------------------------------

function Hud:SetHidden(hidden)
    local h = db()
    h.hidden = hidden and true or false
    if h.hidden then
        self:HideFrame()
        MAT:Print("HUD: disabled (off)")
    else
        if testMode or (IsActiveBattlefieldArena and IsActiveBattlefieldArena()) then
            self:ShowFrame()
        end
        MAT:Print("HUD: enabled (on). Appears on arena entry.")
    end
end

function Hud:PrintStatus()
    local h = db()
    local visible = frame and frame:IsShown() or false
    MAT:Print(string.format(
        "HUD: %s | drag %s | shown=%s | test=%s",
        h.hidden and "OFF" or "ON",
        h.locked and "LOCKED" or "UNLOCKED",
        visible and "yes" or "no",
        testMode and "yes" or "no"
    ))
    MAT:Print("  /mat hud on|off  /mat hud lock  /mat hud test  /mat hud reset  /mat hud debug")
end

function Hud:PrintDebug()
    local h = db()
    local inArena = IsActiveBattlefieldArena and IsActiveBattlefieldArena()
    local detIn   = MAT.Detector and MAT.Detector.IsInArena and MAT.Detector:IsInArena()
    local scan    = MAT.EnemyScanner and MAT.EnemyScanner.GetTeam and #MAT.EnemyScanner:GetTeam() or 0
    MAT:Print("|cffffd200=== HUD debug ===|r")
    MAT:Print(string.format("  hidden=%s locked=%s scale=%.2f",
        tostring(h.hidden), tostring(h.locked), h.scale or 1.0))
    MAT:Print(string.format("  IsActiveBattlefieldArena=%s Detector:IsInArena=%s",
        tostring(inArena), tostring(detIn)))
    MAT:Print(string.format("  frame built=%s shown=%s refreshTimer=%s",
        tostring(frame ~= nil),
        tostring(frame and frame:IsShown() or false),
        tostring(refreshTimer ~= nil)))
    MAT:Print(string.format("  EnemyScanner team size=%d testMode=%s",
        scan, tostring(testMode)))
    local p = h.point
    if p then
        MAT:Print(string.format("  saved point: %s x=%d y=%d",
            tostring(p[1]), p[2] or 0, p[3] or 0))
    else
        MAT:Print("  saved point: <default>")
    end
end

function Hud:ToggleLock()
    db().locked = not db().locked
    self:ApplyLock()
    MAT:Print("HUD: " .. (db().locked and "locked" or "unlocked"))
end

function Hud:ToggleTest()
    testMode = not testMode
    if testMode then
        MAT:Print("HUD test mode: ON. Use /mat hud test to disable.")
        self:ShowFrame()
    else
        MAT:Print("HUD test mode: OFF.")
        if not (IsActiveBattlefieldArena and IsActiveBattlefieldArena()) then
            self:HideFrame()
        end
    end
end

function Hud:ResetPosition()
    db().point = nil
    if frame then restorePoint() end
    MAT:Print("HUD position reset.")
end
