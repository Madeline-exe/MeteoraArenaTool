local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local UI = MAT.UI
local Skin = ns.Skin

-- ============================================================
-- Stats tab — aggregates MAT.Match:GetAll() by enemy comp,
-- map, and partner. Filter strip on top (bracket + period).
-- All tables are text-only; no graphs in MVP.
--
-- Bucket value shape per group:
--   { games, wins, losses, draws, delta (sum of ratingDelta) }
-- ============================================================

UI.StatsPanel = UI.StatsPanel or {}
local SP = UI.StatsPanel

local filterState = { bracket = "all", period = "all" }

-- ------------------------------------------------------------
-- Class colour helpers (same set used by Feed)
-- ------------------------------------------------------------

local CLASS_HEX = {
    WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST  = "FFFFFF", DEATHKNIGHT = "C41F3B", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", DRUID = "FF7D0A",
}

local function colorClass(text, classFile)
    local hex = classFile and CLASS_HEX[classFile]
    if hex then return "|cff" .. hex .. text .. "|r" end
    return text
end

-- ------------------------------------------------------------
-- Filtering / aggregation
-- ------------------------------------------------------------

local function matchPasses(rec)
    if filterState.bracket ~= "all" then
        if rec.bracket ~= filterState.bracket then return false end
    end
    local cutoff = ({ today = 86400, week = 7 * 86400, month = 30 * 86400 })[filterState.period]
    if cutoff and (time() - (rec.ts or 0)) > cutoff then return false end
    return true
end

local function compKey(team)
    local cls = {}
    for _, p in ipairs(team or {}) do
        table.insert(cls, p.classFile or "?")
    end
    table.sort(cls)
    return table.concat(cls, "+")
end

local function compLabel(team)
    -- Same sort order as compKey, but rendered as class-coloured short names.
    local parts = {}
    for _, p in ipairs(team or {}) do
        table.insert(parts, { c = p.classFile or "?" })
    end
    table.sort(parts, function(a, b) return a.c < b.c end)
    local out = {}
    for _, p in ipairs(parts) do table.insert(out, colorClass(p.c, p.c)) end
    return table.concat(out, " + ")
end

local function partnerKey(myTeam)
    local me = UnitName("player")
    local out = {}
    for _, p in ipairs(myTeam or {}) do
        if (p.name or "") ~= me then
            table.insert(out, (p.classFile or "?") .. ":" .. (p.name or "?"))
        end
    end
    if #out == 0 then return nil end
    table.sort(out)
    return table.concat(out, "+")
end

local function partnerLabel(myTeam)
    local me = UnitName("player")
    local parts = {}
    for _, p in ipairs(myTeam or {}) do
        if (p.name or "") ~= me then
            table.insert(parts, colorClass(p.name or "?", p.classFile))
        end
    end
    return table.concat(parts, " + ")
end

local function emptyBucket()
    return { games = 0, wins = 0, losses = 0, draws = 0, delta = 0 }
end

local function accumulate(b, rec)
    b.games = b.games + 1
    if rec.result == "win"  then b.wins   = b.wins   + 1
    elseif rec.result == "loss" then b.losses = b.losses + 1
    elseif rec.result == "draw" then b.draws  = b.draws  + 1 end
    if rec.ratingDelta then b.delta = b.delta + rec.ratingDelta end
end

local function bucketBy(matches, keyFn)
    local groups = {}
    local labels = {}
    for _, rec in ipairs(matches) do
        local k, label = keyFn(rec)
        if k then
            groups[k] = groups[k] or emptyBucket()
            labels[k] = labels[k] or label or k
            accumulate(groups[k], rec)
        end
    end
    local list = {}
    for k, g in pairs(groups) do
        table.insert(list, { key = k, label = labels[k], g = g })
    end
    table.sort(list, function(a, b)
        if a.g.games ~= b.g.games then return a.g.games > b.g.games end
        local wrA = a.g.wins / math.max(a.g.games, 1)
        local wrB = b.g.wins / math.max(b.g.games, 1)
        return wrA > wrB
    end)
    return list
end

local function winrateStr(g)
    if g.games == 0 then return "—" end
    return string.format("%.0f%%", 100 * g.wins / g.games)
end

local function deltaStr(g)
    if g.delta == 0 then return "" end
    local col = g.delta >= 0 and "|cff4fdd4f" or "|cffee4040"
    return string.format(" %s%+d|r", col, g.delta)
end

-- ------------------------------------------------------------
-- Widget helpers
-- ------------------------------------------------------------

local function makeFilterButton(parent, label, isOn, onClick)
    local b = Skin:CreateButton(parent, label, 60, 20)
    b:SetScript("OnClick", onClick)
    b._setActive = function(self, active)
        if active then
            self:SetBackdropColor(unpack(Skin.color.bgActive))
            self:SetBackdropBorderColor(unpack(Skin.color.accent))
            local fs = self:GetFontString(); if fs then fs:SetTextColor(unpack(Skin.color.accent)) end
        else
            self:SetBackdropColor(unpack(Skin.color.bgAlt))
            self:SetBackdropBorderColor(unpack(Skin.color.border))
            local fs = self:GetFontString(); if fs then fs:SetTextColor(unpack(Skin.color.textFg)) end
        end
    end
    b:_setActive(isOn)
    return b
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

