local L = LANG.GetLanguageTableReference("ru")

-- GENERAL ROLE LANGUAGE STRINGS
L[DEFECTIVE.name] = "Дефектив"
L["info_popup_" .. DEFECTIVE.name] = [[Вы дефектив! Дефектив играет в команде предателей, но для всех выглядит как детектив.]]
L["body_found_" .. DEFECTIVE.abbr] = "Он был дефективом!"
L["search_role_" .. DEFECTIVE.abbr] = "Этот человек был дефективом!"
L["target_" .. DEFECTIVE.name] = "Дефектив"
L["ttt2_desc_" .. DEFECTIVE.name] = [[Вы дефектив! Дефектив играет в команде предателей, но для всех выглядит как детектив.]]

-- OTHER ROLE LANGUAGE STRINGS
L["inform_everyone_" .. DEFECTIVE.name] = "Кто-то дефектив!"
L["prevent_def_to_tra_comm_" .. DEFECTIVE.name] = "Дефективам не разрешается использовать текстовый/голосовой чат предателя."
L["prevent_tra_to_def_comm_" .. DEFECTIVE.name] = "Предателям не разрешается использовать текстовый/голосовой чат предателей, пока каждый дефектив не будет мёртв."
L["prevent_order_" .. DEFECTIVE.name] = "Невозможно купить предметы/оружие, которые нельзя купить дефективам."

-- EVENT STRINGS
-- Need to be very specifically worded, due to how the system translates them.
--Attempts to use "prev_role" instead of "oldRole" failed to print the role, instead printing "{prev_role}". Seems like the messaging system hates underscores for string substitution"
--L["title_event_def_disabled"] = "Defectives have been disabled as there are no Detectives"
--L["desc_event_def_disabled"] = "{name} has been demoted from Defective to Traitor."
--L["title_event_def_jam_det"] = "A Defective jammed special Detectives"
--L["desc_event_def_jam_det"] = "A Defective has jammed {name}. Their role changed from {oldRole} to Detective."
--L["title_event_def_demote_det"] = "A Defective demoted Detectives"
--L["desc_event_def_demote_det"] = "{name} has been demoted from {oldRole} to Innocent."
--L["title_event_def_undo_jam"] = "Jammed roles were returned as all Defectives are dead and can be revealed"
--L["desc_event_def_undo_jam"] = "A Defective previously jammed {name}. Their previous role ({oldRole}) was returned to them."