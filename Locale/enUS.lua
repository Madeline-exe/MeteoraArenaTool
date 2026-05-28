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
L["help_stats"] = "— open stats tab"
L["help_lfg"]  = "— open LFG / team finder"
L["help_wipe"] = "— delete all stored matches"
L["help_hud"]       = "— show HUD status and command list"
L["help_hud_onoff"] = "— enable/disable HUD"
L["help_hud_test"]  = "— show HUD with fake comp for positioning"
L["help_hud_lock"]  = "— lock/unlock HUD drag"
L["help_hud_reset"] = "— reset HUD position to center"
L["help_hud_debug"] = "— dump HUD state for diagnosis"

-- Settings tab
L["settings_hud"]          = "HUD overlay"
L["settings_hud_enabled"]  = "Enable HUD in arenas"
L["settings_hud_locked"]   = "Lock HUD position"
L["settings_hud_scale"]    = "HUD scale"
L["settings_hud_reset"]    = "Reset HUD position"
L["settings_hud_test"]     = "Toggle test mode"
L["settings_feed"]         = "Match feed"
L["settings_ask_note"]     = "Ask for a note after each match"
L["settings_minimap"]      = "Minimap"
L["settings_minimap_show"] = "Show minimap button"

-- Stats tab
L["stats_bracket"]   = "Bracket:"
L["stats_period"]    = "Period:"
L["stats_all"]       = "All"
L["stats_today"]     = "Today"
L["stats_week"]      = "Week"
L["stats_month"]     = "Month"
L["stats_total"]     = "Total"
L["stats_winrate"]   = "Win%"
L["stats_top_comps"] = "Top enemy comps"
L["stats_maps"]      = "Maps"
L["stats_partners"]  = "Partners"

-- Cooldowns tab
L["cd_class"]     = "Class:"
L["cd_my_saves"]  = "Saves"
L["cd_threats"]   = "Threats from"
L["cd_vs"]        = "vs"
L["cd_no_data"]   = "No data for this class."

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
L["lfg_you_tag"]      = "(you)"
