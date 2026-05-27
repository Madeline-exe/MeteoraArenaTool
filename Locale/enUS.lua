local ADDON_NAME = ...
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true, true)
if not L then return end

-- Core
L["loaded"]        = "v%s loaded. /mat for commands."
L["version"]       = "version: %s"
L["wiped_history"] = "Match history wiped."
L["wipe_usage"]    = "Use: /mat wipe history"

-- Slash help
L["help_show"] = "— open main window"
L["help_feed"] = "— jump to match feed"
L["help_wipe"] = "— delete all stored matches"

-- Minimap
L["minimap_lmb"] = "open"
L["minimap_rmb"] = "settings"

-- Tabs
L["tab_feed"]     = "Feed"
L["tab_stats"]    = "Stats"
L["tab_cd"]       = "Cooldowns"
L["tab_settings"] = "Settings"

-- Status / placeholders
L["status_ready"]    = "Ready"
L["no_matches"]      = "No matches recorded yet."
L["coming_soon"]     = "Coming soon."

-- Brackets / results
L["bracket_skirmish"] = "Skirmish"
L["result_win"]       = "Win"
L["result_loss"]      = "Loss"
L["result_draw"]      = "Draw"

-- Post-match note
L["postmatch_title"]  = "Match note"
L["postmatch_prompt"] = "Notes on this match (what went wrong / right):"
L["postmatch_save"]   = "Save"
L["postmatch_skip"]   = "Skip"

-- Feed columns
L["col_when"]     = "When"
L["col_bracket"]  = "Bracket"
L["col_map"]      = "Map"
L["col_result"]   = "Result"
L["col_rating"]   = "Rating"
L["col_enemy"]    = "Enemy"
L["col_duration"] = "Duration"
