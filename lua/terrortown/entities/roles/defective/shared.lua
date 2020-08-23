if SERVER then
	--The Detective's icon
	--resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_det.vmt")
	--The Defective's icon
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_def.vmt")
end

function ROLE:PreInitialize()
	--The Detective's color
	--self.color = Color(31, 77, 191, 255)
	--The Defective's color
	self.color = Color(58, 27, 169, 255)
	
	self.abbr = "def"
	self.scoreKillsMultiplier = 1
	self.scoreTeamKillsMultiplier = -8
	self.fallbackTable = {}
	self.unknownTeam = true
	
	--The defective may pick up any credits they find off of dead bodies (especially their fellow traitors)
	--However, they already gain credits in the same way as the detective, so it would be double-dipping to give them credits in the same way as the traitor.
	--This does in fact provide an incentive to the defective to kill their fellow traitors.
	self.preventFindCredits = false
	self.preventKillCredits = true
	self.preventTraitorAloneCredits = true
	
	self.defaultTeam = TEAM_TRAITOR
	self.defaultEquipment = SPECIAL_EQUIPMENT
	
	-- conVarData
	self.conVarData = {
		pct = 0.13,
		maximum = 1,
		minPlayers = 8,
		minKarma = 600,
		
		--Detective defaults replicated here
		credits = 1,
		creditsTraitorKill = 0,
		creditsTraitorDead = 1,
		
		togglable = true,
		shopFallback = SHOP_FALLBACK_DETECTIVE
	}
end

function ROLE:Initialize()
	roles.SetBaseRole(self, ROLE_TRAITOR)
end

