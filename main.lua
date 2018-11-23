hooksecurefunc(_G, "EJ_SelectEncounter", function(id) currentEncounterID = id end)

-- My own loot list needs update thing --
-- Make sure this stuff calls the previous versions of the set functions.
lootSpecListCache = nil -- Used by loot spec icon attaching code.
filteredLootList = nil -- used by transmog filter code.

local function setNeedsUpdate()
	filteredLootList = nil
	lootSpecListCache = nil
end
local previous_EJ_SetSlotFilter = EJ_SetSlotFilter
function EJ_SetSlotFilter(tier)
	setNeedsUpdate()
	previous_EJ_SetSlotFilter(tier)
end
local previous_EJ_SelectTier = EJ_SelectTier
function EJ_SelectTier(tier)
	setNeedsUpdate()
	previous_EJ_SelectTier(tier)
end
local previous_EJ_SetDifficulty = EJ_SetDifficulty
function EJ_SetDifficulty(difficulty)
	setNeedsUpdate()
	previous_EJ_SetDifficulty(difficulty)
end
local previous_EJ_SetLootFilter = EJ_SetLootFilter
function EJ_SetLootFilter(classID, specID)
	--print("EJ_SetLootFilter hook", classID, specID)
	--local a = nil a[1] = 2
	setNeedsUpdate()
	previous_EJ_SetLootFilter(classID, specID)
end
local previous_EJ_SelectEncounter = EJ_SelectEncounter
function EJ_SelectEncounter(encounterID)
	setNeedsUpdate()
	previous_EJ_SelectEncounter(encounterID)
end
local previous_EJ_SelectInstance = EJ_SelectInstance
function EJ_SelectInstance(instanceID)
	setNeedsUpdate()
	previous_EJ_SelectInstance(instanceID)
end

local function attachLootSpecSwapButtons()
	local baseNameSpecChooseButton = "mylootspecchoiceshowingbutton"
	local lastButton = nil
	local desiredLootSpec = GetLootSpecialization() -- TODO
	for i=1,GetNumSpecializations() do
		local frameName = baseNameSpecChooseButton..i
		local frame = _G[frameName]
		local specID,_,_,icon,_,_ = GetSpecializationInfo(i)
		if not frame then
			frame = CreateFrame("BUTTON", frameName, EncounterJournal) -- TODO
			frame:SetSize(40, 40)
		end
		if lastButton then
			frame:SetPoint("BOTTOMRIGHT", lastButton, "TOPRIGHT")
		else
			frame:SetPoint("BOTTOMLEFT", EncounterJournal, "BOTTOMRIGHT") -- TODO
		end
		if not frame.texture then frame.texture = frame:CreateTexture() end
		frame.texture:SetAllPoints(frame)
		frame.texture:SetTexture(icon)
		if specID == desiredLootSpec then
			frame.texture:SetDesaturated(false)
		else
			frame.texture:SetDesaturated(true)
		end
		frame:SetScript("OnClick", function()
			SetLootSpecialization(specID)
		end)
		lastButton = frame
	end

	-- TODO move.
		local frameName = "transmogbutton"..1
		local frame = _G[frameName]
		local specID,_,_,icon,_,_ = GetSpecializationInfo(1)
		if not frame then
			frame = CreateFrame("BUTTON", frameName, EncounterJournal) -- TODO
			frame:SetSize(40, 40)
		end
		if lastButton then
			frame:SetPoint("BOTTOMRIGHT", lastButton, "TOPRIGHT")
		else
			frame:SetPoint("BOTTOMLEFT", EncounterJournal, "BOTTOMRIGHT") -- TODO
		end
		if not frame.texture then frame.texture = frame:CreateTexture() end
		frame.texture:SetAllPoints(frame)
		frame.texture:SetTexture(icon)
		if transmogFilterEnabled() then
			frame.texture:SetDesaturated(false)
		else
			frame.texture:SetDesaturated(true)
		end
		frame:SetScript("OnClick", function()
			toggleTransmogFilter()
		end)
		lastButton = frame
end

-- TODO Tooltips.
local function updateEncounterJournalLootSpecButtons()
	attachLootSpecSwapButtons()
end

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

-- returns the class that loot spec icons are being shown/should be shown for.
local function getSpecIconClassID()
	local currentClassFilter = EJ_GetLootFilter()
	if currentClassFilter == 0 then -- if no class is selected, use player's class for icons (although items for all classes will be shown in the list).
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

		previous_EJ_SetLootFilter(classID, specID)
		for j=1,EJ_GetNumLoot() do
			local itemID = EJ_GetLootInfoByIndex(j)

			if not loots[itemID] then loots[itemID] = {} end
			loots[itemID][specID] = true
		end
	end
	lootSpecListCache = loots

	previous_EJ_SetLootFilter(previousClassFilter, previousSpecFilter)
	return lootSpecListCache
end

