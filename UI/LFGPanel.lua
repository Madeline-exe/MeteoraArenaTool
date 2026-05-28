local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local UI = MAT.UI
local Skin = ns.Skin

-- ============================================================
-- LFG tab. Top: form to post our own LFG/LFM listing. Bottom:
-- scrollable feed of listings broadcast by other addon users
-- in the hidden "MeteoraArena" channel.
--
-- Module exposes UI.LFGPanel:Build(container) and :Refresh()
-- so MainPanel can lazy-build/refresh this tab the same way
-- as Feed.
-- ============================================================

local LFGPanel = {}
UI.LFGPanel = LFGPanel

local CLASS_COLOR_HEX = {
    WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST  = "FFFFFF", DEATHKNIGHT = "C41F3B", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", DRUID = "FF7D0A",
}

local CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local CLASS_SHORT = {
    WARRIOR = "War", PALADIN = "Pal", HUNTER = "Hun", ROGUE = "Rog", PRIEST = "Pri",
    SHAMAN  = "Sha", MAGE    = "Mag", WARLOCK = "Lck", DRUID = "Dru",
}

local BRACKETS = { "2v2", "3v3", "5v5", "Skirmish" }
local KINDS    = { "LFG", "LFM" }

local function colorClassName(name, classFile)
    if not name then return "?" end
    local hex = classFile and CLASS_COLOR_HEX[classFile]
    if hex then return "|cff" .. hex .. name .. "|r" end
    return name
end

local function colorClassShort(classFile)
    local short = CLASS_SHORT[classFile] or "?"
    local hex = CLASS_COLOR_HEX[classFile]
    if hex then return "|cff" .. hex .. short .. "|r" end
    return short
end

local function timeAgo(epoch)
    if not epoch then return "?" end
    local d = time() - epoch
    if d < 60 then return d .. "s"
    elseif d < 3600 then return math.floor(d / 60) .. "m"
    else return math.floor(d / 3600) .. "h" end
end

local function timeLeft(epoch)
    if not epoch then return "?" end
    local d = epoch - time()
    if d <= 0 then return "0m" end
    if d < 60 then return d .. "s"
    elseif d < 3600 then return math.floor(d / 60) .. "m"
    else return math.floor(d / 3600) .. "h" end
end

-- ------------------------------------------------------------
-- Toggle-style button group helper
-- ------------------------------------------------------------

local function styleToggle(btn, isOn)
    if isOn then
        btn:SetBackdropColor(Skin.color.bgActive[1], Skin.color.bgActive[2],
                             Skin.color.bgActive[3], Skin.color.bgActive[4])
        btn:SetBackdropBorderColor(Skin.color.accent[1], Skin.color.accent[2],
                                   Skin.color.accent[3], Skin.color.accent[4])
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(unpack(Skin.color.accent)) end
    else
        btn:SetBackdropColor(Skin.color.bgAlt[1], Skin.color.bgAlt[2],
                             Skin.color.bgAlt[3], Skin.color.bgAlt[4])
        btn:SetBackdropBorderColor(Skin.color.border[1], Skin.color.border[2],
                                   Skin.color.border[3], Skin.color.border[4])
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(unpack(Skin.color.textFg)) end
    end
end

-- Skin:CreateButton attaches hover handlers that hard-reset backdrop to
-- bgAlt/border — that clobbers our "active" styling. For toggle buttons
-- we override OnEnter/OnLeave to respect a live isActive() predicate so
-- mouse-over never strips the accent away from the selected option.
local function bindToggleHover(btn, isActiveFn)
    btn:SetScript("OnEnter", function(self)
        if isActiveFn() then
            self:SetBackdropColor(0.28, 0.38, 0.58, 0.95)
            self:SetBackdropBorderColor(Skin.color.accent[1], Skin.color.accent[2],
                                        Skin.color.accent[3], Skin.color.accent[4])
        else
            self:SetBackdropColor(Skin.color.bgHover[1], Skin.color.bgHover[2],
                                  Skin.color.bgHover[3], Skin.color.bgHover[4])
            self:SetBackdropBorderColor(Skin.color.borderLight[1], Skin.color.borderLight[2],
                                        Skin.color.borderLight[3], Skin.color.borderLight[4])
        end
    end)
    btn:SetScript("OnLeave", function(self)
        styleToggle(self, isActiveFn())
    end)
