local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local UI = MAT.UI
local Skin = ns.Skin

-- ============================================================
-- Settings tab — exposes the toggles previously only reachable
-- via slash. HUD enable / lock / scale, post-match note, minimap.
--
-- Build(parent) is called once by MainPanel.getTabContent.
-- Refresh() repopulates control state from the DB (e.g. after
-- /mat hud lock changed the lock from outside the panel).
-- ============================================================

UI.SettingsPanel = UI.SettingsPanel or {}
local SP = UI.SettingsPanel

local controls   -- table populated in Build(); see Refresh()

-- ------------------------------------------------------------
-- Tiny widget helpers (kept here, not in Skin, because the
-- slider's named-subframe contract is awkward to expose
-- generically — promote to Skin if a second panel needs them.)
-- ------------------------------------------------------------

local uid = 0
local function uniqueName(prefix)
    uid = uid + 1
    return prefix .. uid
end

local function makeCheckbox(parent, label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    if cb.Text then cb.Text:SetText(label) end
    cb.refresh = function() cb:SetChecked(getter() and true or false) end
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    cb:refresh()
    return cb
end

local function makeSlider(parent, label, minV, maxV, step, getter, setter)
    local name = uniqueName("MATSettingsSlider")
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(180); s:SetHeight(18)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local labelFS = _G[name .. "Text"]
    local lowFS   = _G[name .. "Low"]
    local highFS  = _G[name .. "High"]
    if labelFS then labelFS:SetText(label) end
    if lowFS   then lowFS:SetText(string.format("%.1f", minV))  end
    if highFS  then highFS:SetText(string.format("%.1f", maxV)) end
    s.refresh = function()
        local v = getter() or minV
        s:SetValue(v)
        if labelFS then labelFS:SetText(string.format("%s: %.2f", label, v)) end
    end
    s:SetScript("OnValueChanged", function(self, v)
        setter(v)
        if labelFS then labelFS:SetText(string.format("%s: %.2f", label, v)) end
    end)
    s:refresh()
    return s
end

local function makeButton(parent, label, onClick)
    local b = Skin:CreateButton(parent, label, 140, 22)
    b:SetScript("OnClick", onClick)
    return b
end

-- ------------------------------------------------------------
-- Section header (single-line strip with title text)
-- ------------------------------------------------------------

local function sectionHeader(parent, text)
    local strip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin:ApplyDark(strip, Skin.color.bgAlt, Skin.color.borderLight)
    strip:SetHeight(20)
    local fs = strip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", strip, "LEFT", 8, 0)
    fs:SetText(text)
    fs:SetTextColor(unpack(Skin.color.accent))
    return strip
end

-- ------------------------------------------------------------
-- Build
-- ------------------------------------------------------------

local function ensureHudDb()
    MAT.db.profile.hud = MAT.db.profile.hud or {}
    local h = MAT.db.profile.hud
    if h.hidden == nil then h.hidden = false end
    if h.locked == nil then h.locked = true end
    if h.scale  == nil then h.scale  = 1.0  end
    return h
end

function SP:Build(parent)
    if controls then return end
    controls = {}

    -- === HUD section ===
    local hudHeader = sectionHeader(parent, L["settings_hud"] or "HUD overlay")
    hudHeader:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, -10)
    hudHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)

    controls.hudEnabled = makeCheckbox(parent,
        L["settings_hud_enabled"] or "Enable HUD in arenas",
        function() return not ensureHudDb().hidden end,
        function(v)
            if MAT.Hud then MAT.Hud:SetHidden(not v) else ensureHudDb().hidden = not v end
        end)
    controls.hudEnabled:SetPoint("TOPLEFT", hudHeader, "BOTTOMLEFT", 4, -6)

    controls.hudLocked = makeCheckbox(parent,
        L["settings_hud_locked"] or "Lock HUD position",
        function() return ensureHudDb().locked end,
        function(v)
            ensureHudDb().locked = v
            if MAT.Hud and MAT.Hud.ApplyLock then MAT.Hud:ApplyLock() end
        end)
    controls.hudLocked:SetPoint("TOPLEFT", controls.hudEnabled, "BOTTOMLEFT", 0, -2)

    controls.hudScale = makeSlider(parent,
        L["settings_hud_scale"] or "HUD scale",
        0.5, 2.0, 0.05,
        function() return ensureHudDb().scale or 1.0 end,
        function(v)
            local rounded = math.floor(v * 20 + 0.5) / 20
            ensureHudDb().scale = rounded
            if MAT.Hud and MAT.Hud.ApplyScale then MAT.Hud:ApplyScale() end
        end)
    controls.hudScale:SetPoint("TOPLEFT", controls.hudLocked, "BOTTOMLEFT", 4, -16)

    controls.hudReset = makeButton(parent,
        L["settings_hud_reset"] or "Reset HUD position",
        function() if MAT.Hud then MAT.Hud:ResetPosition() end end)
    controls.hudReset:SetPoint("TOPLEFT", controls.hudScale, "BOTTOMLEFT", -4, -10)

    controls.hudTest = makeButton(parent,
        L["settings_hud_test"] or "Toggle HUD test mode",
        function() if MAT.Hud then MAT.Hud:ToggleTest() end end)
    controls.hudTest:SetPoint("LEFT", controls.hudReset, "RIGHT", 8, 0)

    -- === Match feed section ===
    local feedHeader = sectionHeader(parent, L["settings_feed"] or "Match feed")
    feedHeader:SetPoint("TOPLEFT",  controls.hudReset, "BOTTOMLEFT",  -4, -16)
    feedHeader:SetPoint("RIGHT",    parent, "RIGHT",                  -10, 0)

    controls.askForNote = makeCheckbox(parent,
        L["settings_ask_note"] or "Ask for a note after each match",
        function()
            MAT.db.profile.postMatch = MAT.db.profile.postMatch or {}
            return MAT.db.profile.postMatch.askForNote ~= false
        end,
        function(v)
            MAT.db.profile.postMatch = MAT.db.profile.postMatch or {}
            MAT.db.profile.postMatch.askForNote = v
        end)
    controls.askForNote:SetPoint("TOPLEFT", feedHeader, "BOTTOMLEFT", 4, -6)

    -- === Minimap section ===
    local miniHeader = sectionHeader(parent, L["settings_minimap"] or "Minimap")
    miniHeader:SetPoint("TOPLEFT",  controls.askForNote, "BOTTOMLEFT",  -4, -16)
    miniHeader:SetPoint("RIGHT",    parent, "RIGHT",                    -10, 0)

    controls.minimap = makeCheckbox(parent,
        L["settings_minimap_show"] or "Show minimap button",
        function()
            MAT.db.profile.minimap = MAT.db.profile.minimap or {}
            return not MAT.db.profile.minimap.hide
        end,
        function(v)
            MAT.db.profile.minimap = MAT.db.profile.minimap or {}
            MAT.db.profile.minimap.hide = not v
            local Icon = LibStub("LibDBIcon-1.0", true)
            if Icon then
                if v then Icon:Show(ADDON_NAME) else Icon:Hide(ADDON_NAME) end
            end
        end)
    controls.minimap:SetPoint("TOPLEFT", miniHeader, "BOTTOMLEFT", 4, -6)
end

-- ------------------------------------------------------------
-- Refresh — re-read DB after external changes (slash commands).
-- ------------------------------------------------------------

function SP:Refresh()
    if not controls then return end
    for _, c in pairs(controls) do
        if c.refresh then c:refresh() end
    end
end
