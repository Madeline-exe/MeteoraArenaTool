local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local UI = MAT.UI
local Skin = ns.Skin

-- ============================================================
-- Cooldowns tab — per-class editor over the seed Saves DB and a
-- read-only reference to the Threats DB.
--
-- Storage: MAT.db.global.cdOverrides[CLASS] = {
--     disabled = { [defaultSaveName] = true },
--     custom   = { {...} },   -- reserved for v0.3.x; not editable yet
-- }
-- HUD pulls effective saves via ns.Data.Cooldowns.GetEffectiveSaves
-- so disabling here removes the save from the HUD live.
-- ============================================================

UI.CooldownsPanel = UI.CooldownsPanel or {}
local CP = UI.CooldownsPanel

local CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN",  "MAGE",    "WARLOCK", "DRUID",
}

local CLASS_HEX = {
    WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST  = "FFFFFF", DEATHKNIGHT = "C41F3B", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", DRUID = "FF7D0A",
}

local SEVERITY_COLOR_HEX = {
    [3] = "f24c4c",  -- red
    [2] = "ff8c00",  -- amber
    [1] = "ffd200",  -- yellow
}

local selectedClass

local function defaultSelected()
    local _, cls = UnitClass("player")
    return cls or "WARRIOR"
end

-- ------------------------------------------------------------
-- DB helpers
-- ------------------------------------------------------------

local function getCdDb()
    MAT.db.global.cdOverrides = MAT.db.global.cdOverrides or {}
    return MAT.db.global.cdOverrides
end

local function isDisabled(class, name)
    local o = getCdDb()[class]
    return o and o.disabled and o.disabled[name] or false
end

local function setDisabled(class, name, disabled)
    local db = getCdDb()
    db[class] = db[class] or {}
    db[class].disabled = db[class].disabled or {}
    db[class].disabled[name] = disabled and true or nil
end

-- ------------------------------------------------------------
-- Widget helpers
-- ------------------------------------------------------------

local function colored(text, hex)
    return "|cff" .. hex .. text .. "|r"
end

local function severityBadge(sev)
    local hex = SEVERITY_COLOR_HEX[sev] or "888888"
    return colored("[" .. tostring(sev or 0) .. "]", hex)
end

local function categoryList(vs)
    if not vs then return "" end
    return table.concat(vs, ", ")
end

local function sectionStrip(parent, text)
    local strip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(strip, Skin.color.bgAlt, Skin.color.borderLight)
    strip:SetHeight(20)
    local fs = strip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", strip, "LEFT", 8, 0)
    fs:SetText(text)
    fs:SetTextColor(unpack(Skin.color.accent))
    strip.text = fs
    return strip
end

local function classButton(parent, classFile)
    local b = Skin:CreateButton(parent, classFile, 60, 22)
    local fs = b:GetFontString()
    if fs and CLASS_HEX[classFile] then
        fs:SetTextColor(
            tonumber(CLASS_HEX[classFile]:sub(1, 2), 16) / 255,
            tonumber(CLASS_HEX[classFile]:sub(3, 4), 16) / 255,
            tonumber(CLASS_HEX[classFile]:sub(5, 6), 16) / 255
        )
    end
    b._setActive = function(self, active)
        if active then
            self:SetBackdropColor(unpack(Skin.color.bgActive))
            self:SetBackdropBorderColor(unpack(Skin.color.accent))
        else
            self:SetBackdropColor(unpack(Skin.color.bgAlt))
            self:SetBackdropBorderColor(unpack(Skin.color.border))
        end
    end
    return b
end

-- ------------------------------------------------------------
-- Row pools
-- ------------------------------------------------------------

