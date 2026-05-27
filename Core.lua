local ADDON_NAME, ns = ...

-- Compat shims: TBC Classic Anniversary 2.5.5 moved several globals into namespaces.
-- Keep both code paths so the addon works on old 2.5.4 builds and on 2.5.5+.
local function _getAddOnMetadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, field)
    end
    return _G.GetAddOnMetadata and _G.GetAddOnMetadata(name, field) or nil
end

local function _isAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(name) or false
end

ns.compat = {
    GetAddOnMetadata = _getAddOnMetadata,
    IsAddOnLoaded    = _isAddOnLoaded,
}

local MAT = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0",
    "AceHook-3.0"
)

_G.MeteoraArenaTool = MAT
ns.MAT = MAT
ns.ADDON_NAME = ADDON_NAME

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)
            or setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

MAT.version = ns.compat.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
MAT.commPrefix = "MAT1"

local defaults = {
    profile = {
        ui = {
            scale  = 1.0,
            locked = false,
            mainFramePoint = { "CENTER", nil, "CENTER", 0, 0 },
        },
        feed = {
            includeSkirmish = true,
        },
        postMatch = {
            askForNote = true,
        },
        minimap = {
            hide = false,
        },
    },
    global = {
        matches    = {},  -- chronological list of MatchRecord
        cdOverrides = {}, -- user-edited cooldown notes (v0.2+)
    },
}

function MAT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MeteoraArenaToolDB", defaults, true)

    self:RegisterChatCommand("mat",     "OnSlashCommand")
    self:RegisterChatCommand("meteora", "OnSlashCommand")

    self.modules = self.modules or {}
end

function MAT:OnEnable()
    self:SetupMinimapButton()
    self:Print(L["loaded"]:format(self.version))
end

function MAT:SetupMinimapButton()
    local LDB  = LibStub("LibDataBroker-1.1", true)
    local Icon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not Icon then return end

    local dataObj = LDB:NewDataObject(ADDON_NAME, {
        type  = "launcher",
        label = "Meteora Arena",
        icon  = "Interface\\Icons\\Achievement_Arena_2v2_7",
        OnClick = function(_, button)
            if button == "RightButton" then
                if MAT.UI and MAT.UI.OpenTab then MAT.UI:OpenTab("settings") end
            else
                if MAT.UI and MAT.UI.Toggle then MAT.UI:Toggle() end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Meteora Arena Tool")
            tooltip:AddLine("|cffeda55fЛКМ|r — " .. (L["minimap_lmb"] or "открыть"), 1, 1, 1)
            tooltip:AddLine("|cffeda55fПКМ|r — " .. (L["minimap_rmb"] or "настройки"), 1, 1, 1)
        end,
    })
    Icon:Register(ADDON_NAME, dataObj, self.db.profile.minimap)
end

function MAT:OnSlashCommand(input)
    input = (input or ""):trim():lower()
    local cmd, rest = input:match("^(%S*)%s*(.-)$")

    if cmd == "" or cmd == "show" or cmd == "toggle" then
        if self.UI and self.UI.Toggle then self.UI:Toggle() end
    elseif cmd == "feed" then
        if self.UI and self.UI.OpenTab then self.UI:OpenTab("feed") end
    elseif cmd == "version" then
        self:Print(L["version"]:format(self.version))
    elseif cmd == "wipe" then
        if rest == "history" then
            self.db.global.matches = {}
            self:Print(L["wiped_history"])
            self:SendMessage("MAT_MATCH_RECORDED")
        else
            self:Print(L["wipe_usage"])
        end
    else
        self:PrintHelp()
    end
end

function MAT:PrintHelp()
    self:Print("|cffffd200/mat|r " .. L["help_show"])
    self:Print("|cffffd200/mat feed|r " .. L["help_feed"])
    self:Print("|cffffd200/mat wipe history|r " .. L["help_wipe"])
end

-- ============================================================
-- Helpers used across modules
-- ============================================================

function MAT:BracketLabel(teamSize)
    if teamSize == 2 then return "2v2"
    elseif teamSize == 3 then return "3v3"
    elseif teamSize == 5 then return "5v5"
    else return tostring(teamSize or "?") end
end

function MAT:BracketTeamIndex(teamSize)
    -- GetArenaTeam(index): 1=2v2, 2=3v3, 3=5v5
    if teamSize == 2 then return 1
    elseif teamSize == 3 then return 2
    elseif teamSize == 5 then return 3 end
end

function MAT:GetTeamRating(teamSize)
    local idx = self:BracketTeamIndex(teamSize)
    if not idx or not GetArenaTeam then return nil end
    local _, _, rating = GetArenaTeam(idx)
    return rating
end