end

-- ------------------------------------------------------------
-- Form state — kept in module, persisted via Post()
-- ------------------------------------------------------------

local form = {
    kind        = "LFG",
    bracket     = "2v2",
    myRating    = nil,
    wantClasses = {},
    comment     = "",
    expiryMin   = 30,
}

local widgets = {}  -- map of important widgets so Refresh can update them
local builtOnce = false

local function selectedClassesAsSet()
    local s = {}
    for _, c in ipairs(form.wantClasses) do s[c] = true end
    return s
end

local function toggleClass(c)
    local s = selectedClassesAsSet()
    if s[c] then
        s[c] = nil
        for i = #form.wantClasses, 1, -1 do
            if form.wantClasses[i] == c then table.remove(form.wantClasses, i) end
        end
    else
        table.insert(form.wantClasses, c)
    end
end

local function loadFormFromMy()
    local my = MAT.LFG and MAT.LFG:GetMyListing() or nil
    if not my then return end
    form.kind        = my.kind or "LFG"
    form.bracket     = my.bracket or "2v2"
    form.myRating    = my.myRating
    form.wantClasses = {}
    for _, c in ipairs(my.wantClasses or {}) do table.insert(form.wantClasses, c) end
    form.comment     = my.comment or ""
    if my.expiresAt and my.createdAt then
        form.expiryMin = math.max(5, math.floor((my.expiresAt - my.createdAt) / 60))
    end
end

-- ------------------------------------------------------------
-- Listing row pool
-- ------------------------------------------------------------

local listingRows = {}

local function ensureRow(i, parent)
    if listingRows[i] then return listingRows[i] end
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
    row.when:SetPoint("LEFT", row, "LEFT", 6, 0); row.when:SetWidth(38); row.when:SetJustifyH("LEFT")

    row.kind    = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.kind:SetPoint("LEFT", row.when, "RIGHT", 4, 0); row.kind:SetWidth(40); row.kind:SetJustifyH("LEFT")

    row.who     = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.who:SetPoint("LEFT", row.kind, "RIGHT", 4, 0); row.who:SetWidth(150); row.who:SetJustifyH("LEFT")

    row.bracket = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.bracket:SetPoint("LEFT", row.who, "RIGHT", 4, 0); row.bracket:SetWidth(60); row.bracket:SetJustifyH("LEFT")

    row.rating  = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rating:SetPoint("LEFT", row.bracket, "RIGHT", 4, 0); row.rating:SetWidth(60); row.rating:SetJustifyH("LEFT")

    row.wants   = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.wants:SetPoint("LEFT", row.rating, "RIGHT", 4, 0); row.wants:SetWidth(150); row.wants:SetJustifyH("LEFT")

    row.comment = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.comment:SetPoint("LEFT", row.wants, "RIGHT", 6, 0)
    row.comment:SetPoint("RIGHT", row, "RIGHT", -76, 0)
    row.comment:SetJustifyH("LEFT")
    row.comment:SetWordWrap(false)

    row.whisper = Skin:CreateButton(row, L["lfg_whisper"] or "Whisper", 68, 18)
    row.whisper:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    listingRows[i] = row
    return row
end

local function passesFilter(entry)
    local lfg = MAT.db.profile.lfg
    local l = entry.listing
    if lfg.filterBracket and lfg.filterBracket ~= "all" then
        if l.bracket ~= lfg.filterBracket then return false end
    end
    return true
end

-- ------------------------------------------------------------
-- Build
-- ------------------------------------------------------------

local container, listingScroll, listingChild, listingEmpty
local statusFS