local function makeSavesRow(pool, i, parent, onToggle)
    if pool[i] then return pool[i] end
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(20)

    row.cb = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    row.cb:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.cb:SetScript("OnClick", function(self)
        if row._save then
            onToggle(row._save.name, not self:GetChecked())
        end
    end)

    row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.badge:SetPoint("LEFT", row.cb, "RIGHT", 26, 0)
    row.badge:SetWidth(28); row.badge:SetJustifyH("LEFT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.badge, "RIGHT", 4, 0)
    row.name:SetWidth(200); row.name:SetJustifyH("LEFT")

    row.vs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.vs:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.vs:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.vs:SetJustifyH("LEFT")
    row.vs:SetTextColor(unpack(Skin.color.textDim))

    pool[i] = row
    return row
end

local function makeThreatRow(pool, i, parent)
    if pool[i] then return pool[i] end
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.badge:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.badge:SetWidth(28); row.badge:SetJustifyH("LEFT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.badge, "RIGHT", 6, 0)
    row.name:SetWidth(220); row.name:SetJustifyH("LEFT")

    row.cat = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.cat:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.cat:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.cat:SetJustifyH("LEFT")
    row.cat:SetTextColor(unpack(Skin.color.textDim))

    pool[i] = row
    return row
end

-- ------------------------------------------------------------
-- Build
-- ------------------------------------------------------------

local widgets

function CP:Build(parent)
    if widgets then return end
    widgets = {}
    widgets.parent = parent
    selectedClass = selectedClass or defaultSelected()

    -- Class strip --------------------------------------------------------
    local classStrip = CreateFrame("Frame", nil, parent)
    classStrip:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, -10)
    classStrip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    classStrip:SetHeight(24)

    local pickerLabel = classStrip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pickerLabel:SetPoint("LEFT", classStrip, "LEFT", 0, 0)
    pickerLabel:SetText((L["cd_class"] or "Class:"))
    pickerLabel:SetTextColor(unpack(Skin.color.textDim))

    widgets.classBtns = {}
    local x = 50
    for _, cls in ipairs(CLASSES) do
        local b = classButton(classStrip, cls)
        b:SetPoint("LEFT", classStrip, "LEFT", x, 0)
        b:SetScript("OnClick", function()
            selectedClass = cls
            CP:Refresh()
        end)
        widgets.classBtns[cls] = b
        x = x + 62
    end

    -- Saves section ------------------------------------------------------
    widgets.savesStrip = sectionStrip(parent, "")  -- title set in Refresh
    widgets.savesStrip:SetPoint("TOPLEFT",  classStrip, "BOTTOMLEFT",  0, -8)
    widgets.savesStrip:SetPoint("TOPRIGHT", classStrip, "BOTTOMRIGHT", 0, -8)

    widgets.savesArea = CreateFrame("Frame", nil, parent)
    widgets.savesArea:SetPoint("TOPLEFT",  widgets.savesStrip, "BOTTOMLEFT",  0, -4)
    widgets.savesArea:SetPoint("TOPRIGHT", widgets.savesStrip, "BOTTOMRIGHT", 0, -4)
    widgets.savesArea:SetHeight(8 * 20 + 4)
    widgets.savesPool = {}

    -- Threats section ----------------------------------------------------
    widgets.threatsStrip = sectionStrip(parent, "")
    widgets.threatsStrip:SetPoint("TOPLEFT",  widgets.savesArea, "BOTTOMLEFT",  0, -10)
    widgets.threatsStrip:SetPoint("TOPRIGHT", widgets.savesArea, "BOTTOMRIGHT", 0, -10)

    widgets.threatsArea = CreateFrame("Frame", nil, parent)
    widgets.threatsArea:SetPoint("TOPLEFT",  widgets.threatsStrip, "BOTTOMLEFT",  0, -4)
    widgets.threatsArea:SetPoint("TOPRIGHT", widgets.threatsStrip, "BOTTOMRIGHT", 0, -4)
    widgets.threatsArea:SetHeight(10 * 18 + 4)
    widgets.threatsPool = {}

    widgets.emptyFS = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    widgets.emptyFS:SetPoint("CENTER", widgets.savesArea, "CENTER", 0, 0)
    widgets.emptyFS:SetText(L["cd_no_data"] or "")
end

-- ------------------------------------------------------------
-- Render
-- ------------------------------------------------------------

local function classColor(cls)
    return CLASS_HEX[cls] or "ffffff"
end

local function sortedThreatsForClass(cls)
    local CD = ns.Data and ns.Data.Cooldowns
    if not CD or not CD.Threats then return {} end
    local out = {}
    for spellId, t in pairs(CD.Threats) do
        if t.class == cls then
            table.insert(out, { id = spellId, t = t })
        end
    end
    table.sort(out, function(a, b)
        if (a.t.severity or 0) ~= (b.t.severity or 0) then
            return (a.t.severity or 0) > (b.t.severity or 0)
        end
        return (a.t.name or "") < (b.t.name or "")
    end)
    return out
end

local function renderSaves(area, pool, cls)
    local CD = ns.Data and ns.Data.Cooldowns
    local list = CD and CD.Saves and CD.Saves[cls] or {}

    for i, save in ipairs(list) do
        local row = makeSavesRow(pool, i, area, function(name, newDisabled)
            setDisabled(cls, name, newDisabled)
        end)
        row._save = save
        row.cb:SetChecked(not isDisabled(cls, save.name))
        row.badge:SetText(severityBadge(save.severity))
        row.name:SetText(save.name or "?")
        row.vs:SetText(L["cd_vs"] and (L["cd_vs"] .. " " .. categoryList(save.vs))
                       or "vs " .. categoryList(save.vs))
        row:Show()
        row:SetPoint("TOPLEFT",  area, "TOPLEFT",  0, -((i - 1) * 20))
        row:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -((i - 1) * 20))
    end
    for i = #list + 1, #pool do if pool[i] then pool[i]:Hide() end end
    return #list
end

local function renderThreats(area, pool, cls)
    local list = sortedThreatsForClass(cls)
    for i, entry in ipairs(list) do
        local row = makeThreatRow(pool, i, area)
        row.badge:SetText(severityBadge(entry.t.severity))
        row.name:SetText(entry.t.name or ("spell " .. tostring(entry.id)))
        row.cat:SetText(entry.t.category or "?")
        row:Show()
        row:SetPoint("TOPLEFT",  area, "TOPLEFT",  0, -((i - 1) * 18))
        row:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -((i - 1) * 18))
    end
    for i = #list + 1, #pool do if pool[i] then pool[i]:Hide() end end
    return #list
end

function CP:Refresh()
    if not widgets then return end
    selectedClass = selectedClass or defaultSelected()

    -- Toggle class button highlight
    for cls, b in pairs(widgets.classBtns) do b:_setActive(cls == selectedClass) end

    -- Section titles
    local clsHex = classColor(selectedClass)
    widgets.savesStrip.text:SetText(
        (L["cd_my_saves"] or "Saves") .. "  " ..
        colored(selectedClass, clsHex)
    )
    widgets.threatsStrip.text:SetText(
        (L["cd_threats"] or "Threats from") .. "  " ..
        colored(selectedClass, clsHex)
    )

    local nSaves   = renderSaves(widgets.savesArea, widgets.savesPool, selectedClass)
    local nThreats = renderThreats(widgets.threatsArea, widgets.threatsPool, selectedClass)
    widgets.emptyFS:SetShown(nSaves == 0 and nThreats == 0)
end
