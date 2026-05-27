local ADDON_NAME, ns = ...
local MAT = ns.MAT

-- ============================================================
-- UI module registration. Build / Toggle / Refresh / OpenTab
-- are provided by UI/MainPanel.lua (loaded last in TOC). This
-- file owns AceEvent mixin and message subscriptions only.
-- ============================================================

local UI = MAT:NewModule("UI", "AceEvent-3.0")
MAT.UI = UI

function UI:OnEnable()
    self:RegisterMessage("MAT_MATCH_RECORDED",     "RefreshLater")
    self:RegisterMessage("MAT_MATCH_NOTE_UPDATED", "RefreshLater")
end
