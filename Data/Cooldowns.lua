local ADDON_NAME, ns = ...

-- ============================================================
-- Cooldowns DB — two tables:
--
--   ns.Data.Cooldowns.Threats[spellID] = {
--       name, category, severity (1-3), class
--   }
--   Things the enemy team can drop on you that you should save
--   FOR. Categories: "cc", "burst", "interrupt", "dispel".
--
--   ns.Data.Cooldowns.Saves[CLASSFILE] = {
--       { name, vs = {category, ...}, severity (1-3) }, ...
--   }
--   What MY class can press to answer those categories. HUD
--   filters by category overlap with the active enemy comp.
--
-- Coverage policy: max-rank TBC 2.5.5 IDs only. Add lower ranks
-- only if a log actually shows them in arena.
-- ASCII-only strings per project rule.
-- ============================================================

ns.Data = ns.Data or {}

local Threats = {}
local Saves   = {}

-- ============================================================
-- Threats
-- ============================================================

-- ---------------- WARRIOR ----------------
Threats[1719]  = { name = "Recklessness",     category = "burst",     severity = 3, class = "WARRIOR" }
Threats[12292] = { name = "Death Wish",       category = "burst",     severity = 2, class = "WARRIOR" }
Threats[5246]  = { name = "Intimidating Shout", category = "cc",      severity = 3, class = "WARRIOR" }
Threats[12809] = { name = "Concussion Blow",  category = "cc",        severity = 2, class = "WARRIOR" }
Threats[7922]  = { name = "Charge Stun",      category = "cc",        severity = 1, class = "WARRIOR" }
Threats[6552]  = { name = "Pummel",           category = "interrupt", severity = 2, class = "WARRIOR" }

-- ---------------- PALADIN ----------------
Threats[10308] = { name = "Hammer of Justice", category = "cc",       severity = 3, class = "PALADIN" }
Threats[20066] = { name = "Repentance",        category = "cc",       severity = 3, class = "PALADIN" }
Threats[20467] = { name = "Judgement of Justice", category = "cc",    severity = 1, class = "PALADIN" }
Threats[31884] = { name = "Avenging Wrath",    category = "burst",    severity = 3, class = "PALADIN" }
Threats[35395] = { name = "Crusader Strike",   category = "burst",    severity = 1, class = "PALADIN" }

-- ---------------- HUNTER ----------------
Threats[3355]  = { name = "Freezing Trap",    category = "cc",        severity = 3, class = "HUNTER" }
Threats[27068] = { name = "Wyvern Sting",     category = "cc",        severity = 3, class = "HUNTER" }
Threats[19503] = { name = "Scatter Shot",     category = "cc",        severity = 2, class = "HUNTER" }
Threats[19574] = { name = "Bestial Wrath",    category = "burst",     severity = 3, class = "HUNTER" }
Threats[34490] = { name = "Silencing Shot",   category = "interrupt", severity = 2, class = "HUNTER" }

-- ---------------- ROGUE ----------------
Threats[1833]  = { name = "Cheap Shot",       category = "cc",        severity = 3, class = "ROGUE" }
Threats[8643]  = { name = "Kidney Shot",      category = "cc",        severity = 3, class = "ROGUE" }
Threats[2094]  = { name = "Blind",            category = "cc",        severity = 3, class = "ROGUE" }
Threats[6770]  = { name = "Sap",              category = "cc",        severity = 2, class = "ROGUE" }
Threats[1776]  = { name = "Gouge",            category = "cc",        severity = 2, class = "ROGUE" }
Threats[13750] = { name = "Adrenaline Rush",  category = "burst",     severity = 3, class = "ROGUE" }
Threats[14177] = { name = "Cold Blood",       category = "burst",     severity = 2, class = "ROGUE" }
Threats[1766]  = { name = "Kick",             category = "interrupt", severity = 2, class = "ROGUE" }

