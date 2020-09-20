--[[
	Tab for Anchor data
]]

function navcomp.com.ui:CreateAnchorTab (selected)
	local function BuildList ()
		local list = {}
		local sectorId, anchors
		for sectorId, anchors in pairs (navcomp.data.anchors) do
			if sectorId ~= "error" then
				list [LocationStr (tonumber (sectorId))] = {sectorId=sectorId, anchors=anchors}
			end
		end
		
		return list
	end
	
	local anchorTab = iup.vbox {
		navcomp.com.ui:CreateList ("Sector", "anchors", selected, BuildList);
		font = navcomp.ui.font,
		tabtitle = "Anchors",
		size = "1000x400"
	}
	
	function anchorTab:Reset ()
		selected.anchors = nil
	end
	
	function anchorTab:DoClose ()
	end
	
	return anchorTab
end