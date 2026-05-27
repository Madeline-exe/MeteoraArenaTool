local ADDON_NAME, ns = ...
local MAT = ns.MAT

local Match = MAT:NewModule("Match", "AceEvent-3.0")
MAT.Match = Match

-- ============================================================
-- Match — builds a MatchRecord from arena state + scanner output
-- on MAT_ARENA_ENDED, appends it to db.global.matches, and emits
-- MAT_MATCH_RECORDED for downstream UI / sync / post-match-note.
--
-- Schema (db.global.matches[i]):
--   {
--     id, ts, bracket, teamSize, registered, map,
--     durationSec, result, winner,
--     ratingBefore, ratingAfter, ratingDelta,
--     myTeam   = { { name, realm, class, classFile, level }, ... },
--     enemyTeam= same shape,
--     note     = string or nil,
--   }
-- ============================================================

local function snapshotMyTeam()
    local out = {}
    local function add(unitId)
        if not UnitExists(unitId) then return end
        local name, realm = UnitName(unitId)
        local class, classFile = UnitClass(unitId)
        local _, race = UnitRace(unitId)
        local level = UnitLevel(unitId)
        table.insert(out, {
            name = name, realm = realm,
            class = class, classFile = classFile,
            race = race, level = level,
        })
    end
    add("player")
    for i = 1, 4 do add("party" .. i) end
    table.sort(out, function(a, b)
        local ca, cb = a.classFile or "", b.classFile or ""
        if ca ~= cb then return ca < cb end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

local function nextId(db)
    db._lastId = (db._lastId or 0) + 1
    return db._lastId
end

function Match:OnEnable()
    self:RegisterMessage("MAT_ARENA_ENDED", "OnArenaEnded")
end

function Match:OnArenaEnded(_, state)
    if not state then return end
    local db = MAT.db.global

    local enemy = MAT.EnemyScanner and MAT.EnemyScanner:GetTeam() or {}

    local rec = {
        id           = nextId(db),
        ts           = time(),
        bracket      = state.bracket,
        teamSize     = state.teamSize,
        registered   = state.registered,
        map          = state.mapName,
        durationSec  = state.durationSec or 0,
        result       = state.result,
        winner       = state.winner,
        ratingBefore = state.ratingBefore,
        ratingAfter  = state.ratingAfter,
        ratingDelta  = state.ratingDelta,
        myTeam       = snapshotMyTeam(),
        enemyTeam    = enemy,
        note         = nil,
    }

    table.insert(db.matches, rec)
    MAT:SendMessage("MAT_MATCH_RECORDED", rec)
end

-- ------------------------------------------------------------
-- Read helpers used by UI
-- ------------------------------------------------------------

function Match:GetAll()
    return MAT.db.global.matches or {}
end

function Match:GetLast()
    local list = MAT.db.global.matches
    return list and list[#list] or nil
end

function Match:SetNote(id, note)
    for _, rec in ipairs(MAT.db.global.matches) do
        if rec.id == id then
            rec.note = note
            MAT:SendMessage("MAT_MATCH_NOTE_UPDATED", rec)
            return true
        end
    end
    return false
end