local function buildForm(parent, yTop)
    -- Form panel
    local form_bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(form_bg, Skin.color.bgAlt, Skin.color.borderLight)
    form_bg:SetPoint("TOPLEFT",  parent, "TOPLEFT",  4, yTop)
    form_bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yTop)
    form_bg:SetHeight(176)

    local title = form_bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 8, -6)
    title:SetText(L["lfg_my_listing"] or "My listing")
    title:SetTextColor(unpack(Skin.color.accent))

    -- Row 1: kind + bracket
    local rowY = -26
    local x = 8
    widgets.kindBtns = {}
    for _, k in ipairs(KINDS) do
        local captured = k
        local b = Skin:CreateButton(form_bg, captured, 50, 22)
        b:SetPoint("TOPLEFT", form_bg, "TOPLEFT", x, rowY)
        b:SetScript("OnClick", function() form.kind = captured; LFGPanel:Refresh() end)
        bindToggleHover(b, function() return form.kind == captured end)
        widgets.kindBtns[captured] = b
        x = x + 52
    end

    -- Fixed x for "Bracket:" label — GetStringWidth() can return 0 before
    -- layout, which shifted the bracket buttons under the label on first show.
    local bracketLabel = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bracketLabel:SetPoint("LEFT", form_bg, "TOPLEFT", 128, rowY - 11)
    bracketLabel:SetText(L["lfg_bracket"] or "Bracket:")
    x = 184

    widgets.bracketBtns = {}
    for _, b_ in ipairs(BRACKETS) do
        local captured = b_
        local b = Skin:CreateButton(form_bg, captured, 64, 22)
        b:SetPoint("TOPLEFT", form_bg, "TOPLEFT", x, rowY)
        b:SetScript("OnClick", function() form.bracket = captured; LFGPanel:Refresh() end)
        bindToggleHover(b, function() return form.bracket == captured end)
        widgets.bracketBtns[captured] = b
        x = x + 66
    end

    -- Row 2: my rating + expiry
    rowY = rowY - 28
    local ratingLabel = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ratingLabel:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 8, rowY - 6)
    ratingLabel:SetText(L["lfg_my_rating"] or "My rating:")

    local ratingBox = CreateFrame("Frame", nil, form_bg, "BackdropTemplate")
    Skin:ApplyDark(ratingBox, Skin.color.bg, Skin.color.border)
    ratingBox:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 88, rowY)
    ratingBox:SetSize(70, 22)
    local ratingEdit = CreateFrame("EditBox", nil, ratingBox)
    ratingEdit:SetFontObject("ChatFontNormal")
    ratingEdit:SetPoint("TOPLEFT", ratingBox, "TOPLEFT", 6, -3)
    ratingEdit:SetPoint("BOTTOMRIGHT", ratingBox, "BOTTOMRIGHT", -6, 3)
    ratingEdit:SetAutoFocus(false)
    ratingEdit:SetMaxLetters(4)
    ratingEdit:SetNumeric(true)
    ratingEdit:SetScript("OnTextChanged", function(self)
        local n = tonumber(self:GetText())
        form.myRating = n and n > 0 and n or nil
    end)
    ratingEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ratingEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    widgets.ratingEdit = ratingEdit

    local autoBtn = Skin:CreateButton(form_bg, L["lfg_auto"] or "Auto", 50, 22)
    autoBtn:SetPoint("LEFT", ratingBox, "RIGHT", 6, 0)
    autoBtn:SetScript("OnClick", function()
        local t = form.bracket
        local teamSize = (t == "2v2") and 2 or (t == "3v3") and 3 or (t == "5v5") and 5 or nil
        if teamSize and MAT.GetTeamRating then
            local r = MAT:GetTeamRating(teamSize)
            if r and r > 0 then
                form.myRating = r
                ratingEdit:SetText(tostring(r))
            end
        end
    end)

    local expLabel = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    expLabel:SetPoint("LEFT", autoBtn, "RIGHT", 18, 0)
    expLabel:SetText(L["lfg_expiry"] or "Expires in:")

    local expBox = CreateFrame("Frame", nil, form_bg, "BackdropTemplate")
    Skin:ApplyDark(expBox, Skin.color.bg, Skin.color.border)
    expBox:SetPoint("LEFT", expLabel, "RIGHT", 6, 0)
    expBox:SetSize(50, 22)
    local expEdit = CreateFrame("EditBox", nil, expBox)
    expEdit:SetFontObject("ChatFontNormal")
    expEdit:SetPoint("TOPLEFT", expBox, "TOPLEFT", 6, -3)
    expEdit:SetPoint("BOTTOMRIGHT", expBox, "BOTTOMRIGHT", -6, 3)
    expEdit:SetAutoFocus(false)
    expEdit:SetMaxLetters(3)
    expEdit:SetNumeric(true)
    expEdit:SetText(tostring(form.expiryMin))
    expEdit:SetScript("OnTextChanged", function(self)
        local n = tonumber(self:GetText())
        if n and n > 0 then form.expiryMin = n end
    end)
    expEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    expEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    widgets.expEdit = expEdit

    local minLabel = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minLabel:SetPoint("LEFT", expBox, "RIGHT", 4, 0)
    minLabel:SetText(L["lfg_minutes"] or "min")

    -- Row 3: wantClasses
    rowY = rowY - 28
    local wantLabel = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wantLabel:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 8, rowY - 6)
    wantLabel:SetText(L["lfg_looking_for"] or "Looking for:")

    x = 88
    widgets.classBtns = {}
    for _, c in ipairs(CLASSES) do
        local captured = c
        local b = Skin:CreateButton(form_bg, colorClassShort(captured), 40, 22)
        b:SetPoint("TOPLEFT", form_bg, "TOPLEFT", x, rowY)
        b:SetScript("OnClick", function() toggleClass(captured); LFGPanel:Refresh() end)
        bindToggleHover(b, function()
            for _, c2 in ipairs(form.wantClasses) do
                if c2 == captured then return true end
            end
            return false
        end)
        widgets.classBtns[captured] = b
        x = x + 42
    end

    local anyBtn = Skin:CreateButton(form_bg, L["lfg_any"] or "Any", 48, 22)
    anyBtn:SetPoint("TOPLEFT", form_bg, "TOPLEFT", x + 6, rowY)
    anyBtn:SetScript("OnClick", function()
        form.wantClasses = {}
        LFGPanel:Refresh()
    end)

    -- Row 4: comment
    rowY = rowY - 28
    local cmtLabel = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmtLabel:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 8, rowY - 6)
    cmtLabel:SetText(L["lfg_comment"] or "Comment:")

    local cmtBox = CreateFrame("Frame", nil, form_bg, "BackdropTemplate")
    Skin:ApplyDark(cmtBox, Skin.color.bg, Skin.color.border)
    cmtBox:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 88, rowY)
    cmtBox:SetPoint("TOPRIGHT", form_bg, "TOPRIGHT", -8, rowY)
    cmtBox:SetHeight(22)
    local cmtEdit = CreateFrame("EditBox", nil, cmtBox)
    cmtEdit:SetFontObject("ChatFontNormal")
    cmtEdit:SetPoint("TOPLEFT", cmtBox, "TOPLEFT", 6, -3)
    cmtEdit:SetPoint("BOTTOMRIGHT", cmtBox, "BOTTOMRIGHT", -6, 3)
    cmtEdit:SetAutoFocus(false)
    cmtEdit:SetMaxLetters(120)
    cmtEdit:SetScript("OnTextChanged", function(self) form.comment = self:GetText() or "" end)
    cmtEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    cmtEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    widgets.cmtEdit = cmtEdit

    -- Row 5: Post / Clear + status
    rowY = rowY - 28
    local postBtn = Skin:CreateButton(form_bg, L["lfg_post"] or "Post", 80, 22)
    postBtn:SetPoint("TOPLEFT", form_bg, "TOPLEFT", 8, rowY)
    postBtn:SetScript("OnClick", function()
        if not MAT.LFG then return end
        MAT.LFG:Post({
            kind        = form.kind,
            bracket     = form.bracket,
            myRating    = form.myRating,
            wantClasses = form.wantClasses,
            comment     = form.comment,
            expiryMin   = form.expiryMin,
        })
    end)

    local clearBtn = Skin:CreateButton(form_bg, L["lfg_clear"] or "Clear", 80, 22)
    clearBtn:SetPoint("LEFT", postBtn, "RIGHT", 6, 0)
    clearBtn:SetScript("OnClick", function()
        if MAT.LFG then MAT.LFG:Clear() end
    end)

    statusFS = form_bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusFS:SetPoint("LEFT", clearBtn, "RIGHT", 16, 0)
    statusFS:SetText("")

    return form_bg
