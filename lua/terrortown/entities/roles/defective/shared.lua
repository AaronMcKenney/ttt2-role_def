if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_def.vmt")
	util.AddNetworkString("TTT2DefectiveInformEveryone")
	util.AddNetworkString("TTT2DefectiveInformVisage")
	util.AddNetworkString("TTT2AtLeastOneDefectiveLives_TraitorOnly")
end

function ROLE:PreInitialize()
	--The Detective's color
	--self.color = Color(31, 77, 191, 255)
	--The Defective's color
	self.color = Color(58, 27, 169, 255)
	
	self.abbr = "def"
	
	self.defaultTeam = TEAM_TRAITOR
	--Defective uses the Detective shop by default.
	self.defaultEquipment = SPECIAL_EQUIPMENT
	
	--The defective may pick up any credits they find off of dead bodies (especially their fellow traitors)
	self.preventFindCredits = false
	
	--Most of the scoring is taken from the Traitor
	self.score.surviveBonusMultiplier = 0.5
	self.score.timelimitMultiplier = -0.5
	self.score.killsMultiplier = 2
	self.score.bodyFoundMuliplier = 0
	--teamKillsMultiplier is much less than the usual "-16", as the Defective could make a play here using their teammate as a sacrifice.
	--Also Defectives get credits when players from their own team dies, so a sort of "blood for gold" situation can arise here.
	self.score.teamKillsMultiplier = -1
	
	self.fallbackTable = {}
	self.unknownTeam = false --Enables traitor chat (among other things).
	
	--This role is visible to all. However, there are many hooks to disguise the Defective as a Detective.
	self.isPublicRole = true
	--This role has the abilities of a Detective. Also gives the Defective a hat on some player models
	self.isPolicingRole = true
	--This role can see which players are missing in action as well as the haste timer.
	self.isOmniscientRole = true
	
	-- conVarData
	self.conVarData = {
		pct = 0.13,
		maximum = 1,
		minPlayers = 10,
		random = 30,
		minKarma = 600,
		traitorButton = 1, --can use traitor buttons
		
		--Detective has 1 credit by default. Replicated here.
		credits = 1,
		--By default, Defective gets credits in the same manner as their fellow traitors.
		--Note: This is not the same as how the Detective gets credits, as that requires creatively misinterpreting creditsAwardDeadEnable to apply as if the Defective was on TEAM_INNOCENT.
		--This should be fine as creditsAwardDeadEnable counts for both the Def and Det for all 3rd party roles, and generally the Def will have more credits than the Det (thus they can more easily mimic them).
		--The only downside is if Traitors drop left and right before any Innocents, in which case the Det will have more credits. But that should be fine I think, as the Def could lie about what they spent.
		creditsAwardDeadEnable = 1,
		creditsAwardKillEnable = 1,
		
		togglable = true,
		shopFallback = SHOP_FALLBACK_DETECTIVE
	}
end

function ROLE:Initialize()
	roles.SetBaseRole(self, ROLE_TRAITOR)
end

