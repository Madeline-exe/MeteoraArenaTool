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
L["help_lfg"]  = "— open LFG / team finder"
L["help_wipe"] = "— delete all stored matches"

-- Minimap
L["minimap_lmb"] = "open"
L["minimap_rmb"] = "settings"

-- Tabs
L["tab_feed"]     = "Feed"
L["tab_lfg"]      = "LFG"
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

-- LFG tab
L["lfg_my_listing"]   = "My listing"
L["lfg_listings"]     = "Active listings"
L["lfg_bracket"]      = "Bracket:"
L["lfg_my_rating"]    = "My rating:"
L["lfg_auto"]         = "Auto"
L["lfg_expiry"]       = "Expires in:"
L["lfg_minutes"]      = "min"
L["lfg_looking_for"]  = "Looking for:"
L["lfg_any"]          = "Any"
L["lfg_comment"]      = "Comment:"
L["lfg_post"]         = "Post"
L["lfg_clear"]        = "Clear"
L["lfg_refresh"]      = "Refresh"
L["lfg_whisper"]      = "Whisper"
L["lfg_status_active"]= "Active"
L["lfg_status_idle"]  = "Not posted"
L["lfg_expires_in"]   = "expires in"
L["lfg_rating"]       = "Rating:"
L["lfg_all"]          = "All"
L["lfg_no_listings"]  = "No active listings. Click Refresh or wait a moment."
L["lfg_invalid"]      = "listing rejected: pick a bracket and LFG/LFM"
L["lfg_chan_joined"]  = "joined channel #%d (%s)"
L["lfg_posted"]       = "posted"
L["lfg_send_failed"]  = "broadcast failed: channel id=0"
L["help_lfg_debug"]   = "— print LFG channel/listings state"
L["lfg_col_age"]      = "Age"
L["lfg_col_kind"]     = "Type"
L["lfg_col_who"]      = "Player"
L["lfg_col_bracket"]  = "Bracket"
L["lfg_col_rating"]   = "Rating"
L["lfg_col_wants"]    = "Wants"
L["lfg_col_comment"]  = "Comment"
