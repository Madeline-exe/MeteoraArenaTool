local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L

local Detector = MAT:NewModule("Detector", "AceEvent-3.0", "AceTimer-3.0")
MAT.Detector = Detector

-- ============================================================
-- Detector — owns arena state machine.
--
-- Lifecycle:
--   nil --(zone is arena)--> entered --(combat starts)--> started
--      --(winner known)--> ended --(reset)--> nil
--
-- Emits messages (via AceEvent SendMessage) consumed by Match.lua and UI:
--   MAT_ARENA_ENTERED { bracket, teamSize, mapName, registered, ratingBefore, factionGroup }
--   MAT_ARENA_STARTED { startTs }
--   MAT_ARENA_ENDED   { ..., endTs, durationSec, winner, result, ratingAfter, ratingDelta }
-- ============================================================

local state = nil  -- table while in an arena, nil otherwise

local function newState()
    return {
        bracket      = nil,    -- "2v2" / "3v3" / "5v5" / "Skirmish"
        teamSize     = nil,    -- 2 / 3 / 5
        mapName      = nil,
        registered   = nil,    -- true = rated, false = skirmish
        factionGroup = nil,    -- 0 (Green) / 1 (Gold) per GetBattlefieldArenaFaction
        enteredTs    = nil,
        startTs      = nil,
        endTs        = nil,
        ratingBefore = nil,
        ratingAfter  = nil,
        result       = nil,    -- "win" / "loss" / "draw"
        winner       = nil,    -- 0 / 1 / 255
    }
end

function Detector:GetState() return state end
function Detector:IsInArena() return state ~= nil end

-- ------------------------------------------------------------
-- Battlefield status helpers
-- ------------------------------------------------------------

local function findActiveArenaSlot()
    local maxSlots = (GetMaxBattlefieldID and GetMaxBattlefieldID()) or 2
    for i = 1, maxSlots do
        local status, mapName, _, _, _, teamSize, registered = GetBattlefieldStatus(i)
        if status == "active" and teamSize and teamSize > 0 then
            return i, mapName, teamSize, registered and true or false
        end
    end
end

local function readBracketLabel(teamSize, registered)
    if not registered then return L["bracket_skirmish"] or "Skirmish" end
    return MAT:BracketLabel(teamSize)
end

-- ------------------------------------------------------------
-- State transitions
-- ------------------------------------------------------------

function Detector:OnEnterArena()
    if state then return end
    if not (IsActiveBattlefieldArena and IsActiveBattlefieldArena()) then return end

    local slot, mapName, teamSize, registered = findActiveArenaSlot()
    if not slot then
        -- API not ready yet; retry once.
        self:ScheduleTimer(function() self:OnEnterArena() end, 1.0)
        return
    end

    state = newState()
    state.teamSize     = teamSize
    state.registered   = registered
    state.mapName      = mapName or GetRealZoneText() or "?"
    state.bracket      = readBracketLabel(teamSize, registered)
    state.enteredTs    = GetTime()
    state.factionGroup = GetBattlefieldArenaFaction and GetBattlefieldArenaFaction() or nil

    if registered then
        state.ratingBefore = MAT:GetTeamRating(teamSize)
    end

    MAT:SendMessage("MAT_ARENA_ENTERED", state)
end

function Detector:OnArenaStart()
    if not state or state.startTs then return end
    state.startTs = GetTime()
    MAT:SendMessage("MAT_ARENA_STARTED", state)
end

function Detector:OnArenaEnd()
    if not state or state.endTs then return end

    local winner = GetBattlefieldWinner and GetBattlefieldWinner()
    if winner == nil then return end

    state.winner   = winner
    state.endTs    = GetTime()

    if winner == 255 then
        state.result = "draw"
    elseif state.factionGroup ~= nil then
        state.result = (winner == state.factionGroup) and "win" or "loss"
    else
        state.result = "loss"  -- safer default than guessing
    end

    -- Rating snapshot — server takes a beat to push the updated team values.
    if state.registered then
        self:ScheduleTimer(function()
            state.ratingAfter = MAT:GetTeamRating(state.teamSize)
            if state.ratingBefore and state.ratingAfter then
                state.ratingDelta = state.ratingAfter - state.ratingBefore
            end
            self:FinalizeEnd()
        end, 2.0)
    else
        self:FinalizeEnd()
    end
end

function Detector:FinalizeEnd()
    if not state or not state.endTs then return end
    state.durationSec = math.max(0, math.floor((state.endTs - (state.startTs or state.enteredTs or state.endTs))))
    MAT:SendMessage("MAT_ARENA_ENDED", state)
    state = nil
end

-- Defensive reset (zone change away from arena while we still think we're in one).
function Detector:Reset()
    if state then
        state = nil
        MAT:SendMessage("MAT_ARENA_RESET")
    end
end

-- ------------------------------------------------------------
-- Event wiring
-- ------------------------------------------------------------

function Detector:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD",   "OnZoneOrLogin")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA",   "OnZoneOrLogin")
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", "OnBattlefieldStatus")
    self:RegisterEvent("PLAYER_REGEN_DISABLED",   "OnCombatStart")
end

function Detector:OnZoneOrLogin()
    if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then
        self:OnEnterArena()
    else
        self:Reset()
    end
end

function Detector:OnBattlefieldStatus()
    if state and not state.endTs then
        if GetBattlefieldWinner and GetBattlefieldWinner() ~= nil then
            self:OnArenaEnd()
        end
    end
end

function Detector:OnCombatStart()
    if state and not state.startTs then
        self:OnArenaStart()
    end
end
