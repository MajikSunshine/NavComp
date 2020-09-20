--[[
	VO PDA Interface
]]

navcomp.pda = {}
local plotButton = nil
local evasionButton = nil

function navcomp.pda:CreateUI (navTab)
	-- Build Button Set for Navigational PDA
	plotButton = iup.stationbutton {title="Plot", font=navcomp.ui.font, action=function () navcomp:SyncSectorNotes () navcomp:PlotPath () end, hotkey=iup.K_p}
	local optionsButton = iup.stationbutton {title="Options", font=navcomp.ui.font, action=navcomp.Options}
	local syncButton = iup.stationbutton {title="Sync", font=navcomp.ui.font, action=function () navcomp.SyncSectorNotes () navcomp:Print ("Synchronization Complete") end}
	local autoReloadButton = iup.stationbutton {title="AutoReload", font=navcomp.ui.font, action=navcomp.AutoReloadCurrentPath}
	local optionsPanel
	if navTab == PDAShipNavigationTab then
		evasionButton = iup.stationbutton {title="Evade", font=navcomp.ui.font, action=navcomp.ToggleEvasionMode}
		optionsPanel = iup.hbox {
			evasionButton,
			optionsButton,
			syncButton,
			autoReloadButton;
			expand="HORIZONTAL"
		}
	else
		optionsPanel = iup.hbox {
			optionsButton,
			syncButton,
			autoReloadButton;
			expand="HORIZONTAL"
		}
	end
	local content = iup.vbox {
		iup.label {title="NavComp - v" .. navcomp.version, font=navcomp.ui.font, fgcolor=navcomp.ui.fgcolor, expand="HORIZONTAL"},
		iup.hbox {
			plotButton,
			iup.stationbutton {title="Save", font=navcomp.ui.font, action=navcomp.SavePath, expand="HORIZONTAL"},
			iup.stationbutton {title="Load", font=navcomp.ui.font, action=navcomp.LoadPath, expand="HORIZONTAL"},
			iup.stationbutton {title="Clear Data", font=navcomp.ui.font, action=navcomp.ClearStorms, expand="HORIZONTAL"};
			expand="HORIZONTAL"
		},
		optionsPanel;
	}
	
	iup.Append (navTab [3], content)
	iup.Refresh (navTab)
end

function navcomp.pda:CreateBarUI (barTab)
	-- Build Exchange Buttons
	local content = iup.vbox {
		iup.label {title="NavComp - v" .. navcomp.version, font=navcomp.ui.font, fgcolor=navcomp.ui.fgcolor},
		iup.stationbutton {title="Exchange", font=navcomp.ui.font, action=function () navcomp.com.ui:CreateUI () end};
	}
	
	-- Build Toolbar UI
	local toolbar = iup.hbox {
		toolbar = "YES"
	}

	local child = iup.GetNextChild (barTab [1][1])
	while (child and not child.toolbar) do
		child = iup.GetNextChild (barTab [1][1], child)
	end
	if child and child.toolbar then
		iup.Append (child, content)
		iup.Append (child, iup.fill {})
	else
		iup.Append (barTab [1][1], toolbar)
		iup.Append (toolbar, content)
		iup.Append (toolbar, iup.fill {})
	end
	iup.Refresh (barTab)
end

function navcomp.pda:SetPlotMode (flag)
	if flag then
		plotButton.active = "NO"
	else
		plotButton.active = "YES"
	end
end

function navcomp.pda:SetEvasionMode (flag)
	navcomp.data.isEvading = flag
	if flag then
		evasionButton.title = "Resume"
		navcomp.ui.evasionIndicator.visible = "YES"
	else
		evasionButton.title = "Evade"
		navcomp.ui.evasionIndicator.visible = "NO"
	end
	iup.Refresh (evasionButton)
	iup.Refresh (HUD.cboxlayer)
end

-- Paint all the storm sectors
function navcomp.pda:PaintSectors (navmap, sysId, storms, bots)
	local sectorId, color, colorId
	local x, y
	for x = 1, 16 do
		for y = 1, 16 do
			color = 0
			sectorId = navcomp:BuildSectorId (sysId, x, y)
			if navcomp:IsEncounteredStormSector (sectorId) then color = color + 1 end
			if navcomp:IsEncounteredBotSector (sectorId) then color = color + 2 end
			if navcomp:IsAvoidSector (sectorId) then color = color + 4 end
			if navcomp:GetSectorNote (sectorId) then
			if string.find (navcomp:GetSectorNote (sectorId), "#anchors") then color = 8 end
			end
			-- Set the sector color based on hazard
			if color > 0 then
				colorId = string.format ("COLOR%d", sectorId)
				navmap [colorId] = navcomp.ui.hazardColors [color]
			end
		end
	end
end

-- Custom PDA Navmap
navcomp.pda.lastLoadedSysId = 0
function navcomp.pda:CreateNavmapUI (pdaTab)
	local navmap = pdaTab [1][1][1][1]
	
	local oldLoadMap = navmap.loadmap
	function navmap:loadmap (type, path, id)
		oldLoadMap (self, type, path, id)
		navcomp.pda.lastLoadedSysId = 0
		if type == 2 then
			navcomp.pda.lastLoadedSysId = id + 1
			navcomp.pda:PaintSectors (navmap, id + 1, navcomp.data.stormSectors, navcomp.data.botSectors)
		end
	end
	
	local oldClickMap = navmap.click_cb
	function navmap:click_cb (index, modifiers)
		oldClickMap (self, index, modifiers)
		navcomp:ClearActivePath ()
	end
	
	-- Index is sectorId
	-- str is sector string
	local oldMouseoverMap = navmap.mouseover_cb
	local currentSectorId, startAnchorId
	function navmap:mouseover_cb (index, str)
		currentSectorId = index
		oldMouseoverMap (self, index, str)
	end
	
	local oldKeyHandler = pdaTab.k_any
	local setAnchor = false
	function pdaTab:k_any (key)
		if key == iup.K_v then
			if setAnchor then
				-- Need to check if anchor was placed in requested sector
				--local _, _, anch = navcomp:GetAnchorDefinition (currentSectorId)
				navcomp:Print ("Place Anchor in " .. LocationStr (currentSectorId))
				navcomp:WriteNewAnchors ({
					sectorId = currentSectorId,
					anchors = {{
						s = startAnchorId
					}}
				})
				startAnchorId = nil
				setAnchor = false
			else
				navcomp:Print ("Start Anchor in " .. LocationStr (currentSectorId))
				startAnchorId = currentSectorId
				setAnchor = true
			end
			return iup.CONTINUE
		else
			return oldKeyHandler (self, key)
		end
	end
end