local ADDON_NAME, ns = ...

-- ============================================================
-- Spell ID -> class/spec mapping for SpecGuess.
--
-- Each entry says "if you saw this spellID, add `weight` to the
-- score for (class, spec)." SpecGuess accumulates scores per
-- enemy GUID from COMBAT_LOG_EVENT_UNFILTERED and picks the
-- highest-scoring spec at any point.
--
-- Weights:
--   3  = nearly unique to this spec (e.g. Mortal Strike -> Arms)
--   2  = strong indicator but not exclusive
--   1  = mild hint
--
-- Coverage policy: max-rank TBC 2.5.5 IDs only. Arena opponents
-- are level 70 and use highest rank, so lower-rank IDs would
-- mostly be dead weight. Add additional ranks ad-hoc if a
-- specific log shows they actually appear.
--
-- ASCII-only comments per project rule. Add new entries below
-- the relevant class block to keep this file diff-friendly.
-- ============================================================

ns.Data = ns.Data or {}

local S2S = {}

-- ---------------- WARRIOR ----------------
S2S[30330] = { class = "WARRIOR", spec = "Arms",       weight = 3 }  -- Mortal Strike r6
S2S[12328] = { class = "WARRIOR", spec = "Arms",       weight = 2 }  -- Sweeping Strikes
S2S[12294] = { class = "WARRIOR", spec = "Arms",       weight = 3 }  -- Mortal Strike r1 (fallback)
S2S[30335] = { class = "WARRIOR", spec = "Fury",       weight = 3 }  -- Bloodthirst r6
S2S[23881] = { class = "WARRIOR", spec = "Fury",       weight = 3 }  -- Bloodthirst r1 (fallback)
S2S[12292] = { class = "WARRIOR", spec = "Fury",       weight = 2 }  -- Death Wish
S2S[30356] = { class = "WARRIOR", spec = "Protection", weight = 3 }  -- Shield Slam r6
S2S[30022] = { class = "WARRIOR", spec = "Protection", weight = 2 }  -- Devastate r5

-- ---------------- PALADIN ----------------
S2S[33072] = { class = "PALADIN", spec = "Holy",        weight = 3 }  -- Holy Shock heal r5
S2S[33073] = { class = "PALADIN", spec = "Holy",        weight = 3 }  -- Holy Shock damage r5
S2S[20473] = { class = "PALADIN", spec = "Holy",        weight = 3 }  -- Holy Shock r1
S2S[32699] = { class = "PALADIN", spec = "Protection",  weight = 3 }  -- Avenger's Shield r3
S2S[31935] = { class = "PALADIN", spec = "Protection",  weight = 3 }  -- Avenger's Shield r1
S2S[35395] = { class = "PALADIN", spec = "Retribution", weight = 3 }  -- Crusader Strike
S2S[20066] = { class = "PALADIN", spec = "Retribution", weight = 3 }  -- Repentance
S2S[27180] = { class = "PALADIN", spec = "Retribution", weight = 2 }  -- Hammer of Wrath r4

-- ---------------- HUNTER ----------------
S2S[19574] = { class = "HUNTER", spec = "BeastMastery", weight = 3 }  -- Bestial Wrath
S2S[34692] = { class = "HUNTER", spec = "BeastMastery", weight = 3 }  -- The Beast Within (aura)
S2S[34490] = { class = "HUNTER", spec = "Marksmanship", weight = 3 }  -- Silencing Shot
S2S[27065] = { class = "HUNTER", spec = "Marksmanship", weight = 2 }  -- Aimed Shot r8
S2S[27068] = { class = "HUNTER", spec = "Survival",     weight = 3 }  -- Wyvern Sting r4
S2S[23989] = { class = "HUNTER", spec = "Survival",     weight = 2 }  -- Readiness

-- ---------------- ROGUE ----------------
S2S[34413] = { class = "ROGUE", spec = "Assassination", weight = 3 }  -- Mutilate r2
S2S[34411] = { class = "ROGUE", spec = "Assassination", weight = 3 }  -- Mutilate r2 off-hand variant
S2S[1329]  = { class = "ROGUE", spec = "Assassination", weight = 3 }  -- Mutilate r1
S2S[14177] = { class = "ROGUE", spec = "Assassination", weight = 2 }  -- Cold Blood
S2S[13750] = { class = "ROGUE", spec = "Combat",        weight = 3 }  -- Adrenaline Rush
S2S[13877] = { class = "ROGUE", spec = "Combat",        weight = 3 }  -- Blade Flurry
S2S[14183] = { class = "ROGUE", spec = "Subtlety",      weight = 3 }  -- Premeditation
S2S[36554] = { class = "ROGUE", spec = "Subtlety",      weight = 3 }  -- Shadowstep
S2S[26864] = { class = "ROGUE", spec = "Subtlety",      weight = 2 }  -- Hemorrhage r4
S2S[14185] = { class = "ROGUE", spec = "Subtlety",      weight = 1 }  -- Preparation