-- A 4-column row pool: [label | games | W-L | win%/delta]
local function makeRowPool()
    return {}
end

local function ensureRow(pool, i, parent)
    if pool[i] then return pool[i] end
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(16)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.label:SetJustifyH("LEFT")

    row.games = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.games:SetPoint("RIGHT", row, "RIGHT", -190, 0)
    row.games:SetWidth(40); row.games:SetJustifyH("RIGHT")

    row.wl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.wl:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    row.wl:SetWidth(60); row.wl:SetJustifyH("RIGHT")

    row.wr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.wr:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.wr:SetWidth(100); row.wr:SetJustifyH("RIGHT")

    row.label:SetPoint("RIGHT", row.games, "LEFT", -6, 0)
    pool[i] = row
    return row
end

-- ------------------------------------------------------------
-- Build
-- ------------------------------------------------------------

local widgets

function SP:Build(parent)
    if widgets then return end
    widgets = {}
    widgets.parent = parent

    -- Filter strip ---------------------------------------------------------
    local filter = CreateFrame("Frame", nil, parent)
    filter:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, -10)
    filter:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    filter:SetHeight(22)
    widgets.filter = filter

    local fsLabel = filter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fsLabel:SetPoint("LEFT", filter, "LEFT", 0, 0)
    fsLabel:SetText((L["stats_bracket"] or "Bracket:"))
    fsLabel:SetTextColor(unpack(Skin.color.textDim))

    local bracketBtns = {}
    local bracketDefs = {
        { id = "all",      label = L["stats_all"]      or "All" },
        { id = "2v2",      label = "2v2" },
        { id = "3v3",      label = "3v3" },
        { id = "5v5",      label = "5v5" },
        { id = "Skirmish", label = L["bracket_skirmish"] or "Skirmish" },
    }
    local x = 50
    for _, d in ipairs(bracketDefs) do
        local b = makeFilterButton(filter, d.label, filterState.bracket == d.id, function()
            filterState.bracket = d.id
            SP:Refresh()
        end)
        b:SetPoint("LEFT", filter, "LEFT", x, 0)
        bracketBtns[d.id] = b
        x = x + 62
    end
    widgets.bracketBtns = bracketBtns

    local pLabel = filter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pLabel:SetPoint("LEFT", filter, "LEFT", x + 8, 0)
    pLabel:SetText((L["stats_period"] or "Period:"))
    pLabel:SetTextColor(unpack(Skin.color.textDim))
    x = x + 50

    local periodBtns = {}
    local periodDefs = {
        { id = "all",   label = L["stats_all"]      or "All"   },
        { id = "today", label = L["stats_today"]    or "Today" },
        { id = "week",  label = L["stats_week"]     or "Week"  },
        { id = "month", label = L["stats_month"]    or "Month" },
    }
    for _, d in ipairs(periodDefs) do
        local b = makeFilterButton(filter, d.label, filterState.period == d.id, function()
            filterState.period = d.id
            SP:Refresh()
        end)
        b:SetPoint("LEFT", filter, "LEFT", x + 8, 0)
        periodBtns[d.id] = b
        x = x + 62
    end
    widgets.periodBtns = periodBtns

    -- Summary --------------------------------------------------------------
    local summary = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", filter, "BOTTOMLEFT", 4, -8)
    summary:SetPoint("TOPRIGHT", filter, "BOTTOMRIGHT", -4, -8)
    summary:SetJustifyH("LEFT")
    summary:SetText("")
    widgets.summary = summary

    -- Sections (comps, maps, partners) ------------------------------------
    widgets.compsStrip   = sectionStrip(parent, L["stats_top_comps"] or "Top enemy comps")
    widgets.compsStrip:SetPoint("TOPLEFT",  summary, "BOTTOMLEFT",  -4, -10)
    widgets.compsStrip:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 4, -10)

    widgets.mapsStrip    = sectionStrip(parent, L["stats_maps"] or "Maps")
    widgets.partnersStrip= sectionStrip(parent, L["stats_partners"] or "Partners")

    widgets.compsArea    = CreateFrame("Frame", nil, parent)
    widgets.mapsArea     = CreateFrame("Frame", nil, parent)
    widgets.partnersArea = CreateFrame("Frame", nil, parent)
    widgets.compsArea:SetHeight(150)
    widgets.mapsArea:SetHeight(110)
    widgets.partnersArea:SetHeight(110)

    widgets.compsArea:SetPoint("TOPLEFT",     widgets.compsStrip, "BOTTOMLEFT",  0, -2)
    widgets.compsArea:SetPoint("TOPRIGHT",    widgets.compsStrip, "BOTTOMRIGHT", 0, -2)
    widgets.mapsStrip:SetPoint("TOPLEFT",     widgets.compsArea, "BOTTOMLEFT",  0, -8)
    widgets.mapsStrip:SetPoint("TOPRIGHT",    widgets.compsArea, "BOTTOMRIGHT", 0, -8)
    widgets.mapsArea:SetPoint("TOPLEFT",      widgets.mapsStrip, "BOTTOMLEFT",  0, -2)
    widgets.mapsArea:SetPoint("TOPRIGHT",     widgets.mapsStrip, "BOTTOMRIGHT", 0, -2)
    widgets.partnersStrip:SetPoint("TOPLEFT", widgets.mapsArea, "BOTTOMLEFT",  0, -8)
    widgets.partnersStrip:SetPoint("TOPRIGHT",widgets.mapsArea, "BOTTOMRIGHT", 0, -8)
    widgets.partnersArea:SetPoint("TOPLEFT",  widgets.partnersStrip, "BOTTOMLEFT",  0, -2)
    widgets.partnersArea:SetPoint("TOPRIGHT", widgets.partnersStrip, "BOTTOMRIGHT", 0, -2)

    widgets.compsPool    = makeRowPool()
    widgets.mapsPool     = makeRowPool()
    widgets.partnersPool = makeRowPool()

    widgets.emptyFS = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    widgets.emptyFS:SetPoint("CENTER", parent, "CENTER", 0, 0)
    widgets.emptyFS:SetText(L["no_matches"] or "")
