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
L["prevent_inspection_exist_" .. DEFECTIVE.name] = "Проверка недоступна, потому что существует дефектив."
L["prevent_inspection_live_" .. DEFECTIVE.name] = "Осмотр недоступен, потому что дефекив живет."
L["prevent_confirmation_exist_" .. DEFECTIVE.name] = "Подтверждение недоступно, поскольку существует дефектив."
L["prevent_confirmation_live_" .. DEFECTIVE.name] = "Подтверждение недоступно, потому что дефектив жив."
L["prevent_def_to_tra_comm_" .. DEFECTIVE.name] = "Дефективам не разрешается использовать текстовый/голосовой чат предателя."
L["prevent_tra_to_def_comm_" .. DEFECTIVE.name] = "Предателям не разрешается использовать текстовый/голосовой чат предателей, пока каждый дефектив не будет мёртв."
L["prevent_order_" .. DEFECTIVE.name] = "Невозможно купить предметы/оружие, которые нельзя купить дефективам."