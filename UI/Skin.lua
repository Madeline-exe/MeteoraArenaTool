local ADDON_NAME, ns = ...

ns.Skin = ns.Skin or {}
local Skin = ns.Skin

-- ============================================================
-- Palette (ElvUI/DBM-like dark theme)
-- ============================================================

Skin.color = {
    bg          = { 0.06, 0.06, 0.07, 0.96 },
    bgAlt       = { 0.10, 0.10, 0.12, 0.95 },
    bgHover     = { 0.16, 0.16, 0.20, 0.95 },
    bgActive    = { 0.20, 0.30, 0.50, 0.90 },
    border      = { 0.22, 0.22, 0.26, 1.00 },
    borderLight = { 0.36, 0.36, 0.42, 1.00 },
    accent      = { 1.00, 0.82, 0.00, 1.00 },  -- gold
    accentSoft  = { 1.00, 0.55, 0.00, 1.00 },  -- amber for SR
    success     = { 0.30, 0.85, 0.30, 1.00 },
    danger      = { 0.95, 0.30, 0.30, 1.00 },
    textFg      = { 0.92, 0.92, 0.95, 1.00 },
    textDim     = { 0.55, 0.55, 0.60, 1.00 },
}

local WHITE  = "Interface\\Buttons\\WHITE8x8"
local BLANK  = "Interface\\Buttons\\WHITE8x8"

-- ============================================================
-- Backdrop helpers
-- ============================================================

-- 2.5.x: Frames don't auto-include SetBackdrop. Use BackdropTemplate mixin.
local function ensureBackdrop(frame)
    if frame.SetBackdrop then return frame end
    Mixin(frame, BackdropTemplateMixin)
    return frame
end

function Skin:ApplyDark(frame, bgColor, borderColor)
    ensureBackdrop(frame)
    frame:SetBackdrop({
        bgFile   = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local bg = bgColor or self.color.bg
    local bd = borderColor or self.color.border
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
    return frame
end

function Skin:CreatePanel(parent, w, h)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(w or 200, h or 100)
    self:ApplyDark(f)
    return f
end

-- ============================================================
-- Buttons
-- ============================================================

function Skin:CreateButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 110, h or 22)
    self:ApplyDark(b, self.color.bgAlt, self.color.border)
    b:SetNormalFontObject("GameFontNormal")
    b:SetHighlightFontObject("GameFontHighlight")
    b:SetDisabledFontObject("GameFontDisable")
    b:SetText(text or "")

    local fs = b:GetFontString()
    if fs then fs:SetPoint("CENTER", b, "CENTER", 0, 0) end

    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(Skin.color.bgHover[1], Skin.color.bgHover[2],
                              Skin.color.bgHover[3], Skin.color.bgHover[4])
        self:SetBackdropBorderColor(Skin.color.borderLight[1], Skin.color.borderLight[2],
                                    Skin.color.borderLight[3], Skin.color.borderLight[4])
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(Skin.color.bgAlt[1], Skin.color.bgAlt[2],
                              Skin.color.bgAlt[3], Skin.color.bgAlt[4])
        self:SetBackdropBorderColor(Skin.color.border[1], Skin.color.border[2],
                                    Skin.color.border[3], Skin.color.border[4])
    end)
    return b
end

-- A square icon-only toggle button with an item-icon texture.
function Skin:CreateIconButton(parent, size)
    size = size or 28
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size, size)
    self:ApplyDark(b, self.color.bgAlt, self.color.border)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = tex
    return b
end

-- ============================================================
-- Section: a collapsible boss header above its content frame.
-- Returns a Section table with: frame, header, content, expand/collapse, setTitle.
-- Caller arranges content frame children; setHeight on content auto-resizes section.
-- ============================================================

