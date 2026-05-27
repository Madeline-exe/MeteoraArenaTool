local ADDON_NAME = ...
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "ruRU", false)
if not L then return end

L["loaded"]        = "v%s загружен. /mat — команды."
L["version"]       = "версия: %s"
L["wiped_history"] = "История матчей очищена."
L["wipe_usage"]    = "Используй: /mat wipe history"

L["help_show"] = "— открыть главное окно"
L["help_feed"] = "— перейти к ленте матчей"
L["help_wipe"] = "— удалить всю историю матчей"

L["minimap_lmb"] = "открыть"
L["minimap_rmb"] = "настройки"

L["tab_feed"]     = "Лента"
L["tab_stats"]    = "Статистика"
L["tab_cd"]       = "Кулдауны"
L["tab_settings"] = "Настройки"

L["status_ready"] = "Готов"
L["no_matches"]   = "Пока нет записанных матчей."
L["coming_soon"]  = "Скоро будет."

L["bracket_skirmish"] = "Skirmish"
L["result_win"]       = "Победа"
L["result_loss"]      = "Поражение"
L["result_draw"]      = "Ничья"

L["postmatch_title"]  = "Заметка по матчу"
L["postmatch_prompt"] = "Что запомнилось (что пошло не так / что получилось):"
L["postmatch_save"]   = "Сохранить"
L["postmatch_skip"]   = "Пропустить"

L["col_when"]     = "Когда"
L["col_bracket"]  = "Сетка"
L["col_map"]      = "Карта"
L["col_result"]   = "Итог"
L["col_rating"]   = "Рейтинг"
L["col_enemy"]    = "Враги"
L["col_duration"] = "Время"
