local _,private = ...

local MAX_SPECS = 4 -- druid has 5 specs

local buttonPoolSpecSwap = {}
local buttonPoolIcons = {}

-- may be a premature optimization
local lootSpecListCache = nil
local function setNeedsUpdate()
	lootSpecListCache = nil
end
for _,func in ipairs{"EJ_SelectTier", "EJ_SetDifficulty", "EJ_SelectEncounter", "EJ_SelectInstance", "EJ_SelectInstance", "EJ_SetLootFilter"} do
	hooksecurefunc(_G, func, setNeedsUpdate)
end
hooksecurefunc(C_EncounterJournal, "SetSlotFilter", setNeedsUpdate)

local BASE_NAME_SPEC_CHOOSE_BUTTON = "mylootspecchoiceshowingbutton"
local function updateEncounterJournalLootSpecSwapButtons()
	local lastButton = nil
	local desiredLootSpec = GetLootSpecialization()
	for i=1,GetNumSpecializations() do
		local frameName = BASE_NAME_SPEC_CHOOSE_BUTTON..i
		local frame = buttonPoolSpecSwap[frameName]
		local specID,specName,_,icon,_,_ = GetSpecializationInfo(i)
		if not frame then
			frame = CreateFrame("BUTTON", nil, EncounterJournal)
			buttonPoolSpecSwap[frameName] = frame;
			frame.texture = frame:CreateTexture()
			frame.texture:SetAllPoints(frame)
			frame:SetSize(40, 40)
			frame:SetScript("OnClick", function() SetLootSpecialization(specID) end)
			frame:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				local iconString =  (frame.isCurrentLootSpec and "Your loot spec is currently set to" or "Switch your loot spec to").." |T"..icon..":20|t "..specName.."."
				GameTooltip:SetText(iconString, nil, nil, nil, nil, true)
				GameTooltip:Show()
			end)
			frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
		end
		if lastButton then
			frame:SetPoint("BOTTOMRIGHT", lastButton, "TOPRIGHT")
		else
			frame:SetPoint("BOTTOMLEFT", EncounterJournal, "BOTTOMRIGHT")
		end

		frame.texture:SetTexture(icon)
		frame.isCurrentLootSpec = specID == desiredLootSpec
		frame.texture:SetDesaturated(not frame.isCurrentLootSpec)

		lastButton = frame
	end
end

-- returns the class that loot spec icons are being shown/should be shown for.
local function getSpecIconClassID()
	local currentClassFilter = EJ_GetLootFilter()
	if currentClassFilter == 0 then -- use player's class.
		return select(3, UnitClass("player"))
	else
		return currentClassFilter
	end
end

local function getSpecLootInfo()
	if lootSpecListCache then return lootSpecListCache end

	local classID = getSpecIconClassID()

	local previousClassFilter, previousSpecFilter = EJ_GetLootFilter()

	-- n.b. EJ_SetLootFilter sets lootSpecListCache to nil, so store its value in a local variable until you're done calling EJ_SetLootFilter.
	local loots = {}
	for i=1,MAX_SPECS do
		local specID = GetSpecializationInfoForClassID(classID, i)
		if not specID then break end
		EJ_SetLootFilter(classID, specID)
		for j=1,EJ_GetNumLoot() do
			local itemID = C_EncounterJournal.GetLootInfoByIndex(j).itemID

			if not loots[itemID] then loots[itemID] = {} end
			loots[itemID][specID] = true
		end
	end
	EJ_SetLootFilter(previousClassFilter, previousSpecFilter)

	lootSpecListCache = loots
	return lootSpecListCache
end

local SPEC_ICON_FRAME_NAME = "MyLootSpecIcons"
local function updateEncounterJournalLootSpecItems()
	if not EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox
			or not EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox:IsShown() then
		return
	end

	-- wtf 10.0, I don't understand what happened to scroll frames but this hiding is necessary.
	for name,frame in pairs(buttonPoolIcons) do
		frame:Hide()
	end

	local loots = getSpecLootInfo()

	for scrollItemIndex,itemButton in ipairs(EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox:GetFrames()) do
		local previousSpecFrame = nil
		local specIconCount = 1
		if loots[itemButton.itemID] then
			for lootSpecID,_ in pairs(loots[itemButton.itemID]) do
				local iconFrameName = SPEC_ICON_FRAME_NAME..scrollItemIndex.."_"..specIconCount
				local specFrame = buttonPoolIcons[iconFrameName]
				if not specFrame then
					specFrame = CreateFrame("FRAME", iconFrameName, itemButton)
					buttonPoolIcons[iconFrameName] = specFrame
					specFrame:SetSize(20, 20)
					specFrame.texture = specFrame:CreateTexture()
					specFrame.texture:SetAllPoints(specFrame)
				end
				specFrame:Show()
				specFrame:SetParent(itemButton)

				specFrame:ClearAllPoints()
				if not previousSpecFrame then
					specFrame:SetPoint("BOTTOMRIGHT", itemButton.name, "TOPLEFT", 264, -30 - 3) -- besides the -3, this is the same anchor as armorType uses.
				else
					specFrame:SetPoint("TOPRIGHT", previousSpecFrame, "TOPLEFT")
				end

				local _,_,_,icon = GetSpecializationInfoByID(lootSpecID);
				specFrame.texture:SetTexture(icon)

				previousSpecFrame = specFrame
				specIconCount = specIconCount + 1
			end
		end
		if itemButton.armorType then
			itemButton.armorType:ClearAllPoints()
			if previousSpecFrame and itemButton.armorType then
				itemButton.armorType:SetPoint("RIGHT", previousSpecFrame, "LEFT", -3, -2)
			else
				itemButton.armorType:SetPoint("BOTTOMRIGHT", itemButton.name, "TOPLEFT", 264, -30)
			end
		end
		for j=specIconCount,MAX_SPECS do
			local specFrame = buttonPoolIcons[SPEC_ICON_FRAME_NAME..scrollItemIndex.."_"..j]
			if specFrame then specFrame:Hide() end
		end
	end
end

do
	local init
	hooksecurefunc(_G, "EncounterJournal_LoadUI", function()
		if not init then
			EncounterJournal:HookScript("OnUpdate", function()
				updateEncounterJournalLootSpecItems()
				updateEncounterJournalLootSpecSwapButtons()
			end)
			init = true
		end
	end)
end