if SERVER then
	hook.Add("TTT2CheckCreditAward", "DefectiveCreditAward", function(victim, attacker)
		if GetRoundState() ~= ROUND_ACTIVE then
			return
		end
		
		if not IsValid(victim) then
			return
		end
		
		if not IsValid(attacker) or not attacker:IsPlayer() or not attacker:IsActive() then
			return
		end
		
		--This is pretty much copy/pasted from how Detective gets credits in CheckCreditAward()
		--Except here we award credits to the defective if either a det or a def killed a traitor.
		if (attacker:GetBaseRole() == ROLE_DETECTIVE and not victim:IsInTeam(attacker))or (attacker:GetSubRole() == ROLE_DEFECTIVE and victim:IsInTeam(attacker)) then
			local amt = math.ceil(ConVarExists("ttt_def_credits_traitordead") and GetConVar("ttt_def_credits_traitordead"):GetInt() or 1)
			local plys = player.GetAll()
			
			for i = 1, #plys do
				local ply = plys[i]

				if ply:IsActive() and ply:IsShopper() and ply:GetSubRole() == ROLE_DEFECTIVE then
					ply:AddCredits(amt)
				end
			end
			
			LANG.Msg(GetRoleChatFilter(ROLE_DEFECTIVE, true), "credit_all", {num = amt})
		end
	end)
	
	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		--print("DEF_DEBUG GiveRoleLoadout: " .. ply:GetName() .. " is a Defective")
		
		--Send the role to everyone (role is changed during SendFullStateUpdate())
		--Sending this information here also handles cases where the def respawns, as without a SendFullStateUpdate() call their role could be revealed regardless of ConVar settings.
		SendPlayerToEveryone(ply)
		SendFullStateUpdate()
		
		--While GiveEquipmentItem() would be the better function to use here, it actually fails to give the defective the DNA scanner. Currently in the TTT2 codebase, Give() is used for the detective, so it should be fine here for now.
		ply:Give("weapon_ttt_wtester")
		
		--TODO: Consider dynamically adding weapons based on what the detective starts with (which may be different from server to server)
		--print("ROLE_DETECTIVE: " .. ROLE_DETECTIVE)
		--for _,wep in ipairs(weapons.GetList()) do
		--	if wep.ClassName and wep.InLoadoutFor then
		--		print("WEP ClassName: " .. wep.ClassName)
		--		PrintTable(wep.InLoadoutFor)
		--		if wep.InLoadoutFor[ROLE_DETECTIVE] ~= nil then --NOTE: There is a bug here.
		--			ply:GiveEquipmentItem(wep.ClassName)
		--		end
		--	end
		--end
	end
	
	--Not only does this not work, but the detective also does not necessarily have their DNA Scanner removed.
	--function ROLE:RemoveRoleLoadout(ply, isRoleChange)
	--	ply:RemoveEquipmentItem("weapon_ttt_wtester")
	--end
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2SpecialRoleSyncing", "DefectiveSpecialRoleSyncing", function (ply, tbl)
		if not ply or GetRoundState() == ROUND_POST then 
			return
		end
		
		if GetConVar("ttt2_defective_reveal_true_role"):GetBool() then
			local det_def_alive = false
			for ply_i in pairs(tbl) do
				if ply_i:IsTerror() and ply_i:Alive() and (ply_i:GetBaseRole() == ROLE_DETECTIVE or ply_i:GetBaseRole() == ROLE_DEFECTIVE) then
					det_def_alive = true
					break
				end
				
				--Return before we alter the defective's apparent role.
				if not det_def_alive then
					return
				end
			end
		end
		
		local def_exists = false
		for ply_i in pairs(tbl) do
			--Handle how everyone sees a defective
			if ply_i:IsTerror() and ply_i ~= ply and ply_i:GetSubRole() == ROLE_DEFECTIVE then
				def_exists = true
				
				if not ply:HasTeam(TEAM_TRAITOR) then
					--Make the defective look like a detective to all non-traitors.
					if ply_i:Alive() or GetConVar("ttt2_defective_confirm_as_detective"):GetBool() then
						tbl[ply_i] = {ROLE_DETECTIVE, TEAM_INNOCENT}
					end
				else
					--Reveal the defective's role to traitors
					tbl[ply_i] = {ROLE_DEFECTIVE, TEAM_TRAITOR}
				end
			end
			
			--Allow for the defective to see their fellow traitors.
			if ply_i:IsTerror() and ply_i ~= ply and ply:GetSubRole() == ROLE_DEFECTIVE and ply_i:HasTeam(TEAM_TRAITOR) then
				tbl[ply_i] = {ply_i:GetSubRole(), ply_i:GetTeam()}
			end
		end
		
		if def_exists and GetConVar("ttt2_defective_jam_special_roles"):GetBool() then
			--Make every detective have the same apparent role if the defective is still kicking.
			for ply_i in pairs(tbl) do
				if ply_i:IsTerror() and ply_i:Alive() and ply_i ~= ply and ply_i:GetBaseRole() == ROLE_DETECTIVE then
					tbl[ply_i] = {ROLE_DETECTIVE, TEAM_INNOCENT}
				end
			end
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2OverrideDisabledSync", "DefectiveOverrideDisabledSync", function(ply, target)
		if not GetConVar("ttt2_defective_confirm_as_detective"):GetBool() or not GetConVar("ttt2_defective_jam_special_roles"):GetBool() or GetRoundState() == ROUND_POST then
			return
		end
		
		local def_exists = false
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_DEFECTIVE then
				def_exists = true
				break
			end
		end
		
		if def_exists and ply:HasTeam(TEAM_INNOCENT) and target:GetBaseRole() == ROLE_DETECTIVE then
			return true
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2ModifyRadarRole", "DefectiveModifyRadarRole", function(ply, target)
		--Make defectives look like detectives when an innocent role uses a radar.
		if ply:HasTeam(TEAM_INNOCENT) and target:GetSubRole() == ROLE_DEFECTIVE then
			return ROLE_DETECTIVE, TEAM_INNOCENT
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTTCanSearchCorpse", "DefectiveChangeCorpse", function(ply, corpse)
		if not corpse then
			return
		end
		
		--If the corpse is a def or the corpse is a special det, pretend it is a simple det depending on ConVars.
		if (GetConVar("ttt2_defective_confirm_as_detective"):GetBool() and corpse.was_role == ROLE_DEFECTIVE) or (GetConVar("ttt2_defective_jam_special_roles"):GetBool() and roles.GetByIndex(corpse.was_role):GetBaseRole() == ROLE_DETECTIVE) and not corpse.def_reveal_true_role then
			corpse.show_as_det = true
		else
			corpse.show_as_det = false
		end
		
		--Show all defectives (and potentially all special detective roles) as detectives when searched.
		if corpse.show_as_det then
			corpse.was_role = ROLE_DETECTIVE
			corpse.was_team = TEAM_INNOCENT
			corpse.role_color = DETECTIVE.color
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2ConfirmPlayer", "DefectiveChangeRoleToDetective", function(confirmed, finder, corpse)
		if GetConVar("ttt2_defective_confirm_as_detective"):GetBool() and IsValid(confirmed) and corpse.show_as_det then
			--Confirm player as a detective
			confirmed:ConfirmPlayer(true)
			SendRoleListMessage(ROLE_DETECTIVE, TEAM_INNOCENT, {confirmed:EntIndex()})
			SCORE:HandleBodyFound(finder, confirmed)
			
			return false
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTTBodyFound", "DefectiveBodyFound", function(_, confirmed, corpse)
		if not GetConVar("ttt2_defective_confirm_as_detective"):GetBool() or not GetConVar("ttt2_defective_reveal_true_role"):GetBool() then
			return
		end
		
		--Only continue if the dead confirmed player is either a detective or a defective.
		if not IsValid(confirmed) or (not confirmed:GetBaseRole() == ROLE_DETECTIVE and confirmed:GetSubRole() ~= ROLE_DEFECTIVE) then
			return
		end
		
		--Only continue if all detectives and defectives are dead
		for _, ply in ipairs(player.GetAll()) do
			if ply:IsTerror() and ply:Alive() and (ply:GetBaseRole() == ROLE_DETECTIVE or ply:GetSubRole() == ROLE_DEFECTIVE) then
				return
			end
		end
		
		for _, ply in ipairs(player.GetAll()) do
			local ply_corpse = ply.server_ragdoll
			
			if not ply_corpse or not ply:GetNWBool("body_found", false) then 
				continue
			end
			
			--Reveal the detective's and defective's true roles.
			if (GetConVar("ttt2_defective_jam_special_roles"):GetBool() and ply:GetBaseRole() == ROLE_DETECTIVE) or ply:GetSubRole() == ROLE_DEFECTIVE then
				local subrole = ply:GetSubRole()
				local team = ply:GetTeam()
				local srd = ply:GetSubRoleData()
				
				ply_corpse.was_role = subrole
				ply_corpse.was_team = team
				ply_corpse.role_color = srd.color
				ply_corpse.show_as_det = false
				ply_corpse.def_reveal_true_role = true
				
				SendRoleListMessage(subrole, team, {ply:EntIndex()})
			end
		end
	end)
end