-- ---------------- PRIEST ----------------
Threats[8122]  = { name = "Psychic Scream",   category = "cc",        severity = 3, class = "PRIEST" }
Threats[15487] = { name = "Silence",          category = "interrupt", severity = 2, class = "PRIEST" }
Threats[10060] = { name = "Power Infusion",   category = "burst",     severity = 3, class = "PRIEST" }
Threats[605]   = { name = "Mind Control",     category = "cc",        severity = 2, class = "PRIEST" }
Threats[32375] = { name = "Mass Dispel",      category = "dispel",    severity = 3, class = "PRIEST" }

-- ---------------- SHAMAN ----------------
Threats[39796] = { name = "Stoneclaw Stun",   category = "cc",        severity = 1, class = "SHAMAN" }
Threats[8042]  = { name = "Earth Shock",      category = "interrupt", severity = 2, class = "SHAMAN" }
Threats[30823] = { name = "Shamanistic Rage", category = "burst",     severity = 2, class = "SHAMAN" }
Threats[16166] = { name = "Elemental Mastery",category = "burst",     severity = 3, class = "SHAMAN" }
Threats[370]   = { name = "Purge",            category = "dispel",    severity = 2, class = "SHAMAN" }

-- ---------------- MAGE ----------------
Threats[28272] = { name = "Polymorph: Pig",   category = "cc",        severity = 3, class = "MAGE" }
Threats[28271] = { name = "Polymorph: Turtle",category = "cc",        severity = 3, class = "MAGE" }
Threats[12826] = { name = "Polymorph",        category = "cc",        severity = 3, class = "MAGE" }
Threats[33938] = { name = "Pyroblast",        category = "burst",     severity = 3, class = "MAGE" }
Threats[11129] = { name = "Combustion",       category = "burst",     severity = 3, class = "MAGE" }
Threats[12042] = { name = "Arcane Power",     category = "burst",     severity = 3, class = "MAGE" }
Threats[12043] = { name = "Presence of Mind", category = "burst",     severity = 2, class = "MAGE" }
Threats[2139]  = { name = "Counterspell",     category = "interrupt", severity = 3, class = "MAGE" }
Threats[18469] = { name = "Counterspell Silence", category = "interrupt", severity = 2, class = "MAGE" }

-- ---------------- WARLOCK ----------------
Threats[6789]  = { name = "Death Coil",       category = "cc",        severity = 2, class = "WARLOCK" }
Threats[17928] = { name = "Howl of Terror",   category = "cc",        severity = 3, class = "WARLOCK" }
Threats[6358]  = { name = "Seduction",        category = "cc",        severity = 3, class = "WARLOCK" } -- Succubus pet
Threats[5782]  = { name = "Fear",             category = "cc",        severity = 3, class = "WARLOCK" }
Threats[30414] = { name = "Shadowfury",       category = "cc",        severity = 3, class = "WARLOCK" }
Threats[19647] = { name = "Spell Lock",       category = "interrupt", severity = 3, class = "WARLOCK" } -- Felhunter
Threats[30405] = { name = "Unstable Affliction", category = "dispel", severity = 3, class = "WARLOCK" }
Threats[18708] = { name = "Fel Domination",   category = "burst",     severity = 1, class = "WARLOCK" }

-- ---------------- DRUID ----------------
Threats[33786] = { name = "Cyclone",          category = "cc",        severity = 3, class = "DRUID" }
Threats[5211]  = { name = "Bash",             category = "cc",        severity = 2, class = "DRUID" }
Threats[9005]  = { name = "Pounce",           category = "cc",        severity = 3, class = "DRUID" }
Threats[16979] = { name = "Feral Charge",     category = "cc",        severity = 2, class = "DRUID" }
Threats[16689] = { name = "Nature's Grasp",   category = "cc",        severity = 1, class = "DRUID" }

-- ============================================================
-- Saves (per MY class)
-- ============================================================

