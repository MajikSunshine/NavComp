--------------------------------------------------------------
--
--	Data Handling Functions
--
--------------------------------------------------------------

function navcomp.data:Clone (t)
	if not t then return nil end
	local temp = {}
	local prop, value
	for prop, value in pairs (t) do
		if type (value) == "table" then
			temp [prop] = navcomp.data:Clone (value)
		else
			temp [prop] = value
		end
	end
	
	return temp
end

function navcomp.data:SetPathDefaults (path)
	path.note = path.note or ""
	path.autoReload = path.autoReload or false
	path.autoPlot = path.autoPlot or false
	path.path = path.path or GetFullPath (GetCurrentSectorid (), NavRoute.GetCurrentRoute ())
	
	return path
end

function navcomp.data:CreatePath (data)
	if data and data.name then
		-- Create basic path with standard properties
		return navcomp.data:SetPathDefaults (navcomp.data:Clone (data))
	end
end

function navcomp.data:BuildWormholeList ()
	local sysId,sectorId
	local sysMapName, sysData
	local x, y
	local id
	navcomp.data.whSectors = {}
	for sysId,_ in ipairs (SystemNames) do
		id = ""
		if sysId < 10 then id = "0" end
		id = id .. tostring (sysId)
		sysMapName = string.format ("lua/maps/system%smap.lua", id)
		sysData = dofile (sysMapName)
		for _,v in ipairs (sysData [1]) do
			if string.find (v.desc:lower (), "wormhole") then
				sectorId = 256 * (sysId-1) + v.id
				navcomp.data.whSectors [#navcomp.data.whSectors + 1] = sectorId
			end
		end
	end
	navcomp.data.isStormDataSaved = false
	navcomp.data:SaveStormSectors ()
end

function navcomp.data:AddToStormString (sectorId)
	if navcomp.data.stormSectorStr:len () > 0 then
		navcomp.data.stormSectorStr = navcomp.data.stormSectorStr .. "|" .. sectorId .. "|"
	else
		navcomp.data.stormSectorStr = "|" .. tostring (sectorId) .. "|"
	end
end

function navcomp.data:AddToBotString (sectorId)
	if navcomp.data.botSectorStr:len () > 0 then
		navcomp.data.botSectorStr = navcomp.data.botSectorStr .. "|" .. sectorId .. "|"
	else
		navcomp.data.botSectorStr = "|" .. tostring (sectorId) .. "|"
	end
end

-- Data Processing Functions
function navcomp.data:RecordStorm (s1, inStation)
	local str = "Recording Storm in "
	if inStation then
		str = "Storm reported in "
	end
	if not string.find (navcomp.data.stormSectorStr, "|" .. s1 .. "|") then
		purchaseprint (str .. AbbrLocationStr (s1))
		table.insert (navcomp.data.stormSectors, s1)
		navcomp.data.isStormDataSaved = false
		navcomp.data:AddToStormString (s1)
		navcomp.data.stressMaps [GetSystemID (s1)] = nil
	end
end

function navcomp.data:RecordBots (s1, inStation)
	local str = "Recording Hostile Bots in "
	if inStation then
		str = "Hive activity reported in "
	end
	if not string.find (navcomp.data.botSectorStr, "|" .. s1 .. "|") then
		purchaseprint (str .. AbbrLocationStr (s1))
		table.insert (navcomp.data.botSectors, s1)
		navcomp.data.isStormDataSaved = false
		navcomp.data:AddToBotString (s1)
		navcomp.data.stressMaps [GetSystemID (s1)] = nil
	end
end

function navcomp.data:GetSectorIdFromName (sectorName, pattern)
	if not sectorName then return nil end
	
	-- Determine Sector ID
	pattern = pattern or "(%a+%s?%a*)%s(%a)%-?(%d%d?)"
	local sysName, h, v = string.match (sectorName, pattern)
	if sysName then
		return 256 * (navcomp.data.systems [sysName]-1) + 16 * (v-1) + navcomp.data.sectors [h]
	else
		return nil
	end
end

-- Check Station Missions for Storm Info
function navcomp.data:CheckStationMissions ()
	local info, a, b, sysName, temp, h, v, sectorId, stormPresent
	for k=1, GetNumAvailableMissions () do
		info = GetAvailableMissionInfo (k)
		
		--Hive presence in sysName H-V (Ion Storm in progress)
		if string.find (info.desc, "Hive presence in") then
			-- Found Hive Skirmish
			local check
			if string.find (info.desc, "Ion Storm in progress") then
				check = "Hive presence in (.+) (%(Ion Storm in progress%))$"
			else
				check = "Hive presence in (.+)$"
			end
			temp, stormPresent = string.match (info.desc, check)
			
			-- Determine Sector ID
			sectorId = navcomp.data:GetSectorIdFromName (temp)
			
			-- Add sector to Hive data
			navcomp.data:RecordBots (sectorId, true)
			if stormPresent then
				navcomp.data:RecordStorm (sectorId, true)
			end
			
		end
	end
	if not navcomp.data.isStormDataSaved then
		navcomp.data:SaveStormSectors ()
	end
end

function navcomp.data:CheckHostile ()
	if not navcomp.data.hive.isHostile then
		local sectorId = GetCurrentSectorid ()
		ForEachPlayer (function (id)
			local faction = GetPlayerFaction (id) or 1
			if faction == 0 then
				if navcomp:IsHostileBotSector (GetPlayerName (id)) and 
						not navcomp:IsStationSector (sectorId) and not navcomp:IsWormholeSector (sectorId) then
					navcomp.data.hive.isHostile = true
					navcomp.data:RecordBots (sectorId)
				end
			end
		end)
	end
end

function navcomp.data:RemoveHostileSector (sectorId)
	-- Remove sector ID from hostile list
	for k,v in ipairs (navcomp.data.botSectors) do
		if v == sectorId then
			table.remove (navcomp.data.botSectors, k)
			purchaseprint ("Removing Hostile Bot record in " .. AbbrLocationStr (sectorId))
			navcomp.data.botSectorStr = "|" .. table.concat (navcomp.data.botSectors, "|") .. "|"
			navcomp.data.stressMaps [GetSystemID (sectorId)] = nil
			break
		end
	end
end

function navcomp.data:ClearData (sysId, type)
	navcomp.data.avoidSectors = {}
	navcomp:SyncSectorNotes ()
	if sysId then
		-- Loop through data and remove all sector IDs which match passed sysId
		navcomp.data.stressMaps [sysId] = nil
		local k, s, sys
		if type == 0 or type == 3 then
			for k, s in ipairs (navcomp.data.stormSectors) do
				sys = SplitSectorID (s)
				if sys == sysId then
					table.remove (navcomp.data.stormSectors, k)
				end
			end
			navcomp.data.stormSectorStr = "|" .. table.concat (navcomp.data.stormSectors, "|") .. "|"
			purchaseprint (string.format ("Storm Data Cleared for %s", SystemNames [sysId]))
		end
		if type == 1 or type == 3 then
			for k, s in ipairs (navcomp.data.botSectors) do
				sys = SplitSectorID (s)
				if sys == sysId then
					table.remove (navcomp.data.botSectors, k)
				end
			end
			navcomp.data.botSectorStr = "|" .. table.concat (navcomp.data.botSectors, "|") .. "|"
			purchaseprint (string.format ("Hive Data Cleared for %s", SystemNames [sysId]))
		end
	else
		-- Clear all systems
		navcomp.data.stressMaps = {}
		if type == 0 or type == 3 then
			navcomp.data.stormSectors = {}
			navcomp.data.stormSectorStr = ""
			purchaseprint ("Storm Data Cleared")
		end
		
		if type == 1 or type == 3 then
			navcomp.data.botSectors = {}
			navcomp.data.botSectorStr = ""
			purchaseprint ("Hive Data Cleared")
		end
	end
	navcomp.data.isStormDataSaved = false
	navcomp.data:SaveStormSectors ()
end