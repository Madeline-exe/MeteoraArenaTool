local ADDON_NAME, ns = ...
local MAT = ns.MAT

local Scanner = MAT:NewModule("EnemyScanner", "AceEvent-3.0")
MAT.EnemyScanner = Scanner

-- ============================================================
-- EnemyScanner — captures opponent identity from arena1..arenaN.
--
-- Source of truth is unitID arena1..arena5 + ARENA_OPPONENT_UPDATE
-- event. We snapshot whenever a unit appears; the last known data
-- per GUID survives stealth/range issues.
--
-- v0.1 captures: name, realm, class, classFile, race, sex, level.
-- Spec is deliberately NOT captured here — see SpecGuess (v0.2+).
-- ============================================================

local enemies = {}  -- [guid] = { name, realm, class, classFile, race, sex, level, unitId }

local function captureUnit(unitId)
    if not UnitExists(unitId) then return end
    local guid = UnitGUID(unitId)
    if not guid then return end

    local name, realm = UnitName(unitId)
    local class, classFile = UnitClass(unitId)
    local race, _ = UnitRace(unitId)
    local sex = UnitSex(unitId)
    local level = UnitLevel(unitId)

    local rec = enemies[guid] or {}
    rec.name      = name      or rec.name
    rec.realm     = realm     or rec.realm
    rec.class     = class     or rec.class
    rec.classFile = classFile or rec.classFile
    rec.race      = race      or rec.race
    rec.sex       = sex       or rec.sex
    rec.level     = level     or rec.level
    rec.unitId    = unitId
    enemies[guid] = rec
end

function Scanner:Reset()
    enemies = {}
end

function Scanner:ScanAll()
    for i = 1, 5 do captureUnit("arena" .. i) end
end

function Scanner:GetTeam()
    local out = {}
    for _, rec in pairs(enemies) do
        table.insert(out, {
            guid      = nil,    -- intentionally not surfaced (PII-ish)
            name      = rec.name,
            realm     = rec.realm,
            class     = rec.class,
            classFile = rec.classFile,
            race      = rec.race,
            level     = rec.level,
        })
    end
    -- Stable order: by class name, then player name.
    table.sort(out, function(a, b)
        local ca, cb = a.classFile or "", b.classFile or ""
        if ca ~= cb then return ca < cb end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

function Scanner:OnEnable()
    self:RegisterEvent("ARENA_OPPONENT_UPDATE", "OnOpponentUpdate")
    self:RegisterEvent("UNIT_NAME_UPDATE",      "OnUnitNameUpdate")
    self:RegisterMessage("MAT_ARENA_ENTERED",   "OnArenaEntered")
    self:RegisterMessage("MAT_ARENA_RESET",     "Reset")
end

function Scanner:OnArenaEntered()
    self:Reset()
    self:ScanAll()
end

function Scanner:OnOpponentUpdate(_, unitId, eventType)
    if eventType == "cleared" then return end
    if unitId and unitId:match("^arena[1-5]$") then
        captureUnit(unitId)
    end
end

function Scanner:OnUnitNameUpdate(_, unitId)
    if unitId and unitId:match("^arena[1-5]$") then
        captureUnit(unitId)
    end
end
