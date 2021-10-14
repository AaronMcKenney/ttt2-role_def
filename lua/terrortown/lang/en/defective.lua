local L = LANG.GetLanguageTableReference("en")

-- GENERAL ROLE LANGUAGE STRINGS
L[DEFECTIVE.name] = "Defective"
L["info_popup_" .. DEFECTIVE.name] = [[You are Defective! A Defective plays in the traitor team but looks like a detective to everyone.]]
L["body_found_" .. DEFECTIVE.abbr] = "They were Defective!"
L["search_role_" .. DEFECTIVE.abbr] = "This person was Defective!"
L["target_" .. DEFECTIVE.name] = "Defective"
L["ttt2_desc_" .. DEFECTIVE.name] = [[You are Defective! A Defective plays in the traitor team but looks like a detective to everyone.]]

-- OTHER ROLE LANGUAGE STRINGS
L["inform_everyone_" .. DEFECTIVE.name] = "Someone is Defective!"
L["prevent_def_to_tra_comm_" .. DEFECTIVE.name] = "Defectives are not allowed to use traitor chat/voice."
L["prevent_tra_to_def_comm_" .. DEFECTIVE.name] = "Traitors are not allowed to use traitor chat/voice until every Defective is dead."
L["prevent_order_" .. DEFECTIVE.name] = "Can't buy items/weapons that defectives can't buy."

-- EVENT STRINGS
-- Need to be very specifically worded, due to how the system translates them.
--Attempts to use "prev_role" instead of "oldRole" failed to print the role, instead printing "{prev_role}". Seems like the messaging system hates underscores for string substitution"
L["title_event_def_disabled"] = "Defectives have been disabled as there are no Detectives"
L["desc_event_def_disabled"] = "{name} has been demoted from Defective to Traitor."
L["title_event_def_jam_det"] = "A Defective jammed special Detectives"
L["desc_event_def_jam_det"] = "A Defective has jammed {name}. Their role changed from {oldRole} to Detective."
L["title_event_def_demote_det"] = "A Defective demoted Detectives"
L["desc_event_def_demote_det"] = "{name} has been demoted from {oldRole} to Innocent."
L["title_event_def_undo_jam"] = "Jammed roles were returned as all Defectives are dead and can be revealed"
L["desc_event_def_undo_jam"] = "A Defective previously jammed {name}. Their previous role ({oldRole}) was returned to them."