end

local function buildFilters(parent, anchorTo)
    local strip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(strip, Skin.color.bgAlt, Skin.color.borderLight)
    strip:SetPoint("TOPLEFT",  anchorTo, "BOTTOMLEFT",  0, -6)
    strip:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, -6)
    strip:SetHeight(28)

    local label = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", strip, "LEFT", 8, 0)
    label:SetText(L["lfg_listings"] or "Active listings")
    label:SetTextColor(unpack(Skin.color.accent))

    -- Single filter: bracket. Rating + class filtering was overkill for v0.2.x;
    -- the form already constrains who you'll match with via wantClasses, and
    -- raw rating-range filtering on the receive side made the strip too dense.
    local x = 180

    widgets.filterBracketBtns = {}
    local options = { "all", "2v2", "3v3", "5v5", "Skirmish" }
    for _, opt in ipairs(options) do
        local captured = opt
        local lbl = (captured == "all") and (L["lfg_all"] or "All") or captured
        local b = Skin:CreateButton(strip, lbl, 56, 22)
        b:SetPoint("LEFT", strip, "LEFT", x, 0)
        b:SetScript("OnClick", function()
            MAT.db.profile.lfg.filterBracket = captured
            LFGPanel:Refresh()
        end)
        bindToggleHover(b, function() return (MAT.db.profile.lfg.filterBracket or "all") == captured end)
        widgets.filterBracketBtns[captured] = b
        x = x + 58
    end

    local refreshBtn = Skin:CreateButton(strip, L["lfg_refresh"] or "Refresh", 80, 22)
    refreshBtn:SetPoint("RIGHT", strip, "RIGHT", -4, 0)
    refreshBtn:SetScript("OnClick", function()
        if MAT.LFG then MAT.LFG:RequestPing() end
        LFGPanel:Refresh()
    end)

    return strip
