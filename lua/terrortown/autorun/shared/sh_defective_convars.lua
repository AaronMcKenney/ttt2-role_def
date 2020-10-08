--ConVar syncing
CreateConVar("ttt2_defective_inform_everyone", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_shop_order_prevention", "0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_detective_immunity", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_gain_traitor_credits", "0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_can_see_traitors", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_can_be_seen_by_traitors", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_can_see_defectives", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_corpse_reveal_mode", "0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_special_det_handling_mode", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicDefectiveCVars", function(tbl)
	tbl[ROLE_DEFECTIVE] = tbl[ROLE_DEFECTIVE] or {}
	
	--# Send a popup message if there's a defective at the start of the round?
	--  ttt2_defective_inform_everyone [0/1] (default: 1)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_inform_everyone",
		checkbox = true,
		desc = "ttt2_defective_inform_everyone (Def: 1)"
	})
	
	--# Prevent the detective from purchasing items that aren't in the defective's shop?
	--  You can create your own custom shop for the defective via the "shopeditor" command.
	--  You can use this as a way to prevent the detective from purchasing a portable tester, golden deagle, etc. when a defective is active.
	--  Do not enable if ttt2_random_team_shops is enabled (may prevent dets from purchasing most things at random).
	--  ttt2_defective_shop_order_prevention [0/1] (default: 0)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_shop_order_prevention",
		checkbox = true,
		desc = "ttt2_defective_shop_order_prevention (Def: 0)"
	})
	
	--# Prevent all defectives and detectives from harming one another (unless all other members on their team are dead)?
	--  ttt2_defective_detective_immunity [0/1] (default: 1)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_detective_immunity",
		checkbox = true,
		desc = "ttt2_defective_detective_immunity (Def: 1)"
	})
	
	--# Should the defective gain credits from innocent kills (on top of gaining credits from being a "detective")?
	--  ttt2_defective_gain_traitor_credits [0/1] (default: 0)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_gain_traitor_credits",
		checkbox = true,
		desc = "ttt2_defective_gain_traitor_credits (Def: 0)"
	})
	
	--# Can the defective see their fellow team mates (e.g. traitors, bodyguards, etc.)?
	--  ttt2_defective_can_see_traitors [0/1] (default: 1)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_can_see_traitors",
		checkbox = true,
		desc = "ttt2_defective_can_see_traitors (Def: 1)"
	})
	
	--# Are traitors informed about who the defective is?
	--  ttt2_defective_can_be_seen_by_traitors [0/1] (default: 1)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_can_be_seen_by_traitors",
		checkbox = true,
		desc = "ttt2_defective_can_be_seen_by_traitors (Def: 1)"
	})
	
	--# Can the defective see their fellow defectives?
	--  ttt2_defective_can_see_defectives [0/1] (default: 1)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_can_see_defectives",
		checkbox = true,
		desc = "ttt2_defective_can_see_defectives (Def: 1)"
	})
	
	--# When should def's true role be revealed?
	--  ttt2_defective_corpse_reveal_mode [0..3] (default: 0)
	--  # 0: Search never reveals def's role
	--  # 1: Search reveals def's role when all dets and defs are dead
	--  # 2: Search reveals def's role when all defs are dead
	--  # 3: Search reveals def's role
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_corpse_reveal_mode",
		combobox = true,
		desc = "ttt2_defective_corpse_reveal_mode (Def: 0)",
		choices = {
			"0 - Search never reveals def's role",
			"1 - Search reveals def's role when all dets and defs are dead",
			"2 - Search reveals def's role when all defs are dead",
			"3 - Search reveals def's role"
		},
		numStart = 0
	})
	
	--# How should special detectives (ex. Sheriff, Vigilante, Sniffer) be handled when the defective is in play?
	--  ttt2_defective_special_det_handling_mode [0..2] (default: 1)
	--  # 0: Do not alter special dets
	--  # 1: Force all special dets to be normal dets
	--  # 2: Force all special dets to be normal dets, but give them back their roles if: all defs are dead, defs can be revealed, and the former special det didn't undergo a role change (ex. did not become infected)
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_special_det_handling_mode",
		combobox = true,
		desc = "ttt2_defective_special_det_handling_mode (Def: 1)",
		choices = {
			"0 - Do not alter special dets",
			"1 - Force all special dets to be normal dets",
			"2 - Force all special dets to be normal dets until all defs are dead",
		},
		numStart = 0
	})
end)

hook.Add("TTT2SyncGlobals", "AddDefectiveGlobals", function()
	SetGlobalBool("ttt2_defective_inform_everyone", GetConVar("ttt2_defective_inform_everyone"):GetBool())
	SetGlobalBool("ttt2_defective_shop_order_prevention", GetConVar("ttt2_defective_shop_order_prevention"):GetBool())
	SetGlobalBool("ttt2_defective_detective_immunity", GetConVar("ttt2_defective_detective_immunity"):GetBool())
	SetGlobalBool("ttt2_defective_gain_traitor_credits", GetConVar("ttt2_defective_gain_traitor_credits"):GetBool())
	SetGlobalBool("ttt2_defective_can_see_traitors", GetConVar("ttt2_defective_can_see_traitors"):GetBool())
	SetGlobalBool("ttt2_defective_can_be_seen_by_traitors", GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool())
	SetGlobalBool("ttt2_defective_can_see_defectives", GetConVar("ttt2_defective_can_see_defectives"):GetBool())
	SetGlobalInt("ttt2_defective_corpse_reveal_mode", GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt())
	SetGlobalInt("ttt2_defective_special_det_handling_mode", GetConVar("ttt2_defective_special_det_handling_mode"):GetInt())
end)

cvars.AddChangeCallback("ttt2_defective_inform_everyone", function(name, old, new)
	SetGlobalBool("ttt2_defective_inform_everyone", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_shop_order_prevention", function(name, old, new)
	SetGlobalBool("ttt2_defective_shop_order_prevention", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_detective_immunity", function(name, old, new)
	SetGlobalBool("ttt2_defective_detective_immunity", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_gain_traitor_credits", function(name, old, new)
	SetGlobalBool("ttt2_defective_gain_traitor_credits", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_can_see_traitors", function(name, old, new)
	SetGlobalBool("ttt2_defective_can_see_traitors", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_can_be_seen_by_traitors", function(name, old, new)
	SetGlobalBool("ttt2_defective_can_be_seen_by_traitors", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_can_see_defectives", function(name, old, new)
	SetGlobalBool("ttt2_defective_can_see_defectives", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_corpse_reveal_mode", function(name, old, new)
	SetGlobalInt("ttt2_defective_corpse_reveal_mode", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_defective_special_det_handling_mode", function(name, old, new)
	SetGlobalInt("ttt2_defective_special_det_handling_mode", tonumber(new))
end)