-- ---------------- PRIEST ----------------
S2S[25387] = { class = "PRIEST", spec = "Shadow",     weight = 3 }  -- Mind Flay r7
S2S[15407] = { class = "PRIEST", spec = "Shadow",     weight = 3 }  -- Mind Flay r1
S2S[15473] = { class = "PRIEST", spec = "Shadow",     weight = 3 }  -- Shadowform (aura)
S2S[32996] = { class = "PRIEST", spec = "Shadow",     weight = 2 }  -- Shadow Word: Death r2
S2S[34917] = { class = "PRIEST", spec = "Shadow",     weight = 2 }  -- Vampiric Touch r3
S2S[15286] = { class = "PRIEST", spec = "Shadow",     weight = 2 }  -- Vampiric Embrace
S2S[33206] = { class = "PRIEST", spec = "Discipline", weight = 3 }  -- Pain Suppression
S2S[10060] = { class = "PRIEST", spec = "Discipline", weight = 3 }  -- Power Infusion
S2S[34866] = { class = "PRIEST", spec = "Holy",       weight = 3 }  -- Circle of Healing r5
S2S[34861] = { class = "PRIEST", spec = "Holy",       weight = 3 }  -- Circle of Healing r1
S2S[27871] = { class = "PRIEST", spec = "Holy",       weight = 2 }  -- Lightwell r4

-- ---------------- SHAMAN ----------------
S2S[25266] = { class = "SHAMAN", spec = "Enhancement", weight = 3 }  -- Stormstrike r5
S2S[17364] = { class = "SHAMAN", spec = "Enhancement", weight = 3 }  -- Stormstrike r1
S2S[30823] = { class = "SHAMAN", spec = "Enhancement", weight = 3 }  -- Shamanistic Rage
S2S[32594] = { class = "SHAMAN", spec = "Restoration", weight = 3 }  -- Earth Shield r4
S2S[974]   = { class = "SHAMAN", spec = "Restoration", weight = 3 }  -- Earth Shield r1
S2S[16191] = { class = "SHAMAN", spec = "Restoration", weight = 2 }  -- Mana Tide Totem r3
S2S[16166] = { class = "SHAMAN", spec = "Elemental",   weight = 3 }  -- Elemental Mastery
S2S[30706] = { class = "SHAMAN", spec = "Elemental",   weight = 3 }  -- Totem of Wrath

-- ---------------- MAGE ----------------
S2S[33938] = { class = "MAGE", spec = "Fire",   weight = 3 }  -- Pyroblast r11
S2S[11366] = { class = "MAGE", spec = "Fire",   weight = 3 }  -- Pyroblast r1
S2S[11129] = { class = "MAGE", spec = "Fire",   weight = 3 }  -- Combustion
S2S[33405] = { class = "MAGE", spec = "Frost",  weight = 3 }  -- Ice Barrier r6
S2S[11426] = { class = "MAGE", spec = "Frost",  weight = 3 }  -- Ice Barrier r1
S2S[12472] = { class = "MAGE", spec = "Frost",  weight = 3 }  -- Cold Snap
S2S[30455] = { class = "MAGE", spec = "Frost",  weight = 2 }  -- Ice Lance
S2S[30451] = { class = "MAGE", spec = "Arcane", weight = 3 }  -- Arcane Blast
S2S[12042] = { class = "MAGE", spec = "Arcane", weight = 3 }  -- Arcane Power
S2S[12043] = { class = "MAGE", spec = "Arcane", weight = 3 }  -- Presence of Mind

-- ---------------- WARLOCK ----------------
S2S[30405] = { class = "WARLOCK", spec = "Affliction",  weight = 3 }  -- Unstable Affliction r3
S2S[30108] = { class = "WARLOCK", spec = "Affliction",  weight = 3 }  -- Unstable Affliction r1
S2S[17928] = { class = "WARLOCK", spec = "Affliction",  weight = 2 }  -- Howl of Terror r2
S2S[27223] = { class = "WARLOCK", spec = "Affliction",  weight = 1 }  -- Death Coil r4
S2S[30146] = { class = "WARLOCK", spec = "Demonology",  weight = 3 }  -- Summon Felguard
S2S[18788] = { class = "WARLOCK", spec = "Demonology",  weight = 3 }  -- Demonic Sacrifice
S2S[25228] = { class = "WARLOCK", spec = "Demonology",  weight = 2 }  -- Soul Link (aura)
S2S[27266] = { class = "WARLOCK", spec = "Destruction", weight = 3 }  -- Conflagrate r6
S2S[17962] = { class = "WARLOCK", spec = "Destruction", weight = 3 }  -- Conflagrate r1
S2S[30414] = { class = "WARLOCK", spec = "Destruction", weight = 2 }  -- Shadowfury r3
S2S[30546] = { class = "WARLOCK", spec = "Destruction", weight = 2 }  -- Shadowburn r8

-- ---------------- DRUID ----------------
S2S[33763] = { class = "DRUID", spec = "Restoration", weight = 3 }  -- Lifebloom
S2S[33891] = { class = "DRUID", spec = "Restoration", weight = 3 }  -- Tree of Life (aura)
S2S[33987] = { class = "DRUID", spec = "Feral",       weight = 3 }  -- Mangle (Bear) r3
S2S[33983] = { class = "DRUID", spec = "Feral",       weight = 3 }  -- Mangle (Cat)  r3
S2S[33917] = { class = "DRUID", spec = "Feral",       weight = 3 }  -- Mangle (Cat)  r1 / shared
S2S[33876] = { class = "DRUID", spec = "Feral",       weight = 3 }  -- Mangle (Cat)  alt id
S2S[24858] = { class = "DRUID", spec = "Balance",     weight = 3 }  -- Moonkin Form (aura)
S2S[27013] = { class = "DRUID", spec = "Balance",     weight = 2 }  -- Insect Swarm r6
S2S[33831] = { class = "DRUID", spec = "Balance",     weight = 3 }  -- Force of Nature (treants)
S2S[33786] = { class = "DRUID", spec = "Balance",     weight = 2 }  -- Cyclone

ns.Data.SpellToSpec = S2S