end

-- ------------------------------------------------------------
-- Render
-- ------------------------------------------------------------

local function renderRows(area, pool, list, maxRows)
    local shown = math.min(#list, maxRows)
    for i = 1, shown do
        local row = ensureRow(pool, i, area)
        local item = list[i]
        row:Show()
        row:SetPoint("TOPLEFT",  area, "TOPLEFT",  0, -((i - 1) * 18))
        row:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -((i - 1) * 18))
        row.label:SetText(item.label or item.key or "?")
        row.games:SetText(tostring(item.g.games))
        row.wl:SetText(string.format("%d-%d", item.g.wins, item.g.losses))
        row.wr:SetText(winrateStr(item.g) .. deltaStr(item.g))
    end
    -- Hide leftover frames from a prior, larger dataset.
    for i = shown + 1, #pool do
        if pool[i] then pool[i]:Hide() end
    end
end

local function summaryText(matches)
    local total, wins, losses, draws = 0, 0, 0, 0
    local deltaByBracket = {}
    for _, rec in ipairs(matches) do
        total = total + 1
        if     rec.result == "win"  then wins   = wins   + 1
        elseif rec.result == "loss" then losses = losses + 1
        elseif rec.result == "draw" then draws  = draws  + 1 end
        if rec.ratingDelta and rec.bracket then
            deltaByBracket[rec.bracket] = (deltaByBracket[rec.bracket] or 0) + rec.ratingDelta
        end
    end
    local wr = total > 0 and string.format("%.1f%%", 100 * wins / total) or "—"
    local parts = {
        string.format("%s: %d", L["stats_total"] or "Total", total),
        string.format("|cff4fdd4f%s: %d|r", L["result_win"] or "W", wins),
        string.format("|cffee4040%s: %d|r", L["result_loss"] or "L", losses),
        string.format("|cffcccc55%s: %d|r", L["result_draw"] or "D", draws),
        string.format("|cffffd200%s: %s|r", L["stats_winrate"] or "Win%", wr),
    }
    local brStr = ""
    for _, br in ipairs({ "2v2", "3v3", "5v5" }) do
        local d = deltaByBracket[br]
        if d and d ~= 0 then
            local col = d >= 0 and "|cff4fdd4f" or "|cffee4040"
            brStr = brStr .. string.format("  %s %s%+d|r", br, col, d)
        end
    end
    return table.concat(parts, "   ") .. brStr
end

function SP:Refresh()
    if not widgets then return end

    -- Update filter button highlights (idempotent).
    for id, b in pairs(widgets.bracketBtns) do b:_setActive(id == filterState.bracket) end
    for id, b in pairs(widgets.periodBtns)  do b:_setActive(id == filterState.period)  end

    local all = MAT.Match and MAT.Match:GetAll() or {}
    local filtered = {}
    for _, rec in ipairs(all) do
        if matchPasses(rec) then table.insert(filtered, rec) end
    end

    widgets.summary:SetText(summaryText(filtered))
    widgets.emptyFS:SetShown(#filtered == 0)

    local comps = bucketBy(filtered, function(rec)
        local k = compKey(rec.enemyTeam)
        if k == "" then return nil end
        return k, compLabel(rec.enemyTeam)
    end)
    local maps = bucketBy(filtered, function(rec)
        local m = rec.map or "?"
        return m, m
    end)
    local partners = bucketBy(filtered, function(rec)
        if rec.bracket == "5v5" then return nil end  -- too many partners to be useful
        local k = partnerKey(rec.myTeam)
        if not k then return nil end
        return k, partnerLabel(rec.myTeam)
    end)

    renderRows(widgets.compsArea,    widgets.compsPool,    comps,    8)
    renderRows(widgets.mapsArea,     widgets.mapsPool,     maps,     6)
    renderRows(widgets.partnersArea, widgets.partnersPool, partners, 6)
end
