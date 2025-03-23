local L = LANG.GetLanguageTableReference("zh_hans")

-- GENERAL ROLE LANGUAGE STRINGS
L[DEFECTIVE.name] = "假探"
L["info_popup_" .. DEFECTIVE.name] = [[你是假探!一个有假探的人在叛徒队打球,但在每个人看来都像个侦探.]]
L["body_found_" .. DEFECTIVE.abbr] = "他们是假探!"
L["search_role_" .. DEFECTIVE.abbr] = "这个人是假探!"
L["target_" .. DEFECTIVE.name] = "假探"
L["ttt2_desc_" .. DEFECTIVE.name] = [[你是假探!一个有假探的人在叛徒队打球,但在每个人看来都像个侦探.]]

-- OTHER ROLE LANGUAGE STRINGS
L["inform_everyone_" .. DEFECTIVE.name] = "有人是假探!"
L["prevent_def_to_tra_comm_" .. DEFECTIVE.name] = "不允许叛徒使用叛徒聊天/语音."
L["prevent_tra_to_def_comm_" .. DEFECTIVE.name] = "在每一个假探消失之前,叛徒都不允许使用叛徒聊天/语音."
L["prevent_order_" .. DEFECTIVE.name] = "无法购买叛逃者无法购买的物品/武器."

-- EVENT STRINGS
-- Need to be very specifically worded, due to how the system translates them.
--Attempts to use "prev_role" instead of "oldRole" failed to print the role, instead printing "{prev_role}". Seems like the messaging system hates underscores for string substitution"
L["title_event_def_disabled"] = "由于没有侦探,叛逃者已被禁用"
L["desc_event_def_disabled"] = "{name} 已从假探降为叛徒."
L["title_event_def_jam_det"] = "有假探的塞满了特别侦探"
L["desc_event_def_jam_det"] = "假探已阻塞{name}.他们的角色从{oldRole}更改为侦探."
L["title_event_def_demote_det"] = "有假探的降级侦探"
L["desc_event_def_demote_det"] = "{name}已从{oldRole}降级为无辜."
L["title_event_def_undo_jam"] = "由于所有的叛逃者都已死亡,并且可以被揭露,所以拥挤的角色被退回"
L["desc_event_def_undo_jam"] = "以前阻塞的{name}有假探.他们以前的角色({oldRole})已返回给他们."

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