local function updateEncounterJournalLootSpecItems()
	if not EncounterJournalEncounterFrameInfoLootScrollFrame or not EncounterJournalEncounterFrameInfoLootScrollFrame:IsShown() then return end
	local SPECICONFRAMENAME = "MyLootSpecIcons"

	local loots = getSpecLootInfo()

	for i=1,EJ_GetNumLoot() do
		local lootFrame = _G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i]
		if not lootFrame then break end

		local previousSpecFrame = nil
		local specIconCount = 1
		if loots[lootFrame.itemID] then
			for lootSpecID,forThisLootSpec in pairs(loots[lootFrame.itemID]) do
				local iconFrameName = SPECICONFRAMENAME..i.."_"..specIconCount
				if forThisLootSpec then
					local specFrame = _G[iconFrameName]
					if not specFrame then
						specFrame = CreateFrame("FRAME", iconFrameName, lootFrame)
						specFrame:SetSize(20, 20)
						specFrame.texture = specFrame:CreateTexture()
					end
					specFrame:Show()

					if not previousSpecFrame then
						specFrame:SetPoint("BOTTOMRIGHT", lootFrame, "BOTTOMRIGHT", 0, 3)
					else
						specFrame:SetPoint("TOPRIGHT", previousSpecFrame, "TOPLEFT")
					end

					local _,_,_,icon = GetSpecializationInfoByID(lootSpecID);
					specFrame.texture:SetAllPoints(specFrame)
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
		for j=specIconCount,#specIDs[getSpecIconClassID()] do
			local specFrame = _G[SPECICONFRAMENAME..i.."_"..j]
			if specFrame then specFrame:Hide() end
		end
	end
end

do
	local init
	hooksecurefunc(_G, "EncounterJournal_LoadUI", function()
		if not init then
			EncounterJournal:HookScript("OnUpdate", updateEncounterJournalLootSpecItems)
			EncounterJournal:HookScript("OnUpdate", updateEncounterJournalLootSpecButtons)
			init = true
		end
	end)
end

-- Loot list filtering --
local ejFilterPredicate = nil
--local ejLootListSortComparator = nil -- XXX unused, unimplemented.

do
	local previous_EJ_GetLootInfoByIndex = EJ_GetLootInfoByIndex
	local previous_EJ_GetNumLoot = EJ_GetNumLoot
	local function makeSureLootListIsFiltered()
		if filteredLootList then return end
		filteredLootList = {}

		for i=1,previous_EJ_GetNumLoot() do
			local itemInfo = {previous_EJ_GetLootInfoByIndex(i)}
			if ejFilterPredicate(unpack(itemInfo)) then
				filteredLootList[#filteredLootList+1] = itemInfo
			end
		end
	end

	function EJ_GetNumLoot()
		if not ejFilterPredicate then return previous_EJ_GetNumLoot() end
		makeSureLootListIsFiltered()

		return #filteredLootList
	end

	function EJ_GetLootInfoByIndex(index)
		if not ejFilterPredicate then return previous_EJ_GetLootInfoByIndex(index) end
		makeSureLootListIsFiltered()

		return unpack(filteredLootList[index])
	end
end

-- Xmog filter --
local function canBeXmoggedByCharacter(itemID, encounterID, name, icon, slot, armorType, itemLink)
	local text = CanIMogIt:GetTooltipText(itemLink)
	if text == nil or name == nil then return true end

	return text:find("Not learned.")
end

local function canBeXmogged(itemID, encounterID, name, icon, slot, armorType, itemLink)
	local text = CanIMogIt:GetTooltipText(itemLink)
	if text == nil or name == nil then return true end

	if text:find(CanIMogIt.L["Cannot learn: Soulbound"]) then return true end
	if text:find("Not learned.") then return true end
end

SLASH_TOGGLEENCOUNTERJOURNALTRANSMOGFILTER1 = "/ttf"
SlashCmdList["TOGGLEENCOUNTERJOURNALTRANSMOGFILTER"] = function () toggleTransmogFilter() end
local nonXmogClassFilter, nonXmogSpecFilter
function toggleTransmogFilter()
	if ejFilterPredicate == canBeXmoggedByCharacter then
		ejFilterPredicate = canBeXmogged
		print("Transmog filter enabled (transmog any)")
	elseif ejFilterPredicate == canBeXmogged then
		ejFilterPredicate = nil
		local class, spec = EJ_GetLootFilter()
		if nonXmogClassFilter and class == 0 and spec == 0 then EJ_SetLootFilter(nonXmogClassFilter, nonXmogSpecFilter) end
		print("Transmog filter disabled")
	else
		ejFilterPredicate = canBeXmoggedByCharacter
		nonXmogClassFilter, nonXmogSpecFilter = EJ_GetLootFilter()
		previous_EJ_SetLootFilter(0, 0)
		print("Transmog filter enabled (transmog you)")
	end
	filteredLootList = nil
	EncounterJournal_OnFilterChanged()
end

function transmogFilterEnabled()
	return ejFilterPredicate ~= nil
end

-- Disable bonus roll button opening of encounterjournal from setting spec filter.
do
	local previous_OpenBonusRollEncounterJournalLink = OpenBonusRollEncounterJournalLink
	function OpenBonusRollEncounterJournalLink()
		local prev = EJ_SetLootFilter
		local currentClass,currentSpec = EJ_GetLootFilter()
		EJ_SetLootFilter = function(class, spec)
			if currentClass == class then
				prev(class, currentSpec)
			else
				prev(class, 0)
			end
		end
		previous_OpenBonusRollEncounterJournalLink()
		EJ_SetLootFilter = prev
	end
end