if SERVER then
	--CONSTANTS/GLOBALS
	--Used to identify if we're currently setting up role logic in the beginning of the round
	local DEF_DOING_SETUP_LOGIC = false
	--This won't be true until all of the setup has been done, meaning that actions before setup won't occur.
	local DEF_SETUP_COMPLETE = false
	--ttt2_defective_corpse_reveal_mode enum
	local REVEAL_MODE = {NEVER = 0, ALL_DEAD = 1, ALL_DEFS_DEAD = 2, ALWAYS = 3}
	--ttt2_defective_det_handling_mode enum
	local SPECIAL_DET_MODE = {NEVER = 0, JAM = 1, JAM_TEMP = 2, VISAGE = 3}
	--Used in JamDetective to determine what role the player is being forced to
	local JAM_DET_MODE = {BASE_DET = 0, INNO = 1}
	--Used for determining what visage is possible for VISAGE mode (N, R, and W are used for indexing DET_VISAGE_LIST)
	local NUM_PLYS_AT_ROUND_BEGIN = 0
	local DET_VISAGE_LIST = nil
	local DET_VISAGE_LIST_TOTAL_WEIGHT = 0
	local N = 1
	local R = 2
	local W = 3
	local STEAMID64_TO_VISAGE_ROLE_MAP = nil
	--Used for updating how the Spy influences role visibility. Without this, we do not update correctly upon the Spy's death and respawn
	local SPY_IS_JAMMING = false
	local SPY_IS_JAMMING_CORPSES = false
	
	local function IsInSpecDM(ply)
		if SpecDM and (ply.IsGhost and ply:IsGhost()) then
			return true
		end
		
		return false
	end

	local function GetNumPlayers()
		local num_players = 0

		for _, ply in ipairs(player.GetAll()) do
			if not ply:IsSpec() then
				num_players = num_players + 1
			end
		end
		
		return num_players
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
	
	local function UpdateSpyJam()
		--Notice that throughout this file we always let the Spy's jamming logic take priority over the Defective.
		--The reason for this is that if the Defective isn't displayed as a Traitor when a Spy is present and the player count is low, we will end up in a situation where a generic traitor role will see the Defective as a Defective, and therefore be able to easily deduce who the Spy is due to the reduction in social deduction required.

		if not ROLE_SPY or not GetConVar("ttt2_spy_jam_special_roles"):GetBool() then
			return
		end

		local spy_exists = false
		local spy_alive = false
		local tra_alive = false
		local spy_confirm_as_traitor = GetConVar("ttt2_spy_confirm_as_traitor"):GetBool()
		local spy_reveal_true_role = GetConVar("ttt2_spy_reveal_true_role"):GetBool()
		
		--If the spy is in play, Traitors should not be told who the Defective is! The only player who should know the Defective's visage in this case is the Defective themselves.
		for _, ply in ipairs(player.GetAll()) do
			local ply_is_alive = (ply:IsTerror() and ply:Alive() and not IsInSpecDM(ply))
			spy_exists = (spy_exists or ply:GetSubRole() == ROLE_SPY)
			spy_alive = (spy_alive or (ply_is_alive and ply:GetSubRole() == ROLE_SPY))
			tra_alive = (tra_alive or (ply_is_alive and ply:GetTeam() == TEAM_TRAITOR))
		end
		
		--print("DEF_DEBUG SpyIsJamming: spy_confirm_as_traitor=" .. tostring(spy_confirm_as_traitor) .. ", spy_reveal_true_role=" .. tostring(spy_reveal_true_role) .. ", spy_exists=" .. tostring(spy_exists) .. ", spy_alive=" .. tostring(spy_alive) .. ", tra_alive=" .. tostring(tra_alive))
		if spy_alive or (spy_exists and spy_confirm_as_traitor and (not spy_reveal_true_role or tra_alive)) then
			SPY_IS_JAMMING = true
		else
			SPY_IS_JAMMING = false
		end
		
		SPY_IS_JAMMING_CORPSES = SPY_IS_JAMMING and spy_confirm_as_traitor
		
		--print("  SPY_IS_JAMMING=" .. tostring(SPY_IS_JAMMING) .. ", SPY_IS_JAMMING_CORPSES=" .. tostring(SPY_IS_JAMMING_CORPSES)) --DEF_DEBUG
		
		return false
	end
	
	local function JamDetective(ply, base_role, sub_role, jam_det_mode)
		if ply:IsTerror() and ply:Alive() and base_role == ROLE_DETECTIVE and (sub_role ~= ROLE_DETECTIVE or jam_det_mode == JAM_DET_MODE.INNO) then
			if jam_det_mode == JAM_DET_MODE.BASE_DET then
				--print("DEF_DEBUG JamDetective: FORCING PLAYER " .. ply:GetName() .. " TO BE A DETECTIVE!")
				events.Trigger(EVENT_DEF_JAM_DET, ply)
				
				--Keep track of special det's role, in case the server is configured or reconfigured to potentially give back the role (JAM_TEMP)
				ply.det_role_masked_by_def = ply:GetSubRole()
				ply:SetRole(ROLE_DETECTIVE)
				
				if DEF_DOING_SETUP_LOGIC then
					timer.Simple(0.1, function()
						--Force the detective to have the correct number of credits, since ULX doesn't seem to care about that.
						ply:SetCredits(GetConVar("ttt_det_credits_starting"):GetInt())
					end)
				end
			else --JAM_DET_MODE.INNO
				--print("DEF_DEBUG JamDetective: FORCING PLAYER " .. ply:GetName() .. " TO BE AN INNOCENT!")
				events.Trigger(EVENT_DEF_DEMOTE_DET, ply)
				ply:SetRole(ROLE_INNOCENT)
				
				if DEF_DOING_SETUP_LOGIC then
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
		if r <= demote_pct then
			for _, ply in pairs(player.GetAll()) do
				if ply:GetSubRole() == ROLE_DEFECTIVE then
					num_demotions = num_demotions + 1
				end
			end
		end

		--print("DEF_DEBUG GetNumDetectiveDemotions: Roll of " .. r .. " vs. demote_pct of " .. demote_pct .. ". There will be " .. num_demotions .. " demotion(s) this round")
		
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
	
	local function CalculateDetectiveVisages()
		--Viable roles are those that the player could have feasible gotten at the beginning of the round
		local det_visage_list = {}
		local total_weight = 0
		local role_data_list = roles.GetList()

		for i = 1, #role_data_list do
			local role_data = role_data_list[i]
			if role_data.notSelectable or role_data:GetBaseRole() ~= ROLE_DETECTIVE then
				--notSelectable is true for roles spawned under special circumstances, such as the Deputy
				continue
			end
			
			--role_data.builtin will be true for INNOCENT and TRAITOR, which are always enabled.
			local enabled = true
			local min_players = 0
			if not role_data.builtin then
				enabled = GetConVar("ttt_" .. role_data.name .. "_enabled"):GetBool()
				min_players = GetConVar("ttt_" .. role_data.name .. "_min_players"):GetInt()
			end
			if not enabled or min_players > NUM_PLYS_AT_ROUND_BEGIN then
				continue
			end

			local weight = GetConVar("ttt_" .. role_data.name .. "_random"):GetInt()
			total_weight = total_weight + weight
			det_visage_list[#det_visage_list + 1] = {role_data.name, role_data.index, weight}
		end
		
		DET_VISAGE_LIST = det_visage_list
		DET_VISAGE_LIST_TOTAL_WEIGHT = total_weight
		
		--DEF_DEBUG
		--debug_str = "DEF_DEBUG CalculateDetectiveVisages: Printing (role, index, weight) list with total weight " .. tostring(DET_VISAGE_LIST_TOTAL_WEIGHT) .. ": [ "
		--for i = 1, #DET_VISAGE_LIST do
		--	debug_str = debug_str .. "(" .. tostring(DET_VISAGE_LIST[i][N]) .. "," .. tostring(DET_VISAGE_LIST[i][R]) .. "," .. tostring(DET_VISAGE_LIST[i][W]) .. ") "
		--end
		--debug_str = debug_str .. "]"
		--print(debug_str)
	end
	
	local function InformPlayersOfVisages()
		--We have to handle both role and team updates, so it's easier to send info to all players, either telling them the given visage of all Defectives or telling them to reset visage data on their client
		local show_to_tra = GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool()
		local show_to_def = GetConVar("ttt2_defective_can_see_defectives"):GetBool()

		for _, ply_i in ipairs(player.GetAll()) do
			local visage_table = {}
			local num_visages = 0
			for _, def_ply in ipairs(player.GetAll()) do
				--If both ply_i and def_ply are the same player, always let that take priority, as the Defective should always know their visage for proper subterfuge to take place.
				local same_player = ply_i:SteamID64() == def_ply:SteamID64()
				if def_ply:GetSubRole() ~= ROLE_DEFECTIVE or (SPY_IS_JAMMING and not same_player) then
					continue
				end

				if same_player or (show_to_tra and ply_i:GetTeam() == TEAM_TRAITOR and ply_i:GetSubRole() ~= ROLE_DEFECTIVE) or (show_to_def and ply_i:GetSubRole() == ROLE_DEFECTIVE) then
					visage_table[def_ply:GetName()] = def_ply.ttt2_def_visage or ROLE_DETECTIVE
					num_visages = num_visages + 1
				end
			end

			net.Start("TTT2DefectiveInformVisage")
			net.WriteInt(num_visages, 16)
			for def_name, visage in pairs(visage_table) do
				--Can't use net.WriteInt on a SteamID64, as that only supports 32 bits. Also SteamID64() doesn't work on clients if the player is a bot, which makes debugging difficult.
				net.WriteString(def_name)
				net.WriteInt(visage, 16)
			end
			net.Send(ply_i)

			--DEF_DEBUG
			--local debug_str = "DEF_DEBUG InformPlayersOfVisages: visage_table(" .. ply_i:GetName() .. ")=[ "
			--for def_id, role_id in pairs(visage_table) do
			--	debug_str = debug_str .. "(" .. def_id .. "," .. roles.GetByIndex(role_id).name ..") "
			--end
			--debug_str = debug_str .. "] (num_visages=" .. tostring(num_visages) .. ")"
			--print(debug_str)
		end
	end
	
	local function DisguiseDefective(ply, m)
		if ply:GetSubRole() == ROLE_DEFECTIVE and ply.ttt2_def_visage == nil then
			local chosen_name = "???"

			if m ~= SPECIAL_DET_MODE.VISAGE or DET_VISAGE_LIST == nil or DET_VISAGE_LIST_TOTAL_WEIGHT <= 0 then
				--Always disguise the Defective as a regular old Detective if the mode isn't VISAGE
				chosen_name = roles.GetByIndex(ROLE_DETECTIVE).name
				ply.ttt2_def_visage = ROLE_DETECTIVE

				--print("DEF_DEBUG DisguiseDefectives: Defective " .. ply:GetName() .. " has been given the visage of a normal " .. chosen_name)
			else
				--Disguise the Defective as a particular Detective role (ex. Detective/Sniffer/Sherriff/Banker)
				--They won't get any of the abilities, but instead keep the abilities of the Detective.
				--This will understandably put them at a disadvantage, though it does allow the Defective to play with other special Detectives at least.

				local chosen_role = ROLE_DETECTIVE
				local chosen_weight = math.random(1, DET_VISAGE_LIST_TOTAL_WEIGHT)
				local current_weight = 0
				for i = 1, #DET_VISAGE_LIST do
					current_weight = current_weight + DET_VISAGE_LIST[i][W]
					if current_weight >= chosen_weight then
						chosen_name = DET_VISAGE_LIST[i][N]
						chosen_role = DET_VISAGE_LIST[i][R]
						break
					end
				end

				ply.ttt2_def_visage = chosen_role
				
				--print("DEF_DEBUG DisguiseDefectives: Defective " .. ply:GetName() .. " has been randomly assigned the visage of role '" .. chosen_name .. "' (index=" .. tostring(ply.ttt2_def_visage) .. "), with chosen_weight=" .. tostring(chosen_weight))
			end
			
			if STEAMID64_TO_VISAGE_ROLE_MAP == nil then
				STEAMID64_TO_VISAGE_ROLE_MAP = {}
			end
			STEAMID64_TO_VISAGE_ROLE_MAP[ply:SteamID64()] = ply.ttt2_def_visage
			events.Trigger(EVENT_DEF_GIVE_VISAGE, ply, chosen_name)
		end
	end
	
	local function DisguiseDefectives(m)
		for _, ply in ipairs(player.GetAll()) do
			DisguiseDefective(ply, m)
		end
	end
	
	hook.Add("TTTBeginRound", "DefectiveBeginRoundForServer", function()
		--Cache this variable early in case a Defective joins midgame.
		NUM_PLYS_AT_ROUND_BEGIN = GetNumPlayers()

		if not AtLeastOneDefExists() then
			return
		end

		DEF_DOING_SETUP_LOGIC = true
		
		--We don't need to call SendFullStateUpdate() here. Spy is handled correctly at the beginning of the round.
		UpdateSpyJam()
		
		if GetConVar("ttt2_defective_disable_spawn_if_no_detective"):GetBool() and not AtLeastOneDetExists() then
			--This round has no detectives! Quickly force all players of this role to be generic traitors.
			DisableAllDefectives()
			
			--Now that there are no defectives, we can leave this hook without consequence.
			DEF_DOING_SETUP_LOGIC = false
			return
		end
		
		local num_demotions = GetNumDetectiveDemotions()
		if num_demotions > 0 then
			--Force detectives to be innocent, if demotions are requested
			--Player table is shuffled to randomize who gets demoted.
			for _, ply in pairs(table.Shuffle(player.GetAll())) do
				if ply:GetBaseRole() == ROLE_DETECTIVE then
					JamDetective(ply, ply:GetBaseRole(), ply:GetSubRole(), JAM_DET_MODE.INNO)
					num_demotions = num_demotions - 1
				end

				if num_demotions <= 0 then
					break
				end
			end
		end

		local m = GetConVar("ttt2_defective_special_det_handling_mode"):GetInt()
		if m == SPECIAL_DET_MODE.JAM or (m == SPECIAL_DET_MODE.JAM_TEMP and AtLeastOneDefLives()) then
			--Force all special detectives to be normal detectives, in case they have some special equipment or ability that could instantly be used to make them trustworthy.
			for _, ply in pairs(player.GetAll()) do
				JamDetective(ply, ply:GetBaseRole(), ply:GetSubRole(), JAM_DET_MODE.BASE_DET)
			end
		elseif m == SPECIAL_DET_MODE.VISAGE then
			CalculateDetectiveVisages()
		end
		
		DisguiseDefectives(m)
		InformPlayersOfVisages()
		
		--Only send popup here, as opposed to also sending it on TTT2UpdateSubrole, as doing so could reveal the newly created defective.
		if GetConVar("ttt2_defective_inform_everyone"):GetBool() and AtLeastOneDetExists() then
			if m ~= SPECIAL_DET_MODE.VISAGE then
				net.Start("TTT2DefectiveInformEveryone")
				net.WriteBool(SPY_IS_JAMMING)
				net.Broadcast()
			else
				--Don't send the popup to Defectives, as we've already sent a more important pop up in the DisguiseDefectives call to inform them of their visage.
				for _, ply in ipairs(player.GetAll()) do
					if ply:GetSubRole() ~= ROLE_DEFECTIVE then
						net.Start("TTT2DefectiveInformEveryone")
						net.WriteBool(SPY_IS_JAMMING)
						net.Send(ply)
					end
				end
			end
		end
		
		SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
		DEF_DOING_SETUP_LOGIC = false
		DEF_SETUP_COMPLETE = true
	end)

	hook.Add("PlayerSpawn", "DefectivePlayerSpawn", function(ply)
		if DEF_SETUP_COMPLETE and AtLeastOneDefExists() then
			if ROLE_SPY and ply:GetSubRole() == ROLE_SPY then
				 UpdateSpyJam()
			end

			InformPlayersOfVisages()
			SendFullStateUpdate()
		end
	end)
	
	hook.Add("TTT2UpdateSubrole", "DefectiveUpdateSubrole", function(self, oldSubrole, subrole)
		--Don't bother messing with role logic in the beginning of the round here, as that's already happening in TTTBeginRound hook.
		if GetRoundState() ~= ROUND_ACTIVE or DEF_DOING_SETUP_LOGIC then
			return
		end
		
		local at_least_one_def_exists = AtLeastOneDefExists()
		
		if self.det_role_masked_by_def and self.det_role_masked_by_def ~= subrole then
			--Remove the special det's "true role" if they convert to anything other than their true role.
			--Ex. Infected, Deputy, Sidekick, etc.
			self.det_role_masked_by_def = nil
		end
		
		if not at_least_one_def_exists then
			return
		end
		
		--We do not immediately jam all special dets if a def shows up in the middle of the round, as that would immediately give away that they are a def.
		--Only jam special dets that show up when a def is currently in play.
		local m = GetConVar("ttt2_defective_special_det_handling_mode"):GetInt()
		if m == SPECIAL_DET_MODE.JAM or (m == SPECIAL_DET_MODE.JAM_TEMP and AtLeastOneDefLives()) then
			--This timer is a hack to give time for the player to finish setup for their current role before we change it to their new role. It won't work if the current role takes a lot of time to setup.
			--Specifically prevents situations where a sniffer is given their lens, but then changes to a detective before the lens can be properly removed.
			local base_role = roles.GetByIndex(subrole):GetBaseRole()
			timer.Simple(0.1, function()
				JamDetective(self, base_role, subrole, JAM_DET_MODE.BASE_DET)
			end)
		end
		
		if ROLE_SPY and (oldSubrole == ROLE_SPY or subrole == ROLE_SPY) then
			 UpdateSpyJam()
		end
		
		--Don't call this function during setup. Instead only call it if a role changes mid-game.
		if DEF_SETUP_COMPLETE then
			InformPlayersOfVisages()
			SendFullStateUpdate()
		end
		
		SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
	end)
	
	hook.Add("TTT2UpdateTeam", "DefectiveUpdateTeam", function(ply, oldTeam, newTeam)
		if DEF_SETUP_COMPLETE and AtLeastOneDefExists() then
			if ROLE_SPY and (oldSubrole == ROLE_SPY or subrole == ROLE_SPY) then
				 UpdateSpyJam()
			end
			
			--Resend visages in case a player changes to or from a team that can see the Defective's true identity
			InformPlayersOfVisages()
			SendFullStateUpdate()
		end
	end)
	
	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		--We disguise all Defectives when the round begins. However, if the Defective spawns mid-game, we'll need to whip up a quick disguise.
		--"NUM_PLYS_AT_ROUND_BEGIN > 0 and not DEF_DOING_SETUP_LOGIC" probably isn't necessary, but whatever.
		if isRoleChange and DEF_SETUP_COMPLETE then
			--print("DEF_DEBUG GiveRoleLoadout: NUM_PLYS_AT_ROUND_BEGIN=" .. tostring(NUM_PLYS_AT_ROUND_BEGIN) .. ", GetRoundState=" .. tostring(GetRoundState()))
			
			DisguiseDefective(ply, GetConVar("ttt2_defective_special_det_handling_mode"):GetInt())
			InformPlayersOfVisages()
		end
		
		--Send the role to everyone (observed role is changed during SendFullStateUpdate())
		--Sending this information here also handles cases where the def respawns, as without a SendFullStateUpdate() call their role could be revealed regardless of ConVar settings.
		SendPlayerToEveryone(ply)
		SendFullStateUpdate()
		
		--While GiveEquipmentItem() would be the better function to use here, it actually fails to give the defective the DNA scanner. Currently in the TTT2 codebase, Give() is used for the detective, so it should be fine here for now.
		--Also, unlike other roles, it appears that the normal detective does not lose their equipment item should they change roles or die.
		ply:Give("weapon_ttt_wtester")
	end
	
	function ROLE:RemoveRoleLoadout(ply, isRoleChange)
		if isRoleChange then
			--Remove the visage that the former Defective had, but only if their role changed. It would be blatantly obvious that the player is a Defective if they changed visages upon respawning
			ply.ttt2_def_visage = nil
			if STEAMID64_TO_VISAGE_ROLE_MAP then
				STEAMID64_TO_VISAGE_ROLE_MAP[ply:SteamID64()] = nil
			end
		end
	end
	
	hook.Add("TTT2SpecialRoleSyncing", "DefectiveSpecialRoleSyncing", function (ply, tbl)
		if GetRoundState() == ROUND_POST then 
			return
		end
		
		--print("DEF_DEBUG TTT2SpecialRoleSyncing: SPY_IS_JAMMING=" .. tostring(SPY_IS_JAMMING))
		
		--Cache boolean to save some processing time.
		local can_reveal_dead_def = CanADeadDefBeRevealed()
		
		for ply_i in pairs(tbl) do
			if not ply_i:IsTerror() or ply_i:SteamID64() == ply:SteamID64() then
				continue
			end
			
			if ply_i:GetSubRole() == ROLE_DEFECTIVE and (not ply_i:Alive() or IsInSpecDM(ply_i)) and can_reveal_dead_def then
				--Do not mess with dead def's apparent role if they're dead and can be revealed as their true role.
				continue
			end
			
			if SPY_IS_JAMMING and ply:GetBaseRole() == ROLE_TRAITOR and ply_i:GetBaseRole() == ROLE_TRAITOR then
				--If spy is jamming, force special traitors to look like regular traitors.
				--For some reason Spy does not handle this properly in its code when a Spy dies, so handle it here.
				--This takes priority over Defective. If a Spy cannot hide among special traitors (such as the Defective) they will likely be found out and shot when the player count is low.
				--Of course, Innocents could reveal the Defective as being a potential Detective, which would key in the Traitors on the Spy's true role.
				--Therefore, we also send a message at the beginning of the round informing that a Spy exists, which will hopefully make the Innocents more cautious on revealing such information.
				tbl[ply_i] = {ROLE_TRAITOR, TEAM_TRAITOR}
			elseif ply:GetSubRole() ~= ROLE_DEFECTIVE and ply_i:GetSubRole() == ROLE_DEFECTIVE and
				(ply:GetTeam() ~= TEAM_TRAITOR or (ply:GetTeam() == TEAM_TRAITOR and not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool())) then
				--Handle how everyone sees a defective (regardless of what team the Defective is on)
				--If the player can't see the Defective as their true role, display them as a Detective (this is the selling point of the role)
				tbl[ply_i] = {ply_i.ttt2_def_visage or ROLE_DETECTIVE, TEAM_INNOCENT}
			elseif ply:GetSubRole() == ROLE_DEFECTIVE and ply_i:GetTeam() == TEAM_TRAITOR and ply_i:GetSubRole() ~= ROLE_DEFECTIVE and not GetConVar("ttt2_defective_can_see_traitors"):GetBool() then
				--Handle how Defectives see Traitors:
				--If the Defective can see Traitors, we don't need to do anything since that's the default behavior.
				--If the Defective can't see Traitors, display them as the NONE role.
				--Technically, the Defective is the only public traitor role that currently exists
				--  However, in that theoretical case that there is another, we shouldn't mess with their role, as that would prevent them from being public.
				tbl[ply_i] = {ROLE_NONE, TEAM_NONE}
			elseif ply:GetSubRole() == ROLE_DEFECTIVE and ply_i:GetSubRole() == ROLE_DEFECTIVE and not GetConVar("ttt2_defective_can_see_defectives"):GetBool() then
				--Handle how defectives see other defectives
				--If the Defectives can't see each other, display them as Detectives.
				tbl[ply_i] = {ply_i.ttt2_def_visage or ROLE_DETECTIVE, TEAM_INNOCENT}
			end
		end
	end)
	
	hook.Add("TTT2ModifyRadarRole", "DefectiveModifyRadarRole", function(ply, target)
		--This function uses the same general logic as TTT2SpecialRoleSyncing, for consistency
		if GetRoundState() == ROUND_POST or (ROLE_SPY and ply:GetTeam() == TEAM_TRAITOR and target:GetSubRole() == ROLE_SPY) then
			return
		end

		if SPY_IS_JAMMING and ply:GetBaseRole() == ROLE_TRAITOR and target:GetBaseRole() == ROLE_TRAITOR then
			return ROLE_TRAITOR, TEAM_TRAITOR
		elseif ply:GetSubRole() ~= ROLE_DEFECTIVE and target:GetSubRole() == ROLE_DEFECTIVE and
			(ply:GetTeam() ~= TEAM_TRAITOR or (ply:GetTeam() == TEAM_TRAITOR and not GetConVar("ttt2_defective_can_be_seen_by_traitors"):GetBool())) then
			return target.ttt2_def_visage or ROLE_DETECTIVE, TEAM_INNOCENT
		elseif  ply:GetSubRole() == ROLE_DEFECTIVE and target:GetTeam() == TEAM_TRAITOR and target:GetSubRole() ~= ROLE_DEFECTIVE and not GetConVar("ttt2_defective_can_see_traitors"):GetBool() then
			return ROLE_NONE, TEAM_NONE
		elseif ply:GetSubRole() == ROLE_DEFECTIVE and target:GetSubRole() == ROLE_DEFECTIVE and not GetConVar("ttt2_defective_can_see_defectives"):GetBool() then
			return target.ttt2_def_visage or ROLE_DETECTIVE, TEAM_INNOCENT
		end
	end)
	
	hook.Add("TTT2AvoidTeamChat", "DefectiveAvoidTeamChat", function(sender, tm, msg)
		--Only jam traitor team chat
		if not tm == TEAM_TRAITOR or not IsValid(sender) or sender:GetTeam() ~= TEAM_TRAITOR or (sender:GetTeam() == TEAM_TRAITOR and SPY_IS_JAMMING) then
			--Notice that for the Spy its chat message takes priority over the Defective, as it is a more pressing issue for the Traitors
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
		if not isTeamVoice or not IsValid(speaker) or speaker:GetTeam() ~= TEAM_TRAITOR or (speaker:GetTeam() == TEAM_TRAITOR and SPY_IS_JAMMING) then
			--Notice that for the Spy its chat message takes priority over the Defective, as it is a more pressing issue for the Traitors
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
	
	hook.Add("DoPlayerDeath", "DefectiveDoPlayerDeath", function(ply, attacker, dmginfo)
		if SPY_IS_JAMMING then
			--Remove the DNA Scanner as it otherwise drops from the Defective's corpse.
			--RemoveRoleLoadout won't work here, as the player is already dead at that point (and the DNA Scanner has thus been dropped).
			ply:StripWeapon('weapon_ttt_wtester')
		end
	end)
	
	hook.Add("TTT2PostPlayerDeath", "DefectivePostPlayerDeath", function (victim, inflictor, attacker)
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(victim) or not victim:IsPlayer() or not DEF_SETUP_COMPLETE then
			return
		end
		
		local send_full_state_update = false
		
		if ROLE_SPY and (victim:GetSubRole() == ROLE_SPY) then
			UpdateSpyJam()
			send_full_state_update = true
		end
		
		--If a spy is no longer jamming then we will want to see if we can reveal visages, and update any Defective who has been masked by the Spy
		if not SPY_IS_JAMMING then
			InformPlayersOfVisages()
			send_full_state_update = true
		end
		
		local m = GetConVar("ttt2_defective_special_det_handling_mode"):GetInt()
		if m == SPECIAL_DET_MODE.JAM_TEMP and CanADeadDefBeRevealed() and not AtLeastOneDefLives() then
			--If all defs are dead, give any remaining special dets their roles back.
			for _, ply in pairs(player.GetAll()) do
				if ply.det_role_masked_by_def then
					events.Trigger(EVENT_DEF_UNDO_JAM, ply, ply.det_role_masked_by_def)
					ply:SetRole(ply.det_role_masked_by_def)
					--Call this function whenever a role change occurs during an active round.
					send_full_state_update = true
					
					--Remove this variable now that the special det has their role back.
					ply.det_role_masked_by_def = nil
				end
			end
		end
		
		if send_full_state_update then
			--print("DEF_DEBUG TTT2PostPlayerDeath: Calling SendFullStateUpdate")
			SendFullStateUpdate()
		end
		
		SendAtLeastOneDefectiveLivesTraitorOnlyMsg()
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
	
	hook.Add("TTTCanSearchCorpse", "DefectiveCanSearchCorpse", function(ply, corpse, isCovert, isLongRange)
		if not corpse or corpse.was_role ~= ROLE_DEFECTIVE or CanADeadDefBeRevealed() or SPY_IS_JAMMING_CORPSES then
			return
		end
		
		--Show all defectives as detectives when searched.
		if not STEAMID64_TO_VISAGE_ROLE_MAP or not STEAMID64_TO_VISAGE_ROLE_MAP[corpse.sid64] then
			--Fallback to plain Detective. Hopefully we don't enter here.
			corpse.was_role = ROLE_DETECTIVE
			corpse.was_team = TEAM_INNOCENT
			corpse.role_color = DETECTIVE.color
		else
			local def_vis_role_data = roles.GetByIndex(STEAMID64_TO_VISAGE_ROLE_MAP[corpse.sid64])
			corpse.was_role = STEAMID64_TO_VISAGE_ROLE_MAP[corpse.sid64]
			corpse.was_team = def_vis_role_data.defaultTeam
			corpse.role_color = def_vis_role_data.color
		end
	end)
	
	hook.Add("TTT2ConfirmPlayer", "DefectiveConfirmPlayer", function(confirmed, finder, corpse)
		--The Spy only checks for ttt2_spy_confirm_as_traitor in its hook, so we mimic that here.
		if ROLE_SPY and GetConVar("ttt2_spy_confirm_as_traitor"):GetBool() then
			return
		end
		
		--We do not invoke UpdateSpyJam() here. This is because the Spy's logic does not mess with special traitors in its hook to TTT2ConfirmPlayer
		if IsValid(confirmed) and corpse and confirmed:GetSubRole() == ROLE_DEFECTIVE and not CanADeadDefBeRevealed() then
			--Confirm player as a detective
			confirmed:ConfirmPlayer(true)
			SendRoleListMessage(confirmed.ttt2_def_visage or ROLE_DETECTIVE, TEAM_INNOCENT, {confirmed:EntIndex()})
			--Update the scoreboard to show the def as a det.
			events.Trigger(EVENT_BODYFOUND, finder, corpse)
			
			--Prevent traditional player confirmation from occurring (which would reveal the def).
			return false
		end
	end)
	
	hook.Add("TTTBodyFound", "DefectiveBodyFound", function(_, confirmed, corpse)
		--Only continue if we are set up to reveal the det's and def's roles.
		if not CanADeadDefBeRevealed() or SPY_IS_JAMMING_CORPSES then
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
	
	local function ResetDefectiveDataForServer()
		DEF_DOING_SETUP_LOGIC = false
		DEF_SETUP_COMPLETE = false
		NUM_PLYS_AT_ROUND_BEGIN = 0
		DET_VISAGE_LIST = nil
		DET_VISAGE_LIST_TOTAL_WEIGHT = 0
		STEAMID64_TO_VISAGE_ROLE_MAP = nil
		SPY_IS_JAMMING = false
		SPY_IS_JAMMING_CORPSES = false
		
		for _, ply in ipairs(player.GetAll()) do
			ply.ttt2_def_visage = nil
			ply.det_role_masked_by_def = nil
		end
	end
	hook.Add("TTTPrepareRound", "DefectivePrepareRoundForServer", ResetDefectiveDataForServer)
	hook.Add("TTTEndRound", "DefectivePrepareEndForServer", ResetDefectiveDataForServer)
end

if CLIENT then
	local icon_def = Material("vgui/ttt/dynamic/roles/icon_def")
	local at_least_one_def_lives_traitor_only = false
	local NAME_TO_VISAGE_ROLE_MAP = nil

	local function ResetDefectivePlayerDataForClient()
		--Initialize data that this client needs to know, but must be kept secret from other clients.
		at_least_one_def_lives_traitor_only = false
		NAME_TO_VISAGE_ROLE_MAP = nil
	end
	hook.Add("TTTEndRound", "ResetDefectiveForClientOnEndRound", ResetDefectivePlayerDataForClient)
	hook.Add("TTTPrepareRound", "ResetDefectiveForClientOnPrepareRound", ResetDefectivePlayerDataForClient)
	hook.Add("TTTBeginRound", "ResetDefectiveForClientOnBeginRound", ResetDefectivePlayerDataForClient)
	
	net.Receive("TTT2DefectiveInformEveryone", function()
		local client = LocalPlayer()
		local spy_jam = net.ReadBool()

		if spy_jam then
			EPOP:AddMessage({text = LANG.GetTranslation("inform_everyone_spy_" .. DEFECTIVE.name), color = DEFECTIVE.color}, "", 6)
		else
			EPOP:AddMessage({text = LANG.GetTranslation("inform_everyone_" .. DEFECTIVE.name), color = DEFECTIVE.color}, "", 6)
		end
	end)
	
	net.Receive("TTT2DefectiveInformVisage", function()
		local client = LocalPlayer()
		
		--WARNING: If a player changes roles to or from Defective in the middle of the round, this function will be called before the role has fully been changed.
		--print("DEF_DEBUG TTT2DefectiveInformVisage: client:GetName()=" .. client:GetName() .. ", client:SteamID64()=" .. tostring(client:SteamID64()) .. ", client:GetRoleString()=" .. client:GetRoleString())
		
		local num_visages = net.ReadInt(16)
		if num_visages <= 0 then
			--We are told to forget everything about any visages we may or may not have heard of.
			NAME_TO_VISAGE_ROLE_MAP = {}
			return
		end
		
		local old_visage_map = {}
		if NAME_TO_VISAGE_ROLE_MAP then
			for def_id_str, def_visage in pairs(NAME_TO_VISAGE_ROLE_MAP) do
				old_visage_map[def_id_str] = def_visage
			end
		end
		
		--Clear out any stale visages that may have been present.
		NAME_TO_VISAGE_ROLE_MAP = {}
		
		--Read in the table
		for i = 1, num_visages do
			local def_id_str = net.ReadString()
			local def_visage = net.ReadInt(16)
			local def_visage_role_data = roles.GetByIndex(def_visage)
			
			NAME_TO_VISAGE_ROLE_MAP[def_id_str] = def_visage
			
			--Display a large and loud pop-up on Defective's client if they are given a new visage that's different from their current one.
			if client:GetName() == def_id_str and def_visage ~= old_visage_map[def_id_str] then
				EPOP:AddMessage({text = LANG.GetParamTranslation("inform_visage_" .. DEFECTIVE.name, {role = def_visage_role_data.name}), color = def_visage_role_data.color}, "", 6)
			end
			
			--If a Defective has received a new visage, inform everyone who can know this via a small chat message.
			if def_visage ~= old_visage_map[def_id_str] then
				LANG.Msg("inform_visage_generic_" .. DEFECTIVE.name, {name = def_id_str, role = def_visage_role_data.name}, MSG_CHAT_WARN)
			end
		end
		
		--DEF_DEBUG
		--local debug_str = "DEF_DEBUG TTT2DefectiveInformVisage: old_visage_map(" .. client:GetName() .. ")=[ "
		--for def_id_str, def_visage in pairs(old_visage_map) do
		--	debug_str = debug_str .. "(" .. def_id_str .. "," .. roles.GetByIndex(def_visage).name ..") "
		--end
		--debug_str = debug_str .. "]"
		--print(debug_str)
		--debug_str = "DEF_DEBUG TTT2DefectiveInformVisage: NAME_TO_VISAGE_ROLE_MAP(" .. client:GetName() .. ")=[ "
		--for def_id_str, def_visage in pairs(NAME_TO_VISAGE_ROLE_MAP) do
		--	debug_str = debug_str .. "(" .. def_id_str .. "," .. roles.GetByIndex(def_visage).name ..") "
		--end
		--debug_str = debug_str .. "]"
		--print(debug_str)
		--DEF_DEBUG
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

	hook.Add("TTTRenderEntityInfo", "TTTRenderEntityInfoDefective", function(tData)
		local ply = tData:GetEntity()

		if not IsValid(ply) or not ply:IsPlayer() or not NAME_TO_VISAGE_ROLE_MAP or not NAME_TO_VISAGE_ROLE_MAP[ply:GetName()] then
			return
		end

		local visage_role_data = roles.GetByIndex(NAME_TO_VISAGE_ROLE_MAP[ply:GetName()])
		tData:AddDescriptionLine(
			LANG.GetParamTranslation("visage_display_" .. DEFECTIVE.name, {role = visage_role_data.name}),
			visage_role_data.ltcolor
		)
	end)

	-------------
	-- CONVARS --
	-------------
	function ROLE:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_roles_additional")

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_inform_everyone",
			label = "label_defective_inform_everyone"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_shop_order_prevention",
			label = "label_defective_shop_order_prevention"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_detective_immunity",
			label = "label_defective_detective_immunity"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_can_see_traitors",
			label = "label_defective_can_see_traitors"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_can_be_seen_by_traitors",
			label = "label_defective_can_be_seen_by_traitors"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_can_see_defectives",
			label = "label_defective_can_see_defectives"
		})

		form:MakeComboBox({
			serverConvar = "ttt2_defective_corpse_reveal_mode",
			label = "label_defective_corpse_reveal_mode",
			choices = {{
				value = 0,
				title = LANG.GetTranslation("label_defective_corpse_reveal_mode_0")
			},{
				value = 1,
				title = LANG.GetTranslation("label_defective_corpse_reveal_mode_1")
			},{
				value = 2,
				title = LANG.GetTranslation("label_defective_corpse_reveal_mode_2")
			},{
				value = 3,
				title = LANG.GetTranslation("label_defective_corpse_reveal_mode_3")
			}}
		})

		form:MakeComboBox({
			serverConvar = "ttt2_defective_special_det_handling_mode",
			label = "label_defective_special_det_handling_mode",
			choices = {{
				value = 0,
				title = LANG.GetTranslation("label_defective_special_det_handling_mode_0")
			},{
				value = 1,
				title = LANG.GetTranslation("label_defective_special_det_handling_mode_1")
			},{
				value = 2,
				title = LANG.GetTranslation("label_defective_special_det_handling_mode_2")
			},{
				value = 3,
				title = LANG.GetTranslation("label_defective_special_det_handling_mode_3")
			}}
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_defective_disable_spawn_if_no_detective",
			label = "label_defective_disable_spawn_if_no_detective"
		})
		
		form:MakeSlider({
			serverConvar = "ttt2_defective_demote_detective_pct",
			label = "label_defective_demote_detective_pct",
			min = 0.0,
			max = 1.0,
			decimal = 2
		})
	end
end

----------
--SHARED--
----------

hook.Add("TTT2GraverobberPreventSelection", "DefectiveGraverobberPreventSelection", function(ply)
	if ply:GetSubRole() == ROLE_DEFECTIVE then
		return true
	end
end)
