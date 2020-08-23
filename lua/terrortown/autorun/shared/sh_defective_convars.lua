--ConVar syncing
CreateConVar("ttt2_defective_confirm_as_detective", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_reveal_true_role", "0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_defective_jam_special_roles", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicDefectiveCVars", function(tbl)
	tbl[ROLE_DEFECTIVE] = tbl[ROLE_DEFECTIVE] or {}
	
	--"Defective looks like a detective when searched (Def: 1)"
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_confirm_as_detective",
		checkbox = true,
		desc = "ttt2_defective_confirm_as_detective (Def: 1)"
	})
	--"Defective's true role is revealed when searched if every detective and defective is dead (Def: 0)"
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_reveal_true_role",
		checkbox = true,
		desc = "ttt2_defective_reveal_true_role (Def: 0)"
	})
	--"Special detective roles (ex. sniffer) appear as normal detectives (Def: 1)"
	table.insert(tbl[ROLE_DEFECTIVE], {
		cvar = "ttt2_defective_jam_special_roles",
		checkbox = true,
		desc = "ttt2_defective_jam_special_roles (Def: 1)"
	})
end)

hook.Add("TTT2SyncGlobals", "AddDefectiveGlobals", function()
	SetGlobalBool("ttt2_defective_confirm_as_detective", GetConVar("ttt2_defective_confirm_as_detective"):GetBool())
	SetGlobalBool("ttt2_defective_reveal_true_role", GetConVar("ttt2_defective_reveal_true_role"):GetBool())
	SetGlobalBool("ttt2_defective_jam_special_roles", GetConVar("ttt2_defective_jam_special_roles"):GetBool())
end)

cvars.AddChangeCallback("ttt2_defective_confirm_as_detective", function(name, old, new)
	SetGlobalBool("ttt2_defective_confirm_as_detective", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_reveal_true_role", function(name, old, new)
	SetGlobalBool("ttt2_defective_reveal_true_role", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_defective_jam_special_roles", function(name, old, new)
	SetGlobalBool("ttt2_defective_jam_special_roles", tobool(tonumber(new)))
end)