end

function LFGPanel:Build(parent)
    if builtOnce then return end
    container = parent

    loadFormFromMy()

    local formFrame = buildForm(parent, -4)
    local filterStrip = buildFilters(parent, formFrame)

    -- Header strip for listings
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(header, Skin.color.bgAlt, Skin.color.borderLight)
    header:SetPoint("TOPLEFT",  filterStrip, "BOTTOMLEFT",  0, -2)
    header:SetPoint("TOPRIGHT", filterStrip, "BOTTOMRIGHT", 0, -2)
    header:SetHeight(20)

    local function hCol(text, left, width)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", header, "LEFT", left, 0)
        fs:SetWidth(width); fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(unpack(Skin.color.accent))
        return fs
    end
    hCol(L["lfg_col_age"]     or "Age",     6,   38)
    hCol(L["lfg_col_kind"]    or "Type",    48,  40)
    hCol(L["lfg_col_who"]     or "Player",  92,  150)
    hCol(L["lfg_col_bracket"] or "Bracket", 246, 60)
    hCol(L["lfg_col_rating"]  or "Rating",  310, 60)
    hCol(L["lfg_col_wants"]   or "Wants",   374, 150)
    hCol(L["lfg_col_comment"] or "Comment", 528, 180)

    -- Scrollable list
    listingScroll = CreateFrame("ScrollFrame", "MATLFGScroll", parent, "UIPanelScrollFrameTemplate")
    listingScroll:SetPoint("TOPLEFT",     header, "BOTTOMLEFT", 0, -2)
    listingScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 4)

    listingChild = CreateFrame("Frame", nil, listingScroll)
    listingChild:SetSize(1, 1)
    listingScroll:SetScrollChild(listingChild)

    listingEmpty = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    listingEmpty:SetPoint("CENTER", listingScroll, "CENTER", 0, 0)
    listingEmpty:SetText(L["lfg_no_listings"] or "")

    builtOnce = true
end

-- ------------------------------------------------------------
-- Refresh
-- ------------------------------------------------------------

