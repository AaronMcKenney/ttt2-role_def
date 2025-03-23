local L = LANG.GetLanguageTableReference("de")

-- GENERAL ROLE LANGUAGE STRINGS
L[DEFECTIVE.name] = "Defektiv"
L["info_popup_" .. DEFECTIVE.name] = [[Du bist Defektiv! Ein Defektiv spielt im Verräterteam, sieht aber wie ein normaler Detektiv aus.]]
L["body_found_" .. DEFECTIVE.abbr] = "Er war Defektiv!"
L["search_role_" .. DEFECTIVE.abbr] = "Diese Person war Defektiv!"
L["target_" .. DEFECTIVE.name] = "Defektiv"
L["ttt2_desc_" .. DEFECTIVE.name] = [[Du bist Defektiv! Ein Defektiv spielt im Verräterteam, sieht aber wie ein normaler Detektiv aus.]]

-- OTHER ROLE LANGUAGE STRINGS
L["inform_everyone_" .. DEFECTIVE.name] = "Jemand ist Defektiv!"
L["prevent_def_to_tra_comm_" .. DEFECTIVE.name] = "Defektive dürfen den Verräterchat / Voicechat nicht benutzen."
L["prevent_tra_to_def_comm_" .. DEFECTIVE.name] = "Verräter dürfen den Verräterchat / Voicechat nicht benutzen, solange ein Defektiv lebt."
L["prevent_order_" .. DEFECTIVE.name] = "Kann keine Items kaufen, die Defektive nicht kaufen können."

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

-- CONVAR STRINGS
--L["label_defective_inform_everyone"] = "Display pop-up message at round start"
--L["label_defective_color_mode"] = "The Defective's role color"
--L["label_defective_color_mode_0"] = "0: Default color (purple)"
--L["label_defective_color_mode_1"] = "1: Traitor color (a shade of red)"
--L["label_defective_shop_order_prevention"] = "Prevent Det from purchasing non-Def items"
--L["label_defective_detective_immunity"] = "Prevent Defs and Dets from harming one another where possible"
--L["label_defective_can_see_traitors"] = "The Def can see their fellow team mates"
--L["label_defective_can_be_seen_by_traitors"] = "Traitors are informed about who the Def is"
--L["label_defective_can_see_defectives"] = "Defs can see their fellow Defs"
--L["label_defective_corpse_reveal_mode"] = "Searching a Def's corpse will:"
--L["label_defective_corpse_reveal_mode_0"] = "0: Never reveals the Def's role"
--L["label_defective_corpse_reveal_mode_1"] = "1: Reveals def's role when all dets and defs are dead"
--L["label_defective_corpse_reveal_mode_2"] = "2: Reveals def's role when all defs are dead"
--L["label_defective_corpse_reveal_mode_3"] = "3: Always reveals the Def's role"
--L["label_defective_special_det_handling_mode"] = "How special Dets are handled"
--L["label_defective_special_det_handling_mode_0"] = "0: Do not alter special Dets"
--L["label_defective_special_det_handling_mode_1"] = "1: Force special Dets to be normal Dets"
--L["label_defective_special_det_handling_mode_2"] = "2: Force special Dets to be normal Dets until all Defs are dead"
--L["label_defective_special_det_handling_mode_3"] = "3: Do not alter special Dets. Def may take visage of special Det"
--L["label_defective_disable_spawn_if_no_detective"] = "Demote Def to Traitor if no Dets are present"
--L["label_defective_demote_detective_pct"] = "Chance that a Det will be demoted to Inno for every Def"
