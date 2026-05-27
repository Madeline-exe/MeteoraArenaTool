local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L
local Skin = ns.Skin

-- ============================================================
-- Post-match note dialog. Pops up after MAT_MATCH_RECORDED
-- (if the user opted into post-match prompts) and also opens
-- on demand from the Feed tab (UI:OpenNoteFor).
-- ============================================================

local UI = MAT.UI
local dialog, headerFS, bodyEdit, saveBtn, skipBtn
local currentMatchId

local function build()
    if dialog then return end

    dialog = CreateFrame("Frame", "MeteoraArenaToolNoteDialog", UIParent, "BackdropTemplate")
    Skin:ApplyDark(dialog)
    dialog:SetSize(440, 220)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true); dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop",  dialog.StopMovingOrSizing)
    dialog:Hide()
    tinsert(UISpecialFrames, "MeteoraArenaToolNoteDialog")

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -8)
    title:SetTextColor(unpack(Skin.color.accent))
    title:SetText(L["postmatch_title"] or "Match note")

    headerFS = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerFS:SetPoint("TOPLEFT",  dialog, "TOPLEFT",  12, -32)
    headerFS:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -12, -32)
    headerFS:SetJustifyH("LEFT")

    local prompt = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    prompt:SetPoint("TOPLEFT", headerFS, "BOTTOMLEFT", 0, -8)
    prompt:SetText(L["postmatch_prompt"] or "")

    local box = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    Skin:ApplyDark(box, Skin.color.bgAlt, Skin.color.border)
    box:SetPoint("TOPLEFT",     prompt, "BOTTOMLEFT", 0, -6)
    box:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 44)

    bodyEdit = CreateFrame("EditBox", nil, box)
    bodyEdit:SetMultiLine(true)
    bodyEdit:SetAutoFocus(true)
    bodyEdit:SetFontObject("ChatFontNormal")
    bodyEdit:SetPoint("TOPLEFT",     box, "TOPLEFT",     6, -4)
    bodyEdit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 4)
    bodyEdit:SetScript("OnEscapePressed", function() dialog:Hide() end)
    bodyEdit:SetMaxLetters(500)

    saveBtn = Skin:CreateButton(dialog, L["postmatch_save"] or "Save", 100, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 12)
    saveBtn:SetScript("OnClick", function()
        if currentMatchId and MAT.Match then
            MAT.Match:SetNote(currentMatchId, bodyEdit:GetText())
        end
        dialog:Hide()
    end)

    skipBtn = Skin:CreateButton(dialog, L["postmatch_skip"] or "Skip", 100, 22)
    skipBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
    skipBtn:SetScript("OnClick", function() dialog:Hide() end)
end

local function summary(rec)
    if not rec then return "" end
    local res = rec.result or "?"
    local delta = rec.ratingDelta and (rec.ratingDelta >= 0 and "+" or "") .. rec.ratingDelta or ""
    return string.format("%s | %s | %s %s",
        rec.bracket or "?", rec.map or "?", res, delta)
end

function UI:OpenNoteFor(id)
    build()
    local rec
    for _, r in ipairs(MAT.db.global.matches or {}) do
        if r.id == id then rec = r; break end
    end
    if not rec then return end
    currentMatchId = id
    headerFS:SetText(summary(rec))
    bodyEdit:SetText(rec.note or "")
    dialog:Show()
    bodyEdit:SetFocus()
end

local Note = MAT:NewModule("PostMatchNote", "AceEvent-3.0")
function Note:OnEnable()
    self:RegisterMessage("MAT_MATCH_RECORDED", "OnMatchRecorded")
end

function Note:OnMatchRecorded(_, rec)
    if not rec then return end
    if not MAT.db.profile.postMatch.askForNote then return end
    if UI.OpenNoteFor then UI:OpenNoteFor(rec.id) end
end
