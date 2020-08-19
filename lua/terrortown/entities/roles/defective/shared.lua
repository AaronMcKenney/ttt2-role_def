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
end