function Skin:CreateSection(parent, initiallyExpanded)
    local section = {}
    section.expanded = initiallyExpanded ~= false

    section.frame = CreateFrame("Frame", nil, parent)
    section.frame:SetHeight(24)

    section.header = CreateFrame("Button", nil, section.frame, "BackdropTemplate")
    section.header:SetPoint("TOPLEFT", section.frame, "TOPLEFT", 0, 0)
    section.header:SetPoint("TOPRIGHT", section.frame, "TOPRIGHT", 0, 0)
    section.header:SetHeight(22)
    self:ApplyDark(section.header, self.color.bgAlt, self.color.border)

    section.toggle = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.toggle:SetPoint("LEFT", section.header, "LEFT", 6, 0)
    section.toggle:SetText(section.expanded and "[-]" or "[+]")
    section.toggle:SetTextColor(unpack(self.color.accent))

    section.title = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    section.title:SetPoint("LEFT", section.toggle, "RIGHT", 8, 0)
    section.title:SetTextColor(unpack(self.color.textFg))

    section.meta = section.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.meta:SetPoint("RIGHT", section.header, "RIGHT", -8, 0)
    section.meta:SetTextColor(unpack(self.color.textDim))

    section.content = CreateFrame("Frame", nil, section.frame)
    section.content:SetPoint("TOPLEFT", section.header, "BOTTOMLEFT", 0, -2)
    section.content:SetPoint("TOPRIGHT", section.header, "BOTTOMRIGHT", 0, -2)
    section.content:SetHeight(1)

    function section:SetTitle(t) self.title:SetText(t or "") end
    function section:SetMeta(t)  self.meta:SetText(t or "")  end

    function section:Layout(contentHeight)
        if self.expanded then
            self.content:Show()
            self.content:SetHeight(contentHeight or 1)
            self.frame:SetHeight(22 + 2 + (contentHeight or 1))
        else
            self.content:Hide()
            self.frame:SetHeight(22)
        end
    end

    section.header:SetScript("OnClick", function()
        section.expanded = not section.expanded
        section.toggle:SetText(section.expanded and "[-]" or "[+]")
        if section.onToggle then section.onToggle(section.expanded) end
    end)
    section.header:SetScript("OnEnter", function(h)
        h:SetBackdropColor(Skin.color.bgHover[1], Skin.color.bgHover[2],
                           Skin.color.bgHover[3], Skin.color.bgHover[4])
    end)
    section.header:SetScript("OnLeave", function(h)
        h:SetBackdropColor(Skin.color.bgAlt[1], Skin.color.bgAlt[2],
                           Skin.color.bgAlt[3], Skin.color.bgAlt[4])
    end)

    return section
end

-- ============================================================
-- Class-coloured player name (works on any player name, falls
-- back to plain if class lookup fails).
-- ============================================================

-- ============================================================
-- UTF-8 aware text helpers (used by export tables — Lua's %-Ns
-- counts bytes, so Cyrillic names break column alignment).
-- ============================================================

function Skin.utf8len(s)
    if not s or s == "" then return 0 end
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

function Skin.utf8truncate(s, maxChars)
    if not s then return "" end
    local len = Skin.utf8len(s)
    if len <= maxChars then return s end
    local out, count = "", 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if count >= maxChars - 3 then break end
        out = out .. ch
        count = count + 1
    end
    return out .. "..."
end

function Skin.padRight(s, width)
    s = tostring(s or "")
    local n = Skin.utf8len(s)
    if n >= width then return Skin.utf8truncate(s, width) end
    return s .. string.rep(" ", width - n)
end

function Skin.padLeft(s, width)
    s = tostring(s or "")
    local n = Skin.utf8len(s)
    if n >= width then return Skin.utf8truncate(s, width) end
    return string.rep(" ", width - n) .. s
end

function Skin:ColorName(name)
    if not name or name == "" then return name or "?" end
    local _, class
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitName("raid" .. i) == name then
                _, class = UnitClass("raid" .. i); break
            end
        end
    end
    if not class then
        for i = 1, (GetNumGroupMembers() or 0) - 1 do
            if UnitName("party" .. i) == name then
                _, class = UnitClass("party" .. i); break
            end
        end
    end
    if not class and UnitName("player") == name then _, class = UnitClass("player") end
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return string.format("|c%s%s|r", c.colorStr, name) end
    return name
end
