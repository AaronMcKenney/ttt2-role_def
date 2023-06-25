if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_def.vmt")
end

if CLIENT then
	EVENT.title = "title_event_def_give_visage"
	EVENT.icon = Material("vgui/ttt/dynamic/roles/icon_def.vmt")
	
	function EVENT:GetText()
		
		return {
			{
				string = "desc_event_def_give_visage",
				params = {
					name = self.event.def_name,
					role = self.event.def_visage_name
				},
				translateParams = true
			}
		}
    end
end

if SERVER then
	function EVENT:Trigger(def, chosen_name)
		self:AddAffectedPlayers(
			{def:SteamID64()},
			{def:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			def_name = def:GetName(),
			def_visage_name = chosen_name
		})
	end
	
	function EVENT:Serialize()
		return self.event.serialname
	end
end