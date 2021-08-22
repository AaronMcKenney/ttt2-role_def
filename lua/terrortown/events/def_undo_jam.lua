if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/vskin/events/def_undo_jam.vmt")
end

if CLIENT then
	EVENT.title = "title_event_def_undo_jam"
	EVENT.icon = Material("vgui/ttt/vskin/events/def_undo_jam.vmt")
	
	function EVENT:GetText()
		return {
			{
				string = "desc_event_def_undo_jam",
				params = {
					name = self.event.det_name,
					oldRole = roles.GetByIndex(self.event.det_role).name
				},
				translateParams = true
			}
		}
    end
end

if SERVER then
	function EVENT:Trigger(det, role)
		self:AddAffectedPlayers(
			{det:SteamID64()},
			{det:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			det_name = det:GetName(),
			det_role = role
		})
	end
	
	function EVENT:Serialize()
		return self.event.serialname
	end
end