local function refreshForm()
    if not widgets.kindBtns then return end
    for k, b in pairs(widgets.kindBtns)    do styleToggle(b, k == form.kind) end
    for k, b in pairs(widgets.bracketBtns) do styleToggle(b, k == form.bracket) end
    local s = selectedClassesAsSet()
    for c, b in pairs(widgets.classBtns)   do styleToggle(b, s[c] == true) end

    if widgets.ratingEdit then
        local cur = tostring(form.myRating or "")
        if widgets.ratingEdit:GetText() ~= cur then widgets.ratingEdit:SetText(cur) end
    end
    if widgets.cmtEdit then
        if widgets.cmtEdit:GetText() ~= (form.comment or "") then
            widgets.cmtEdit:SetText(form.comment or "")
        end
    end
    if widgets.expEdit then
        local cur = tostring(form.expiryMin or 30)
        if widgets.expEdit:GetText() ~= cur then widgets.expEdit:SetText(cur) end
    end

    -- Status
    if statusFS then
        if MAT.LFG and MAT.LFG:IsActive() then
            local my = MAT.LFG:GetMyListing()
            statusFS:SetText(string.format("|cff4fdd4f%s|r %s %s",
                L["lfg_status_active"] or "Active",
                L["lfg_expires_in"] or "expires in",
                timeLeft(my.expiresAt)))
        else
            statusFS:SetText("|cff888888" .. (L["lfg_status_idle"] or "Not posted") .. "|r")
        end
    end
end

local function refreshFilters()
    if widgets.filterBracketBtns then
        local active = MAT.db.profile.lfg.filterBracket or "all"
        for k, b in pairs(widgets.filterBracketBtns) do styleToggle(b, k == active) end
    end
end

local function wantsToText(want)
    if not want or #want == 0 then return "|cff888888" .. (L["lfg_any"] or "Any") .. "|r" end
    local parts = {}
    for _, c in ipairs(want) do table.insert(parts, colorClassShort(c)) end
    return table.concat(parts, " ")
end

local function refreshList()
    if not listingChild then return end
    local entries = MAT.LFG and MAT.LFG:GetListings() or {}
    local filtered = {}
    for _, e in ipairs(entries) do
        if passesFilter(e) then table.insert(filtered, e) end
    end

    listingEmpty:SetShown(#filtered == 0)

    local rowH = 22
    local pad  = 2
    local width = listingScroll:GetWidth()
    listingChild:SetSize(math.max(width, 1), math.max(#filtered * (rowH + pad), 1))

    for i, entry in ipairs(filtered) do
        local row = ensureRow(i, listingChild)
        row:Show()
        row:SetPoint("TOPLEFT",  listingChild, "TOPLEFT",  0, -((i - 1) * (rowH + pad)))
        row:SetPoint("TOPRIGHT", listingChild, "TOPRIGHT", 0, -((i - 1) * (rowH + pad)))

        local l = entry.listing
        row.when:SetText(timeAgo(l.createdAt))
        if l.kind == "LFG" then
            row.kind:SetText("|cff69ccf0LFG|r")
        else
            row.kind:SetText("|cffffd200LFM|r")
        end
        row.who:SetText(colorClassName(entry.name, l.myClassFile))
        row.bracket:SetText(l.bracket or "?")
        row.rating:SetText(l.myRating and tostring(l.myRating) or "-")
        row.wants:SetText(wantsToText(l.wantClasses))
        row.comment:SetText(l.comment or "")

        local target = entry.sender or entry.name
        row.whisper:SetScript("OnClick", function()
            if ChatFrame_SendTell then
                ChatFrame_SendTell(target, ChatFrame1)
            elseif ChatFrame_OpenChat then
                ChatFrame_OpenChat("/w " .. target .. " ")
            end
        end)
        row:SetScript("OnClick", function() row.whisper:Click() end)
    end

    for i = #filtered + 1, #listingRows do
        if listingRows[i] then listingRows[i]:Hide() end
    end
end

function LFGPanel:Refresh()
    if not builtOnce then return end
    refreshForm()
    refreshFilters()
    refreshList()
end

-- ------------------------------------------------------------
-- AceEvent module wiring so we refresh when listings update
-- ------------------------------------------------------------

local LFGUI = MAT:NewModule("LFGUI", "AceEvent-3.0")
function LFGUI:OnEnable()
    self:RegisterMessage("MAT_LFG_UPDATED", "OnUpdate")
    -- live "expires in" countdown — cheap, only ticks the status string
    self.tickTimer = self.tickTimer or C_Timer.NewTicker(5, function()
        if builtOnce then LFGPanel:Refresh() end
    end)
end
function LFGUI:OnUpdate()
    if UI.RefreshLater then UI:RefreshLater() end
end
