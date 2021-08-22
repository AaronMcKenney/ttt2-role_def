if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/vskin/events/def_demote_det.vmt")
end

if CLIENT then
	EVENT.title = "title_event_def_demote_det"
	EVENT.icon = Material("vgui/ttt/vskin/events/def_demote_det.vmt")
	
	function EVENT:GetText()
		return {
			{
				string = "desc_event_def_demote_det",
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
	function EVENT:Trigger(det)
		self:AddAffectedPlayers(
			{det:SteamID64()},
			{det:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			det_name = det:GetName(),
			det_role = det:GetSubRole()
		})
	end
	
	function EVENT:Serialize()
		return self.event.serialname
	end
end