Saves.WARRIOR = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Berserker Rage",    vs = { "cc" },              severity = 2 }, -- fear/sleep only
    { name = "Shield Wall",       vs = { "burst" },           severity = 3 },
    { name = "Last Stand",        vs = { "burst" },           severity = 2 },
    { name = "Spell Reflect",     vs = { "burst", "cc" },     severity = 2 },
    { name = "Intercept stun",    vs = { "interrupt" },       severity = 1 },
}

Saves.PALADIN = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Divine Shield",     vs = { "cc", "burst" },     severity = 3 },
    { name = "Hand of Freedom",   vs = { "cc" },              severity = 2 },
    { name = "Hand of Sacrifice", vs = { "burst" },           severity = 2 }, -- on partner
    { name = "Hand of Protection",vs = { "burst" },           severity = 2 }, -- on caster vs phys
    { name = "Lay on Hands",      vs = { "burst" },           severity = 3 },
}

Saves.HUNTER = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Deterrence",        vs = { "burst" },           severity = 3 },
    { name = "Feign Death",       vs = { "cc", "burst" },     severity = 2 },
    { name = "Scatter Shot",      vs = { "cc", "interrupt" }, severity = 2 },
}

Saves.ROGUE = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Cloak of Shadows",  vs = { "cc", "burst", "dispel" }, severity = 3 },
    { name = "Evasion",           vs = { "burst" },           severity = 3 }, -- melee burst only
    { name = "Vanish",            vs = { "burst", "cc" },     severity = 3 },
    { name = "Blind",             vs = { "interrupt" },       severity = 2 },
}

Saves.PRIEST = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Pain Suppression",  vs = { "burst", "cc" },     severity = 3 }, -- disc only
    { name = "Power Word: Shield",vs = { "burst" },           severity = 2 },
    { name = "Fade",              vs = { "cc" },              severity = 1 }, -- threat drop, situational
    { name = "Mass Dispel",       vs = { "dispel", "cc" },    severity = 3 },
}

Saves.SHAMAN = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Grounding Totem",   vs = { "cc", "interrupt" }, severity = 3 },
    { name = "Tremor Totem",      vs = { "cc" },              severity = 2 }, -- fear/charm/sleep
    { name = "Nature's Swiftness",vs = { "burst" },           severity = 3 }, -- + clutch heal
    { name = "Shamanistic Rage",  vs = { "burst" },           severity = 2 }, -- enh
    { name = "Earthbind Totem",   vs = { "burst" },           severity = 1 },
}

Saves.MAGE = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Ice Block",         vs = { "burst", "cc", "dispel" }, severity = 3 },
    { name = "Cold Snap",         vs = { "burst", "cc" },     severity = 2 }, -- resets Ice Block
    { name = "Counterspell",      vs = { "cc", "interrupt" }, severity = 3 }, -- preempt enemy cast
    { name = "Blink",             vs = { "cc" },              severity = 2 },
    { name = "Mana Shield",       vs = { "burst" },           severity = 1 },
}

Saves.WARLOCK = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Felhunter Spell Lock", vs = { "interrupt" },    severity = 3 },
    { name = "Death Coil",        vs = { "burst", "cc" },     severity = 3 },
    { name = "Howl of Terror",    vs = { "burst" },           severity = 2 },
    { name = "Soul Link",         vs = { "burst" },           severity = 2 }, -- demonology
    { name = "Curse of Tongues",  vs = { "cc" },              severity = 1 },
}

Saves.DRUID = {
    { name = "PvP Trinket",       vs = { "cc" },              severity = 3 },
    { name = "Barkskin",          vs = { "burst", "cc" },     severity = 3 },
    { name = "Nature's Swiftness",vs = { "burst" },           severity = 3 }, -- + Healing Touch
    { name = "Bash",              vs = { "interrupt", "cc" }, severity = 2 }, -- bear
    { name = "Travel Form",       vs = { "cc" },              severity = 1 }, -- breaks roots
    { name = "Innervate",         vs = { "burst" },           severity = 1 }, -- on healer partner
}

ns.Data.Cooldowns = {
    Threats = Threats,
    Saves   = Saves,
}
