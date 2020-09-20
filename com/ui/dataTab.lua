--[[
	Tab for managing encounter data of bots and storms
]]

function navcomp.com.ui:CreateDataTab (selected)
	local function BuildList ()
		-- Load Data
		local list = {}
		local k, v, sysId, x, y, name
		for _, v in pairs (navcomp.data.stormSectors) do
			sysId, y, x = SplitSectorID (v)
			name = SystemNames [sysId]
			if not list [name] then list [name] = {storms = {}, hive = {}} end
			table.insert (list [name].storms, v)
		end
		for _, v in pairs (navcomp.data.botSectors) do
			sysId, y, x = SplitSectorID (v)
			name = SystemNames [sysId]
			if not list [name] then list [name] = {storms = {}, hive = {}} end
			table.insert (list [name].hive, v)
		end
		
		return list
	end
	
	local dataTab = iup.vbox {
		navcomp.com.ui:CreateList ("System", "data", selected, BuildList);
		font = navcomp.ui.font,
		tabtitle = "Data",
		size = "1000x400"
	}
	
	function dataTab:Reset ()
		selected.data = nil
	end
	
	function dataTab:DoClose ()
	end
	
	return dataTab
end