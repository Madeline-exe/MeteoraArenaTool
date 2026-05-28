local ADDON_NAME, ns = ...
local MAT = ns.MAT

local SpecGuess = MAT:NewModule("SpecGuess", "AceEvent-3.0")
MAT.SpecGuess = SpecGuess

-- ============================================================
-- SpecGuess — derives an enemy player's talent spec from the
-- spells they cast in the arena.
--
-- Approach: subscribe to COMBAT_LOG_EVENT_UNFILTERED, look up
-- each spellID in ns.Data.SpellToSpec, and add the spell's
-- weight to scores[sourceGUID][class..":"..spec]. At any moment
-- the spec with the highest score for a GUID is the best guess.
--
-- We only score events where sourceGUID is a known enemy
-- (EnemyScanner:HasGuid). That keeps scores from being polluted
-- by pets, totems, or our own party members casting the same
-- spell.
--
-- Confidence = top score - runner-up score. Sub-class fallback:
-- if no spec for a GUID yet, GetSpec returns nil (UI shows "?").
-- ============================================================

local SpellToSpec  -- bound in OnEnable from ns.Data.SpellToSpec
local scores = {}  -- [guid] = { ["CLASS:Spec"] = number }

local function ensureBucket(guid)
    local b = scores[guid]
    if not b then b = {}; scores[guid] = b end
    return b
end

-- ------------------------------------------------------------
-- Lifecycle
-- ------------------------------------------------------------

function SpecGuess:OnEnable()
    SpellToSpec = ns.Data and ns.Data.SpellToSpec or {}
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    self:RegisterMessage("MAT_ARENA_RESET",   "Reset")
    self:RegisterMessage("MAT_ARENA_ENTERED", "Reset")
end

function SpecGuess:Reset()
    wipe(scores)
end

-- ------------------------------------------------------------
-- CLEU
-- ------------------------------------------------------------

function SpecGuess:OnCombatLog()
    -- CLEU args via CombatLogGetCurrentEventInfo (TBC 2.5.5).
    local _, _, _, sourceGUID, _, _, _, _, _, _, _,
          spellId = CombatLogGetCurrentEventInfo()
    if not sourceGUID or not spellId then return end

    local hit = SpellToSpec[spellId]
    if not hit then return end

    -- Only score actual enemy players we have on scan.
    if not MAT.EnemyScanner or not MAT.EnemyScanner:HasGuid(sourceGUID) then
        return
    end

    -- Sanity: ignore if the enemy's known class disagrees with the spell's
    -- expected class. Pets and weird CLEU sourceGUID quirks slip in
    -- otherwise (e.g. warlock pet casting Shadowfury counted against the
    -- warlock's spec).
    local enemy = MAT.EnemyScanner:GetByGuid(sourceGUID)
    if enemy and enemy.classFile and enemy.classFile ~= hit.class then
        return
    end

    local b = ensureBucket(sourceGUID)
    local key = hit.class .. ":" .. hit.spec
    b[key] = (b[key] or 0) + (hit.weight or 1)
end

-- ------------------------------------------------------------
-- Read API
-- ------------------------------------------------------------

-- Returns spec name (e.g. "Arms"), confidence delta, total score.
-- nil if no diagnostic spells were observed for this GUID yet.
function SpecGuess:GetSpec(guid)
    local b = scores[guid]
    if not b then return nil end

    local bestKey, bestScore = nil, 0
    local secondScore = 0
    for k, v in pairs(b) do
        if v > bestScore then
            secondScore = bestScore
            bestScore   = v
            bestKey     = k
        elseif v > secondScore then
            secondScore = v
        end
    end

    if not bestKey then return nil end
    local _, spec = bestKey:match("^([^:]+):(.+)$")
    return spec, bestScore - secondScore, bestScore
end

-- One row per known enemy slot. `spec` may be nil if we have no
-- observations yet. Ordering mirrors EnemyScanner:GetTeam (sorted).
function SpecGuess:GetTeamSpecs()
    local out = {}
    if not MAT.EnemyScanner then return out end
    for _, guid in ipairs(MAT.EnemyScanner:GetGuids()) do
        local enemy = MAT.EnemyScanner:GetByGuid(guid)
        if enemy then
            local spec, confidence = self:GetSpec(guid)
            table.insert(out, {
                guid       = guid,
                name       = enemy.name,
                classFile  = enemy.classFile,
                spec       = spec,
                confidence = confidence or 0,
            })
        end
    end
    table.sort(out, function(a, b)
        local ca, cb = a.classFile or "", b.classFile or ""
        if ca ~= cb then return ca < cb end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

-- Debug helper: dump all observed enemies and their score tables.
function SpecGuess:Dump()
    MAT:Print("|cffffd200=== SpecGuess scores ===|r")
    local n = 0
    for guid, b in pairs(scores) do
        n = n + 1
        local enemy = MAT.EnemyScanner and MAT.EnemyScanner:GetByGuid(guid)
        local who = enemy and enemy.name or guid
        local spec, conf = self:GetSpec(guid)
        MAT:Print(string.format("  %s -> %s (delta=%d)",
            tostring(who), spec or "?", conf or 0))
        for k, v in pairs(b) do
            MAT:Print(string.format("      %s = %d", k, v))
        end
    end
    if n == 0 then MAT:Print("  (no enemies scored yet)") end
end
