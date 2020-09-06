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
	--CONSTANTS
	--ttt2_defective_corpse_reveal_mode enum
	local REVEAL_MODE = {NEVER = 0, ALL_DEAD = 1, ON_DEATH = 2}
	--ttt2_defective_det_handling_mode enum
	local SPECIAL_DET_MODE = {NEVER = 0, JAM = 1, MIMIC = 2}
	
	local function AtLeastOneDefExists()
		for _, ply in pairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_DEFECTIVE then
				return true
			end
		end
	end
	
	local function AtLeastOneDefLives()
		for _, ply in pairs(player.GetAll()) do
			if ply:IsTerror() and ply:Alive() and ply:GetSubRole() == ROLE_DEFECTIVE then
				return true
			end
		end
	end
	
	local function AtLeastOneDefOrDetLives()
		for _, ply in pairs(player.GetAll()) do
			if ply:IsTerror() and ply:Alive() and (ply:GetBaseRole() == ROLE_DETECTIVE or ply:GetSubRole() == ROLE_DEFECTIVE) then
				
				return true
			end
		end
	end
	
	local function CanADeadDefBeRevealed()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		if m == REVEAL_MODE.NEVER or (m == REVEAL_MODE.ALL_DEAD and AtLeastOneDefOrDetLives()) then
			return false
		else
			return true
		end
	end
	
	local function AllowDetsToInspect()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		
		if GetConVar("ttt2_inspect_detective_only"):GetBool() and ((m == REVEAL_MODE.ON_DEATH and AtLeastOneDefLives()) or (m ~= REVEAL_MODE.ON_DEATH and AtLeastOneDefExists())) then
			--Prevent dets from inspecting if doing so could be used to reveal the defective.
			return false
		end
		
		return true
	end
	
	local function AllowDetsToConfirm()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		
		if GetConVar("ttt2_confirm_detective_only"):GetBool() and ((m == REVEAL_MODE.ON_DEATH and AtLeastOneDefLives()) or (m ~= REVEAL_MODE.ON_DEATH and AtLeastOneDefExists())) then
			--Prevent dets from confirming if doing so could be used to reveal the defective.
			return false
		end
		
		return true
	end
	
	local function SendDefectiveInspectionNotice(ply)
		if GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt() == REVEAL_MODE.ON_DEATH then
			LANG.Msg(ply, "prevent_inspection_live_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		else
			LANG.Msg(ply, "prevent_inspection_exist_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		end
	end
	
	local function SendDefectiveConfirmationNotice(ply)
		if GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt() == REVEAL_MODE.ON_DEATH then
			LANG.Msg(ply, "prevent_confirmation_live_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		else
			LANG.Msg(ply, "prevent_confirmation_exist_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		end
	end
	
	local function JamDetective(ply, base_role, sub_role)
		if ply:IsTerror() and ply:Alive() and base_role == ROLE_DETECTIVE and sub_role ~= ROLE_DETECTIVE then
			--This timer is a hack to give time for the player to finish setup for their current role before we change it to their new role. It won't work if the current role takes a lot of time to setup.
			--Specifically prevents situations where a sniffer is given their lens, but then changes to a detective before the lens can be properly removed.
			timer.Simple(0.1, function()
				--Their former roles may be given back to them, depending on ttt2_defective_reveal_true_role
				ply:SetRole(ROLE_DETECTIVE)
				--Call this function whenever a role change occurs during an active round.
				SendFullStateUpdate()
			end)
		end
	end
	
	hook.Add("TTTBeginRound", "DefectiveBeginRound", function()
		if GetConVar("ttt2_defective_special_det_handling_mode"):GetInt() == SPECIAL_DET_MODE.JAM and AtLeastOneDefExists() then
			--Force all special detectives to be normal detectives, in case they have some special equipment or ability that could instantly be used to make them trustworthy.
			for _, ply in pairs(player.GetAll()) do
				JamDetective(ply, ply:GetBaseRole(), ply:GetSubRole())
			end
		end
	end)
	
	hook.Add("TTT2UpdateSubrole", "DefectiveUpdateSubrole", function(self, oldSubrole, subrole)
		if GetConVar("ttt2_defective_special_det_handling_mode"):GetInt() == SPECIAL_DET_MODE.JAM and AtLeastOneDefExists() then
			JamDetective(self, roles.GetByIndex(subrole):GetBaseRole(), subrole)
		end
	end)
	
	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		--print("DEF_DEBUG GiveRoleLoadout: " .. ply:GetName() .. " is a Defective")
		
		--Send the role to everyone (role is changed during SendFullStateUpdate())
		--Sending this information here also handles cases where the def respawns, as without a SendFullStateUpdate() call their role could be revealed regardless of ConVar settings.
		SendPlayerToEveryone(ply)
		SendFullStateUpdate()
		
		--While GiveEquipmentItem() would be the better function to use here, it actually fails to give the defective the DNA scanner. Currently in the TTT2 codebase, Give() is used for the detective, so it should be fine here for now.
		--Also, unlike other roles, it appears that the normal detective does not lose their equipment item should they change roles or die.
		ply:Give("weapon_ttt_wtester")
	end
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2SpecialRoleSyncing", "DefectiveSpecialRoleSyncing", function (ply, tbl)
		if not ply or GetRoundState() == ROUND_POST then 
			return
		end
		
		local can_reveal_dead_def = CanADeadDefBeRevealed()
		
		for ply_i in pairs(tbl) do
			--Handle how everyone sees a defective
			if ply_i:IsTerror() and ply_i ~= ply and ply_i:GetSubRole() == ROLE_DEFECTIVE then
				if not ply_i:Alive() and can_reveal_dead_def then
					--Do not mess with dead def's apparent role.
					continue
				end
				
				if not ply:HasTeam(TEAM_TRAITOR) then
					--TODO: Hookup with SPECIAL_DET_MODE.MIMIC
					--TODO: Abstract "ROLE_DETECTIVE" so that other roles can be used here.
					
					--Make the defective look like a detective to all non-traitors.
					tbl[ply_i] = {ROLE_DETECTIVE, TEAM_INNOCENT}
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
	end)
	
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
		--We also award credits to the det if the def killed a traitor.
		if (attacker:GetBaseRole() == ROLE_DETECTIVE and not victim:IsInTeam(attacker)) or (attacker:GetSubRole() == ROLE_DEFECTIVE and victim:IsInTeam(attacker)) then
			local amt = math.ceil(ConVarExists("ttt_det_credits_traitordead") and GetConVar("ttt_det_credits_traitordead"):GetInt() or 1)
			local plys = player.GetAll()
			
			for i = 1, #plys do
				local ply = plys[i]
				
				--Give credits to the def regardless.
				--But only give credits to the det if the attacker is a def (to avoid double dipping)
				if ply:IsActive() and ply:IsShopper() and (ply:GetSubRole() == ROLE_DEFECTIVE or (attacker:GetSubRole() == ROLE_DEFECTIVE and ply:GetBaseRole() == ROLE_DETECTIVE)) then
					ply:AddCredits(amt)
				end
			end
			
			LANG.Msg(GetRoleChatFilter(ROLE_DEFECTIVE, true), "credit_all", {num = amt})
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2ModifyRadarRole", "DefectiveModifyRadarRole", function(ply, target)
		--Make defectives look like detectives when an innocent role uses a radar.
		if not ply:HasTeam(TEAM_TRAITOR) and target:GetSubRole() == ROLE_DEFECTIVE then
			return ROLE_DETECTIVE, TEAM_INNOCENT
		end
	end)
	
	--TODO: REMOVE (Not supporting giving players their roles back right now)
	--hook.Add("TTT2PostPlayerDeath", "DefectivePostPlayerDeath", function(victim, inflictor, attacker)
	--	if GetRoundState() ~= ROUND_ACTIVE or not (GetConVar("ttt2_defective_jam_special_roles"):GetBool() and GetConVar("ttt2_defective_reveal_true_role"):GetBool()) then
	--		return
	--	end
	--	
	--	if not IsValid(victim) or not victim:IsPlayer() or not IsValid(attacker) or not attacker:IsPlayer() then
	--		return
	--	end
	--	
	--	if AtLeastOneDefOrDetLives() then
	--		return
	--	end
	--	
	--	--If all of the defectives/detectives are dead and the special detectives had their role jammed, we can give back their special roles if reveal_true_role is enabled
	--	for _, ply in pairs(player.GetAll()) do
	--		if ply:IsTerror() and ply:GetBaseRole() == ROLE_DETECTIVE and ply.former_det_role then
	--			ply:SetRole(ply.former_det_role)
	--			ply.former_det_role = nil
	--			--Call this function whenever a role change occurs during an active round.
	--			SendFullStateUpdate()
	--		end
	--	end
	--end)
	
	--Copied directly from TTT2/gamemodes/terrortown/gamemode/server/sv_corpse.lua
	local function GiveFoundCredits(ply, rag, isLongRange)
		local corpseNick = CORPSE.GetPlayerNick(rag)
		local credits = CORPSE.GetCredits(rag, 0)

		if not ply:IsActiveShopper() or ply:GetSubRoleData().preventFindCredits
			or credits == 0 or isLongRange
		then return end

		LANG.Msg(ply, "body_credits", {num = credits})

		ply:AddCredits(credits)

		CORPSE.SetCredits(rag, 0)

		ServerLog(ply:Nick() .. " took " .. credits .. " credits from the body of " .. corpseNick .. "\n")

		SCORE:HandleCreditFound(ply, corpseNick, credits)
	end
	
	--Taken mostly from the Spy role.
	hook.Add("TTTCanSearchCorpse", "DefectiveCanSearchCorpse", function(ply, corpse, isCovert, isLongRange)
		if not corpse then
			return
		end
		
		if not CanADeadDefBeRevealed() then
			--Show all defectives (and potentially all special detective roles) as detectives when searched.
			if corpse.was_role == ROLE_DEFECTIVE then
				corpse.was_role = ROLE_DETECTIVE
				corpse.was_team = TEAM_INNOCENT
				corpse.role_color = DETECTIVE.color
			end
		end
		
		if not AllowDetsToInspect() then
			SendDefectiveInspectionNotice(ply)
			
			--Give any found credits on the body before leaving.
			GiveFoundCredits(ply, corpse, isLongRange)
			
			return false
		end
	end)
	
	hook.Add("TTTCanIdentifyCorpse", "DefectiveCanIdentifyCorpse", function(ply, rag)
		if not AllowDetsToInspect() then
			SendDefectiveInspectionNotice(ply)
			return false
		end
		
		if not AllowDetsToConfirm() and not CORPSE.GetFound(rag, false) then
			SendDefectiveConfirmationNotice(ply)
			return false
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTT2ConfirmPlayer", "DefectiveConfirmPlayer", function(confirmed, finder, corpse)
		if IsValid(confirmed) and not CanADeadDefBeRevealed() then
			--Confirm player as a detective
			confirmed:ConfirmPlayer(true)
			SendRoleListMessage(ROLE_DETECTIVE, TEAM_INNOCENT, {confirmed:EntIndex()})
			--Update the scoreboard to show the def as a det.
			SCORE:HandleBodyFound(finder, confirmed)
			
			--Prevent traditional player confirmation from occurring (which would reveal the def).
			return false
		end
	end)
	
	--Taken mostly from the Spy role.
	hook.Add("TTTBodyFound", "DefectiveBodyFound", function(_, confirmed, corpse)
		--Only continue if we are set up to reveal the det's and def's roles.
		if not CanADeadDefBeRevealed() then
			return
		end
		
		--Only continue if the dead confirmed player is either a detective or a defective.
		if not IsValid(confirmed) or (confirmed:GetBaseRole() ~= ROLE_DETECTIVE and confirmed:GetSubRole() ~= ROLE_DEFECTIVE) then
			return
		end
		
		for _, ply in pairs(player.GetAll()) do
			local ply_corpse = ply.server_ragdoll
			
			if not ply_corpse or not ply:GetNWBool("body_found", false) then 
				continue
			end
			
			--Reveal the defective's true role
			if ply:GetSubRole() == ROLE_DEFECTIVE then
				local subrole = ply:GetSubRole()
				local team = ply:GetTeam()
				local srd = ply:GetSubRoleData()
				
				ply_corpse.was_role = subrole
				ply_corpse.was_team = team
				ply_corpse.role_color = srd.color
				
				--Inform everyone about the def's true role
				SendPlayerToEveryone(ply)
			end
		end
	end)
end