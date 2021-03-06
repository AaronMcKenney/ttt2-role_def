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
L["prevent_inspection_exist_" .. DEFECTIVE.name] = "Die Untersuchung ist nicht möglich, da es einen Defektiv gibt."
L["prevent_inspection_live_" .. DEFECTIVE.name] = "Die Untersuchung ist nicht möglich, da ein Defektiv lebt."
L["prevent_confirmation_exist_" .. DEFECTIVE.name] = "Die Bestätigung ist nicht möglich, da es einen Defektiv gibt."
L["prevent_confirmation_live_" .. DEFECTIVE.name] = "Die Bestätigung ist nicht möglich, da ein Defektiv lebt."
L["prevent_def_to_tra_comm_" .. DEFECTIVE.name] = "Defektive dürfen den Verräterchat / Voicechat nicht benutzen."
L["prevent_tra_to_def_comm_" .. DEFECTIVE.name] = "Verräter dürfen den Verräterchat / Voicechat nicht benutzen, solange ein Defektiv lebt."
L["prevent_order_" .. DEFECTIVE.name] = "Kann keine Items kaufen, die Defektive nicht kaufen können."