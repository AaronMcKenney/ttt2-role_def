--ConVar syncing
CreateConVar("ttt2_defective_inform_everyone", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
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
	--  ttt2_defective_special_det_handling_mode [0..3] (default: 1)
	--  # 0: Do not alter special dets
	--  # 1: Force all special dets to be normal dets
	--  # 2: Force all special dets to be normal dets, but give them back their roles if: all defs are dead, defs can be revealed, and the former special det didn't undergo a role change (ex. did not become infected)
	--  # 3: Provide the possibility for the def to be disguised as a special det
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_special_det_handling_mode",
		combobox = true,
		desc = "ttt2_defective_special_det_handling_mode (Def: 0)",
		choices = {
			"0 - Do not alter special dets",
			"1 - Force all special dets to be normal dets",
			"2 - Force all special dets to be normal dets until all defs are dead",
			"3 - Provide the possibility for the def to be disguised as a special det"
		},
		numStart = 0
	})
end)

hook.Add("TTT2SyncGlobals", "AddDefectiveGlobals", function()
	SetGlobalBool("ttt2_defective_inform_everyone", GetConVar("ttt2_defective_inform_everyone"):GetBool())
	SetGlobalInt("ttt2_defective_corpse_reveal_mode", GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt())
	SetGlobalInt("ttt2_defective_special_det_handling_mode", GetConVar("ttt2_defective_special_det_handling_mode"):GetInt())
end)

cvars.AddChangeCallback("ttt2_defective_inform_everyone", function(name, old, new)
	SetGlobalBool("ttt2_defective_inform_everyone", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_corpse_reveal_mode", function(name, old, new)
	SetGlobalInt("ttt2_defective_corpse_reveal_mode", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_defective_special_det_handling_mode", function(name, old, new)
	SetGlobalInt("ttt2_defective_special_det_handling_mode", tonumber(new))
end)
