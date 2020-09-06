--ConVar syncing
CreateConVar("ttt2_defective_corpse_reveal_mode", "0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_special_det_handling_mode", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicDefectiveCVars", function(tbl)
	tbl[ROLE_DEFECTIVE] = tbl[ROLE_DEFECTIVE] or {}
	
	--# When should def's true role be revealed?
	--  ttt2_defective_corpse_reveal_mode [0..2] (default: 0)
	--  # 0: Never reveal the def's role when searched
	--  # 1: Reveal def's role when all dets and defs are dead
	--  # 2: Reveal def's role when searched
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_corpse_reveal_mode",
		combobox = true,
		desc = "ttt2_defective_corpse_reveal_mode (Def: 0)",
		choices = {
			"0 - Never reveal the def's role when searched",
			"1 - Reveal def's role when all dets and defs are confirmed dead",
			"2 - Reveal def's role when searched"
		},
		numStart = 0
	})
	
	--# How should special detectives (ex. Sheriff, Vigilante, Sniffer) be handled when the defective is in play?
	--  ttt2_defective_special_det_handling_mode [0..2] (default: 1)
	--  # 0: Do not alter special dets
	--  # 1: Force all special dets to be normal dets
	--  # 2: Provide the possibility for the def to be disguised as a special det
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_special_det_handling_mode",
		combobox = true,
		desc = "ttt2_defective_special_det_handling_mode (Def: 0)",
		choices = {
			"0 - Do not alter special dets",
			"1 - Force all special dets to be normal dets",
			"2 - Provide the possibility for the def to be disguised as a special det"
		},
		numStart = 0
	})
end)

hook.Add("TTT2SyncGlobals", "AddDefectiveGlobals", function()
	SetGlobalInt("ttt2_defective_corpse_reveal_mode", GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt())
	SetGlobalInt("ttt2_defective_special_det_handling_mode", GetConVar("ttt2_defective_special_det_handling_mode"):GetInt())
end)

cvars.AddChangeCallback("ttt2_defective_corpse_reveal_mode", function(name, old, new)
	SetGlobalInt("ttt2_defective_corpse_reveal_mode", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_defective_special_det_handling_mode", function(name, old, new)
	SetGlobalInt("ttt2_defective_special_det_handling_mode", tonumber(new))
end)
