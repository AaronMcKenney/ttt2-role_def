if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/vskin/events/def_disabled.vmt")
end

if CLIENT then
	EVENT.title = "title_event_def_disabled"
	EVENT.icon = Material("vgui/ttt/vskin/events/def_disabled.vmt")
	
	function EVENT:GetText()
		return {
			{
				string = "desc_event_def_disabled",
				params = {
					name = self.event.def_name
				},
				translateParams = true
			}
		}
    end
end

if SERVER then
	function EVENT:Trigger(def)
		self:AddAffectedPlayers(
			{def:SteamID64()},
			{def:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			def_name = def:GetName()
		})
	end
	
	function EVENT:Serialize()
		return self.event.serialname
	end
end