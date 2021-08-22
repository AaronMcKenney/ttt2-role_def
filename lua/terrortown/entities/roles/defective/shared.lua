if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_def.vmt")
	util.AddNetworkString("TTT2DefectiveInformEveryone")
	util.AddNetworkString("TTT2AtLeastOneDefectiveLives_TraitorOnly")
end

function ROLE:PreInitialize()
	--The Detective's color
	--self.color = Color(31, 77, 191, 255)
	--The Defective's color
	self.color = Color(58, 27, 169, 255)
	
	self.abbr = "def"
	self.scoreKillsMultiplier = 2
	self.scoreTeamKillsMultiplier = -1
	self.fallbackTable = {}
	self.unknownTeam = false --Enables traitor chat (among other things).
	
	--The defective may pick up any credits they find off of dead bodies (especially their fellow traitors)
	--However, they already gain credits in the same way as the detective, so it would be double-dipping to give them credits in the same way as the traitor.
	--This does in fact provide an incentive to the defective to kill their fellow traitors.
	self.preventFindCredits = false
	self.preventKillCredits = not GetConVar("ttt2_defective_gain_traitor_credits"):GetBool()
	self.preventTraitorAloneCredits = not GetConVar("ttt2_defective_gain_traitor_credits"):GetBool()
	
	self.defaultTeam = TEAM_TRAITOR
	self.defaultEquipment = SPECIAL_EQUIPMENT
	
	-- conVarData
	self.conVarData = {
		pct = 0.13,
		maximum = 1,
		minPlayers = 10,
		random = 30,
		minKarma = 600,
		traitorButton = 1, --can use traitor buttons
		
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
	--Used to identify if we're currently setting up role logic in the beginning of the round
	local def_doing_setup_logic = false
	--ttt2_defective_corpse_reveal_mode enum
	local REVEAL_MODE = {NEVER = 0, ALL_DEAD = 1, ALL_DEFS_DEAD = 2, ALWAYS = 3}
	--ttt2_defective_det_handling_mode enum
	local SPECIAL_DET_MODE = {NEVER = 0, JAM = 1, JAM_TEMP = 2}
	--Used in JamDetective to determine what role the player is being forced to
	local JAM_DET_MODE = {BASE_DET = 0, INNO = 1}
	
	--Shamelessly copy/pasted from TTT2/gamemodes/terrortown/gamemode/server/sv_weaponry.lua
	-- Quick hack to limit hats to models that fit them well
	local Hattables = {
		"phoenix.mdl",
		"arctic.mdl",
		"Group01",
		"monk.mdl"
	}
	
	local function IsInSpecDM(ply)
		if SpecDM and (ply.IsGhost and ply:IsGhost()) then
			return true
		end
		
		return false
	end
	
	local function RevealOnlyRequiresDeadDefs()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		return (m == REVEAL_MODE.ALWAYS or m == REVEAL_MODE.ALL_DEFS_DEAD)
	end
	
	local function IsDefOrDet(ply)
		return (ply:GetSubRole() == ROLE_DEFECTIVE or ply:GetBaseRole() == ROLE_DETECTIVE)
	end
	
	local function AtLeastOneDefExists()
		for _, ply in pairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_DEFECTIVE then
				return true
			end
		end
		
		return false
	end
	
	local function AtLeastOneDetExists()
		for _, ply in pairs(player.GetAll()) do
			if ply:GetBaseRole() == ROLE_DETECTIVE then
				return true
			end
		end
		
		return false
	end
	
	local function AtLeastOneDefLives()
		for _, ply in pairs(player.GetAll()) do
			if ply:IsTerror() and ply:Alive() and ply:GetSubRole() == ROLE_DEFECTIVE and not IsInSpecDM(ply) then
				return true
			end
		end
		
		return false
	end
	
	local function AtLeastOneDefOrDetLives()
		for _, ply in pairs(player.GetAll()) do
			if ply:IsTerror() and ply:Alive() and IsDefOrDet(ply) and not IsInSpecDM(ply) then
				return true
			end
		end
		
		return false
	end
	
	local function CanALivingDetBeRevealed()
		if RevealOnlyRequiresDeadDefs() then
			return not AtLeastOneDefLives()
		else
			return not AtLeastOneDefExists()
		end
	end
	
	--This is not local as it may be used by other mods which desire to "play along" with the defective's shenanigans.
	function CanADeadDefBeRevealed()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		if m == REVEAL_MODE.NEVER or (m == REVEAL_MODE.ALL_DEAD and AtLeastOneDefOrDetLives()) or (m == REVEAL_MODE.ALL_DEFS_DEAD and AtLeastOneDefLives()) then
			return false
		else
			return true
		end
	end
	
	local function AllowDetsToInspect()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		
		if GetConVar("ttt2_inspect_detective_only"):GetBool() and not CanALivingDetBeRevealed() then
			--Prevent dets from inspecting if doing so could be used to reveal the defective.
			return false
		end
		
		return true
	end
	
	local function AllowDetsToConfirm()
		local m = GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt()
		
		if GetConVar("ttt2_confirm_detective_only"):GetBool() and not CanALivingDetBeRevealed() then
			--Prevent dets from confirming if doing so could be used to reveal the defective.
			return false
		end
		
		return true
	end
	
	local function SendDefectiveInspectionNotice(ply)
		if RevealOnlyRequiresDeadDefs() then
			LANG.Msg(ply, "prevent_inspection_live_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		else
			LANG.Msg(ply, "prevent_inspection_exist_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		end
	end
	
	local function SendDefectiveConfirmationNotice(ply)
		if RevealOnlyRequiresDeadDefs() then
			LANG.Msg(ply, "prevent_confirmation_live_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		else
			LANG.Msg(ply, "prevent_confirmation_exist_" .. DEFECTIVE.name, nil, MSG_MSTACK_WARN)
		end
	end
	
	local function JamDetective(ply, base_role, sub_role, jam_det_mode)
		if ply:IsTerror() and ply:Alive() and base_role == ROLE_DETECTIVE and (sub_role ~= ROLE_DETECTIVE or jam_det_mode == JAM_DET_MODE.INNO) then
			if jam_det_mode == JAM_DET_MODE.BASE_DET then
				--print("DEF_DEBUG JamDetective: FORCING PLAYER " .. ply:GetName() .. " TO BE A DETECTIVE!")
				events.Trigger(EVENT_DEF_JAM_DET, ply)
				
				--Keep track of special det's role, in case the server is configured or reconfigured to potentially give back the role (JAM_TEMP)
				ply.det_role_masked_by_def = ply:GetSubRole()
				ply:SetRole(ROLE_DETECTIVE)
				
				if def_doing_setup_logic == true then
					timer.Simple(0.1, function()
						--Force the detective to have the correct number of credits, since ULX doesn't seem to care about that.
						ply:SetCredits(GetConVar("ttt_det_credits_starting"):GetInt())
					end)
				end
			else --JAM_DET_MODE.INNO
				--print("DEF_DEBUG JamDetective: FORCING PLAYER " .. ply:GetName() .. " TO BE AN INNOCENT!")
				events.Trigger(EVENT_DEF_DEMOTE_DET, ply)
				ply:SetRole(ROLE_INNOCENT)
				
				if def_doing_setup_logic == true then
					timer.Simple(0.1, function()
						ply:SetCredits(0)
					end)
				end
			end
			--Call this function whenever a role change occurs during an active round.
			SendFullStateUpdate()
		end
	end
	
	local function SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
		--This is more or less a hack to sync up TTT2CanUseVoiceChat Server and Client hooks
		--Explicitly to handle the case where traitor team voice chat is disabled due to a living defective that traitors aren't supposed to talk to.
		local at_least_one_def_lives = AtLeastOneDefLives()
		for _, ply in pairs(player.GetAll()) do
			if ply:GetBaseRole() == ROLE_TRAITOR then
				net.Start("TTT2AtLeastOneDefectiveLives_TraitorOnly")
				net.WriteBool(at_least_one_def_lives)
				net.Send(ply)
			end
		end
	end
	
	local function GetNumDetectiveDemotions()
		local num_demotions = 0
		local demote_pct = GetConVar("ttt2_defective_demote_detective_pct"):GetFloat()
		
		local r = math.random()
		--print("DEF_DEBUG GetNumDetectiveDemotions: Roll of " .. r .. " vs. demote_pct of " .. demote_pct)
		if r <= demote_pct then
			for _, ply in pairs(player.GetAll()) do
				if ply:GetSubRole() == ROLE_DEFECTIVE then
					num_demotions = num_demotions + 1
				end
			end
		end
		
		return num_demotions
	end
	
	local function DisableAllDefectives()
		local def_was_disabled = false
		for _, ply in pairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_DEFECTIVE then
				--print("DEF_DEBUG DisableAllDefectives: FORCING PLAYER " .. ply:GetName() .. " TO BE A TRAITOR!")
				events.Trigger(EVENT_DEF_DISABLED, ply)
				ply:SetRole(ROLE_TRAITOR)
				
				timer.Simple(0.1, function()
					--Force the traitor to have the correct number of credits, since ULX doesn't seem to care about that.
					ply:SetCredits(GetConVar("ttt_credits_starting"):GetInt())
				end)
				
				--Also remove the DNA Scanner that they were given at the start of the round. Traitors shouldn't have this.
				ply:StripWeapon('weapon_ttt_wtester')
				
				def_was_disabled = true
			end
		end
		
		if def_was_disabled then
			--Call this whenever a role change has occurred.
			--Especially necessary here, as otherwise there's a full second in the beginning of the round where the now-traitors
			--look like detectives, which could have been exploited by the innocent team.
			SendFullStateUpdate()
		end
	end
	
	local function ResetDefectivePlayerDataForServer()
		def_doing_setup_logic = false
	end
	hook.Add("TTTPrepareRound", "DefectivePrepareRoundForServer", ResetDefectivePlayerDataForServer())
	hook.Add("TTTEndRound", "DefectivePrepareEndForServer", ResetDefectivePlayerDataForServer())
	
	hook.Add("TTTBeginRound", "DefectiveBeginRoundForServer", function()
		def_doing_setup_logic = true
		
		if GetConVar("ttt2_defective_disable_spawn_if_no_detective"):GetBool() and not AtLeastOneDetExists() then
			--This round has no detectives! Quickly force all players of this role to be generic traitors.
			DisableAllDefectives()
			
			--Now that there are no defectives, we can leave this hook without consequence.
			def_doing_setup_logic = false
			return
		end
		
		local num_demotions = GetNumDetectiveDemotions()
		local m = GetConVar("ttt2_defective_special_det_handling_mode"):GetInt()
		if (m == SPECIAL_DET_MODE.JAM and AtLeastOneDefExists()) or (m == SPECIAL_DET_MODE.JAM_TEMP and AtLeastOneDefLives()) or num_demotions > 0 then
			--Force all special detectives to be normal detectives, in case they have some special equipment or ability that could instantly be used to make them trustworthy.
			--Also force detectives to be innocent, if demotions are required
			--Player table is shuffled to randomize who gets demoted.
			for _, ply in pairs(table.Shuffle(player.GetAll())) do
				if num_demotions > 0 and ply:GetBaseRole() == ROLE_DETECTIVE then
					JamDetective(ply, ply:GetBaseRole(), ply:GetSubRole(), JAM_DET_MODE.INNO)
					num_demotions = num_demotions - 1
				else
					JamDetective(ply, ply:GetBaseRole(), ply:GetSubRole(), JAM_DET_MODE.BASE_DET)
				end
			end
		end
		
		--Only send popup here, as opposed to also sending it on TTT2UpdateSubrole, as doing so could reveal the newly created defective.
		if GetConVar("ttt2_defective_inform_everyone"):GetBool() and AtLeastOneDefExists() and AtLeastOneDetExists() then
			net.Start("TTT2DefectiveInformEveryone")
			net.Broadcast()
		end
		
		SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
		def_doing_setup_logic = false
	end)
	
	hook.Add("TTT2UpdateSubrole", "DefectiveUpdateSubrole", function(self, oldSubrole, subrole)
		--Don't bother messing with role logic in the beginning of the round here, as that's already happening in TTTBeginRound hook.
		if GetRoundState() ~= ROUND_ACTIVE or def_doing_setup_logic then
			return
		end
		
		local base_role = roles.GetByIndex(subrole):GetBaseRole()
		local m = GetConVar("ttt2_defective_special_det_handling_mode"):GetInt()
		
		if self.det_role_masked_by_def and self.det_role_masked_by_def ~= subrole then
			--Remove the special det's "true role" if they convert to anything other than their true role.
			--Ex. Infected, Deputy, Sidekick, etc.
			self.det_role_masked_by_def = nil
		end
		
		--We do not immediately jam all special dets if a def shows up in the middle of the round, as that would immediately give away that they are a def.
		--Only jam special dets that show up when a def is currently in play.
		if (m == SPECIAL_DET_MODE.JAM and AtLeastOneDefExists()) or (m == SPECIAL_DET_MODE.JAM_TEMP and AtLeastOneDefLives()) then
			--This timer is a hack to give time for the player to finish setup for their current role before we change it to their new role. It won't work if the current role takes a lot of time to setup.
			--Specifically prevents situations where a sniffer is given their lens, but then changes to a detective before the lens can be properly removed.
			timer.Simple(0.1, function()
				JamDetective(self, base_role, subrole, JAM_DET_MODE.BASE_DET)
			end)
		end
		
		SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
	end)
	
	--Shamelessly copy/pasted from TTT2/gamemodes/terrortown/gamemode/server/sv_weaponry.lua
	local function CanWearHat(ply)
		local path = string.Explode("/", ply:GetModel())
		
		if #path == 1 then
			path = string.Explode("\\", path)
		end
		
		return table.HasValue(Hattables, path[3])
	end
	
	hook.Add("PlayerLoadout", "DefectivePlayerLoadout", function(ply, isRespawn)
		--Mostly shamelessly copy/pasted from GiveLoadoutSpecial in:
		--TTT2/gamemodes/terrortown/gamemode/server/sv_weaponry.lua
		--Have to use "def_hat" and can't reuse "ply.hat" entities, as TTT2 server can take away ply.hat entities as soon as they are given.
		--The code here appears to be mildly broken for the detective, as they only truly lose their hat if they change roles. Otherwise the hat will still exist (even if it isn't on their head).
		--Not entirely sure why this is the case, but it can be replicated through the added "on_def" field.
		
		if not IsValid(ply) or ply:IsSpec() then
			return
		end
		
		if not ply:IsActive() or ply:GetSubRole() ~= ROLE_DEFECTIVE or not GetConVar("ttt_detective_hats"):GetBool() or not CanWearHat(ply) then
			if IsValid(ply.def_hat) and ply.def_hat.on_def then
				SafeRemoveEntity(ply.def_hat)
				ply.def_hat = nil
			end
			
			return
		end
		
		--"and not isRespawn" is needed because for some reason detectives get new hats when they respawn, even though the hats they have from their past life still exists in the world. Very strange.
		if IsValid(ply.def_hat) and ply.def_hat.on_def then
			return
		end
		
		local def_hat = ents.Create("ttt_hat_deerstalker")
		if not IsValid(def_hat) then
			return
		end

		def_hat:SetPos(ply:GetPos() + Vector(0, 0, 70))
		def_hat:SetAngles(ply:GetAngles())
		def_hat:SetParent(ply)
		def_hat.on_def = true

		ply.def_hat = def_hat

		def_hat:Spawn()
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
		
		--Need a timer (hack) here because the starting credits can be overwritten by ULX and other things.
		--See function "ulx.force"
		timer.Simple(0.1, function()
			--Give the defective the same number of credits as the role their disguised as.
			ply:SetCredits(GetConVar("ttt_det_credits_starting"):GetInt())
		end)
	end
	
	hook.Add("TTT2SpecialRoleSyncing", "DefectiveSpecialRoleSyncing", function (ply, tbl)
		if not ply or GetRoundState() == ROUND_POST then 
			return
		end
		
		--Cache boolean to save some processing time.
		local can_reveal_dead_def = CanADeadDefBeRevealed()
		
		for ply_i in pairs(tbl) do
			if not ply_i:IsTerror() or ply_i == ply then
				continue
			end
			
			--Handle how everyone sees a defective
			if ply:GetSubRole() ~= ROLE_DEFECTIVE and ply_i:GetSubRole() == ROLE_DEFECTIVE then
				if not ply_i:Alive() and can_reveal_dead_def then
					--Do not mess with dead def's apparent role.
					continue
				end
				
				if ply:GetTeam() ~= TEAM_TRAITOR or not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool() then
					--Make the defective look like a detective to all non-traitors.
					tbl[ply_i] = {ROLE_DETECTIVE, TEAM_INNOCENT}
				else
					--Reveal the defective's role to their team mates
					tbl[ply_i] = {ROLE_DEFECTIVE, TEAM_TRAITOR}
				end
			end
			
			--Handle how defectives see traitors
			if ply:GetSubRole() == ROLE_DEFECTIVE and ply_i:GetSubRole() ~= ROLE_DEFECTIVE and ply_i:GetTeam() == TEAM_TRAITOR then
				if GetConVar("ttt2_defective_can_see_traitors"):GetBool() then
					--Allow for the defective to see their fellow traitors.
					tbl[ply_i] = {ply_i:GetSubRole(), ply_i:GetTeam()}
				else
					--Force all traitors to look like none role to the defective
					tbl[ply_i] = {ROLE_NONE, TEAM_NONE}
				end
			end
			
			--Handle how defectives see other defectives
			if ply:GetSubRole() == ROLE_DEFECTIVE and ply_i:GetSubRole() == ROLE_DEFECTIVE then
				if GetConVar("ttt2_defective_can_see_defectives"):GetBool() then
					tbl[ply_i] = {ROLE_DEFECTIVE, TEAM_TRAITOR}
				else
					tbl[ply_i] = {ROLE_DETECTIVE, TEAM_INNOCENT}
				end
			end
		end
	end)
	
	hook.Add("TTT2ModifyRadarRole", "DefectiveModifyRadarRole", function(ply, target)
		--Handle how everyone sees a defective
		if ply:GetSubRole() ~= ROLE_DEFECTIVE and target:GetSubRole() == ROLE_DEFECTIVE then
			if ply:GetTeam() ~= TEAM_TRAITOR or not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool() then
				--Make the defective look like a detective to all non-traitors.
				return ROLE_DETECTIVE, TEAM_INNOCENT
			else
				--Reveal the defective's role to their team mates
				return ROLE_DEFECTIVE, TEAM_TRAITOR
			end
		end
		
		--Handle how defectives see traitors
		if ply:GetSubRole() == ROLE_DEFECTIVE and target:GetSubRole() ~= ROLE_DEFECTIVE and target:GetTeam() == TEAM_TRAITOR then
			if GetConVar("ttt2_defective_can_see_traitors"):GetBool() then
				--Allow for the defective to see their fellow traitors.
				return target:GetSubRole(), target:GetTeam()
			else
				--Force all traitors to look like none role to the defective
				return ROLE_NONE, TEAM_NONE
			end
		end
		
		--Handle how defectives see other defectives
		if ply:GetSubRole() == ROLE_DEFECTIVE and target:GetSubRole() == ROLE_DEFECTIVE then
			if GetConVar("ttt2_defective_can_see_defectives"):GetBool() then
				return ROLE_DEFECTIVE, TEAM_TRAITOR
			else
				return ROLE_DETECTIVE, TEAM_INNOCENT
			end
		end
	end)
	
	hook.Add("TTT2AvoidTeamChat", "DefectiveAvoidTeamChat", function(sender, tm, msg)
		--Only jam traitor team chat
		if not tm == TEAM_TRAITOR or not IsValid(sender) or sender:GetTeam() ~= TEAM_TRAITOR then
			return
		end
		
		if (not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool() or not GetConVar("ttt2_defective_can_see_defectives"):GetBool()) and sender:GetSubRole() == ROLE_DEFECTIVE then
			--Prevent defective from talking to their team mates through traitor chat, which would reveal their role to the traitors.
			LANG.Msg(sender, "prevent_def_to_tra_comm_" .. DEFECTIVE.name, nil, MSG_CHAT_WARN)
			return false
		end
		
		if not GetConVar("ttt2_defective_can_see_traitors"):GetBool() and sender:GetSubRole() ~= ROLE_DEFECTIVE and AtLeastOneDefLives() then
			--Prevent traitors from talking to their team mates through traitor chat, which would reveal their roles to the def.
			LANG.Msg(sender, "prevent_tra_to_def_comm_" .. DEFECTIVE.name, nil, MSG_CHAT_WARN)
			return false
		end
	end)
	
	hook.Add("TTT2CanUseVoiceChat", "DefectiveServerCanUseVoiceChat", function(speaker, isTeamVoice)
		--Only jam traitor team voice
		if not isTeamVoice or not IsValid(speaker) or speaker:GetTeam() ~= TEAM_TRAITOR then
			return
		end
		
		if (not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool() or not GetConVar("ttt2_defective_can_see_defectives"):GetBool()) and speaker:GetSubRole() == ROLE_DEFECTIVE then
			--Prevent defective from talking to their team mates through traitor chat, which would reveal their role to the traitors.
			LANG.Msg(speaker, "prevent_def_to_tra_comm_" .. DEFECTIVE.name, nil, MSG_CHAT_WARN)
			return false
		end
		
		if not GetConVar("ttt2_defective_can_see_traitors"):GetBool() and speaker:GetSubRole() ~= ROLE_DEFECTIVE and AtLeastOneDefLives() then
			--Prevent traitors from talking to their team mates through traitor chat, which would reveal their roles to the def.
			LANG.Msg(speaker, "prevent_tra_to_def_comm_" .. DEFECTIVE.name, nil, MSG_CHAT_WARN)
			return false
		end
	end)
	
	hook.Add("PlayerTraceAttack", "DefectiveTraceAttack", function(ply, dmginfo, dir, trace)
		if IsValid(ply.def_hat) and trace.HitGroup == HITGROUP_HEAD then
			ply.def_hat:Drop(dir)
			ply.def_hat.on_def = false
		end
	end)
	
	hook.Add("EntityTakeDamage", "DefectiveTakeDamage", function(target, dmg_info)
		local attacker = dmg_info:GetAttacker()
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(target) or not target:IsPlayer() or not IsValid(attacker) or not attacker:IsPlayer() then
			return
		end
		
		if not GetConVar("ttt2_defective_detective_immunity"):GetBool() or CanALivingDetBeRevealed() or not IsDefOrDet(target) or not IsDefOrDet(attacker) then
			--Return if immunity is disabled, defs are not affecting gameplay, or if either the target or attacker aren't dets/defs.
			return
		end
		
		--Count all of the def's living team mates and all of the det's living team mates.
		--If they both have no remaining non-def and non-def team mates on both sides,
		--then immunity should be revoked (otherwise the game may become a stalemate).
		local num_living_defs = 0
		local num_living_dets = 0
		local num_living_traitors = 0
		local num_living_innos = 0
		for _, ply in pairs(player.GetAll()) do
			if ply:IsTerror() and ply:Alive() and not IsInSpecDM(ply) then
				num_living_defs = num_living_defs + (ply:GetSubRole() == ROLE_DEFECTIVE and 1 or 0)
				num_living_dets = num_living_dets + (ply:GetBaseRole() == ROLE_DETECTIVE and 1 or 0)
				num_living_traitors = num_living_traitors + (ply:GetTeam() == TEAM_TRAITOR and 1 or 0)
				num_living_innos = num_living_innos + (ply:GetTeam() == TEAM_INNOCENT and 1 or 0)
			end
		end
		
		if num_living_defs < num_living_traitors or num_living_dets < num_living_innos then
			dmg_info:SetDamage(0)
		end
	end)
	
	hook.Add("DoPlayerDeath", "DefectivePlayerDeath", function(ply, attacker, dmginfo)
		if IsValid(ply.def_hat) then
			ply.def_hat:Drop()
			ply.def_hat.on_def = false
		end
	end)
	
	hook.Add("TTT2PostPlayerDeath", "DefectivePostPlayerDeath", function (victim, inflictor, attacker)
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(victim) or not victim:IsPlayer() then
			return
		end
		
		local m = GetConVar("ttt2_defective_special_det_handling_mode"):GetInt()
		if m == SPECIAL_DET_MODE.JAM_TEMP and CanADeadDefBeRevealed() and not AtLeastOneDefLives() then
			--If all defs are dead, give any remaining special dets their roles back.
			for _, ply in pairs(player.GetAll()) do
				if ply.det_role_masked_by_def then
					events.Trigger(EVENT_DEF_UNDO_JAM, ply, ply.det_role_masked_by_def)
					ply:SetRole(ply.det_role_masked_by_def)
					--Call this function whenever a role change occurs during an active round.
					SendFullStateUpdate()
					
					--Remove this variable now that the special det has their role back.
					ply.det_role_masked_by_def = nil
				end
			end
		end
		
		SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
	end)
	
	hook.Add("TTT2CheckCreditAward", "DefectiveCreditAward", function(victim, attacker)
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(victim) or not IsValid(attacker) or not attacker:IsPlayer() or not attacker:IsActive()then
			return
		end
		
		--This is pretty much copy/pasted from how Detective gets credits in CheckCreditAward()
		--Except here we award credits to the defective if either a det or a def killed a traitor.
		--We also award credits to the det if the def killed a traitor.
		if (attacker:GetBaseRole() == ROLE_DETECTIVE and not victim:IsInTeam(attacker)) or (attacker:GetSubRole() == ROLE_DEFECTIVE and victim:IsInTeam(attacker)) then
			local amt = math.ceil(ConVarExists("ttt_det_credits_traitordead") and GetConVar("ttt_det_credits_traitordead"):GetInt() or 1)
			
			if amt > 0 then
				local plys = player.GetAll()
				
				for i = 1, #plys do
					local ply = plys[i]
					
					--Give credits to the def regardless.
					--But only give credits to the det if the attacker is a def (to avoid double dipping)
					if ply:IsActive() and ply:IsShopper() and (ply:GetSubRole() == ROLE_DEFECTIVE or (attacker:GetSubRole() == ROLE_DEFECTIVE and ply:GetBaseRole() == ROLE_DETECTIVE)) then
						ply:AddCredits(amt)
					end
				end
				
				--Always inform defectives of the credits they have received.
				LANG.Msg(GetRoleChatFilter(ROLE_DEFECTIVE, true), "credit_all", {num = amt})
				if attacker:GetSubRole() == ROLE_DEFECTIVE then
					--Only inform detectives of credits they receive from defectives (they will already be sent a popup if the attacker was a fellow detective).
					LANG.Msg(GetRoleChatFilter(ROLE_DETECTIVE, true), "credit_all", {num = amt})
				end
			end
		end
	end)
	
	hook.Add("TTT2CanOrderEquipment", "DefectiveCanOrderEquipment", function(ply, cls, is_item, credits)
		if not GetConVar("ttt2_defective_shop_order_prevention"):GetBool() or GetRoundState() ~= ROUND_ACTIVE or ply:GetBaseRole() ~= ROLE_DETECTIVE or CanALivingDetBeRevealed() then
			return
		end
		
		--Taken from OrderEquipment function. Semi-internal variable containing all info on a weapon/item.
		local equip_table = not is_item and weapons.GetStored(cls) or items.GetStored(cls)
		
		--The code suggests that it is possible for players of the same role to have different shops.
		local dead_defs_prevent_orders = (GetConVar("ttt2_defective_corpse_reveal_mode"):GetInt() ~= REVEAL_MODE.ALWAYS)
		for _, ply_i in pairs(player.GetAll()) do
			if ply_i:IsTerror() and (dead_defs_prevent_orders or (ply_i:Alive() and not IsInSpecDM(ply_i))) and ply_i:GetSubRole() == ROLE_DEFECTIVE and not EquipmentIsBuyable(equip_table, ply_i) then
				--Prevent dets from buying items/weapons that defs can't buy.
				--This allows the admin to prevent dets from buying something like a portable tester or similar item which can instantly prove their innocence and reveal the def.
				LANG.Msg(ply, "prevent_order_" .. DEFECTIVE.name, nil, MSG_CHAT_WARN)
				return false
			end
		end
	end)
	
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

		events.Trigger(EVENT_CREDITFOUND, ply, rag, credits)
	end
	
	hook.Add("TTTCanSearchCorpse", "DefectiveCanSearchCorpse", function(ply, corpse, isCovert, isLongRange)
		if not corpse then
			return
		end
		
		--Show all defectives as detectives when searched.
		if corpse.was_role == ROLE_DEFECTIVE and not CanADeadDefBeRevealed() then
			corpse.was_role = ROLE_DETECTIVE
			corpse.was_team = TEAM_INNOCENT
			corpse.role_color = DETECTIVE.color
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
	
	hook.Add("TTT2ConfirmPlayer", "DefectiveConfirmPlayer", function(confirmed, finder, corpse)
		if IsValid(confirmed) and corpse and confirmed:GetSubRole() == ROLE_DEFECTIVE and not CanADeadDefBeRevealed() then
			--Confirm player as a detective
			confirmed:ConfirmPlayer(true)
			SendRoleListMessage(ROLE_DETECTIVE, TEAM_INNOCENT, {confirmed:EntIndex()})
			--Update the scoreboard to show the def as a det.
			events.Trigger(EVENT_BODYFOUND, finder, corpse)
			
			--Prevent traditional player confirmation from occurring (which would reveal the def).
			return false
		end
	end)
	
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
	
	hook.Add("TTT2ModifyCorpseCallRadarRecipients", "DefectiveModifyCorpseCallRadarRecipients", function(plyTable, rag, ply)
		--Add defectives to list of players that are called when someone hits the "Call Detective" button
		for _, ply_i in pairs(player.GetAll()) do
			if ply_i:IsTerror() and ply_i:Alive() and ply_i:GetSubRole() == ROLE_DEFECTIVE and not ply_i:GetSubRoleData().disabledTeamChatRec then
				plyTable[#plyTable + 1] = ply_i
			end
		end
	end)
end

if CLIENT then
	local at_least_one_def_lives_traitor_only = false
	local function ResetDefectivePlayerDataForClient()
		--Initialize data that this client needs to know, but must be kept secret from other clients.
		at_least_one_def_lives_traitor_only = false
	end
	hook.Add("TTTEndRound", "ResetDefectiveForClientOnEndRound", ResetDefectivePlayerDataForClient)
	hook.Add("TTTPrepareRound", "ResetDefectiveForClientOnPrepareRound", ResetDefectivePlayerDataForClient)
	hook.Add("TTTBeginRound", "ResetDefectiveForClientOnBeginRound", ResetDefectivePlayerDataForClient)
	
	net.Receive("TTT2DefectiveInformEveryone", function()
		EPOP:AddMessage({text = LANG.GetTranslation("inform_everyone_" .. DEFECTIVE.name), color = DEFECTIVE.color}, "", 6)
	end)
	
	net.Receive("TTT2AtLeastOneDefectiveLives_TraitorOnly", function()
		at_least_one_def_lives_traitor_only = net.ReadBool()
	end)
	
	hook.Add("TTT2CanUseVoiceChat", "DefectiveClientCanUseVoiceChat", function(speaker, isTeamVoice)
		--This is mostly copied from the server-side hook. Client also needs a hook here for VGUI stuff.
		
		--Only jam traitor team voice
		if not isTeamVoice or not IsValid(speaker) or speaker:GetTeam() ~= TEAM_TRAITOR then
			return
		end
		
		if (not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool() or not GetConVar("ttt2_defective_can_see_defectives"):GetBool()) and speaker:GetSubRole() == ROLE_DEFECTIVE then
			--Prevent defective from talking to their team mates through traitor chat, which would reveal their role to the traitors.
			return false
		end
		
		if not GetConVar("ttt2_defective_can_see_traitors"):GetBool() and speaker:GetSubRole() ~= ROLE_DEFECTIVE and at_least_one_def_lives_traitor_only then
			--Prevent traitors from talking to their team mates through traitor chat, which would reveal their roles to the def.
			return false
		end
	end)
end