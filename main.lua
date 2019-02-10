local _,private = ...

local MAX_SPECS = 4 -- druid has 5 specs
local specIDs = {
	[6] = { 250, 251, 252, },
	[12] = { 577, 581, },
	[11] = { 102, 103, 104, 105, },
	[3] = { 253, 254, 255, },
	[8] = { 62, 63, 64, },
	[10] = { 268, 269, 270, },
	[2] = { 65, 66, 70, },
	[5] = { 256, 257, 258, },
	[4] = { 259, 260, 261, },
	[7] = { 262, 263, 264, },
	[9] = { 265, 266, 267, },
	[1] = { 71, 72, 73, },
}
local buttonPool = {}

lootSpecListCache = nil -- Used by loot spec icon attaching code.

local function setNeedsUpdate()
	lootSpecListCache = nil
end

local original_EJ_SetLootFilter = EJ_SetLootFilter
function EJ_SetLootFilter(...)
	setNeedsUpdate()
	original_EJ_SetLootFilter(...)
end
hooksecurefunc(_G, "EJ_SelectInstance", function(id) setNeedsUpdate() private.currentlyDisplayedInstanceID = id end)
for _,func in ipairs{"EJ_SetSlotFilter", "EJ_SelectTier", "EJ_SetDifficulty", "EJ_SelectEncounter"} do
	hooksecurefunc(_G, func, setNeedsUpdate)
end

local BASE_NAME_SPEC_CHOOSE_BUTTON = "mylootspecchoiceshowingbutton"
local function updateEncounterJournalLootSpecSwapButtons()
	local lastButton = nil
	local desiredLootSpec = GetLootSpecialization()
	for i=1,GetNumSpecializations() do
		local frameName = BASE_NAME_SPEC_CHOOSE_BUTTON..i
		local frame = buttonPool[frameName]
		local specID,specName,_,icon,_,_ = GetSpecializationInfo(i)
		if not frame then
			frame = CreateFrame("BUTTON", nil, EncounterJournal)
			buttonPool[frameName] = frame;
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

	local loots = {}
	for i=1,#specIDs[classID] do
		local specID = specIDs[classID][i]
		local _,_,_,icon = GetSpecializationInfoByID(specID)

		original_EJ_SetLootFilter(classID, specID)
		for j=1,EJ_GetNumLoot() do
			local itemID = EJ_GetLootInfoByIndex(j)

			if not loots[itemID] then loots[itemID] = {} end
			loots[itemID][specID] = true
		end
	end
	lootSpecListCache = loots

	original_EJ_SetLootFilter(previousClassFilter, previousSpecFilter)
	return lootSpecListCache
end

local SPEC_ICON_FRAME_NAME = "MyLootSpecIcons"
local function updateEncounterJournalLootSpecItems()
	if not EncounterJournalEncounterFrameInfoLootScrollFrame
			or not EncounterJournalEncounterFrameInfoLootScrollFrame:IsShown() then
		return
	end

	local loots = getSpecLootInfo()

	for i=1,EJ_GetNumLoot() do
		local lootFrame = _G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i]
		if not lootFrame then break end

		local previousSpecFrame = nil
		local specIconCount = 1
		if loots[lootFrame.itemID] then
			for lootSpecID,forThisLootSpec in pairs(loots[lootFrame.itemID]) do
				local iconFrameName = SPEC_ICON_FRAME_NAME..i.."_"..specIconCount
				if forThisLootSpec then
					local specFrame = buttonPool[iconFrameName]
					if not specFrame then
						specFrame = CreateFrame("FRAME", iconFrameName, lootFrame)
						buttonPool[iconFrameName] = specFrame
						specFrame:SetSize(20, 20)
						specFrame.texture = specFrame:CreateTexture()
						specFrame.texture:SetAllPoints(specFrame)
					end
					specFrame:Show()

					if not previousSpecFrame then
						specFrame:SetPoint("BOTTOMRIGHT", lootFrame, "BOTTOMRIGHT", 0, 3)
					else
						specFrame:SetPoint("TOPRIGHT", previousSpecFrame, "TOPLEFT")
					end

					local _,_,_,icon = GetSpecializationInfoByID(lootSpecID);
					specFrame.texture:SetTexture(icon)

					previousSpecFrame = specFrame
					specIconCount = specIconCount + 1
				end
			end
		end
		if previousSpecFrame then
			lootFrame.armorType:ClearAllPoints()
			lootFrame.armorType:SetPoint("RIGHT", previousSpecFrame, "LEFT", -3, 0)
		end
		for j=specIconCount,MAX_SPECS do
			local specFrame = buttonPool[SPEC_ICON_FRAME_NAME..i.."_"..j]
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

--[[
Disable bonus roll button opening of encounterjournal from setting spec filter,
since this addon makes spec filters mostly useless.
--]]
do
	local previous_OpenBonusRollEncounterJournalLink = OpenBonusRollEncounterJournalLink
	function OpenBonusRollEncounterJournalLink()
		local currentClass,currentSpec = EJ_GetLootFilter()
		previous_OpenBonusRollEncounterJournalLink()
		EJ_SetLootFilter(currentClass, currentSpec)
	end
end

