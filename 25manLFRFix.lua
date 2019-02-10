local _,private = ...

--[[
No raids show 25man LFR (different from flex LFR), even though they should.
--]]
do
	local shouldHaveRaidFinder = {
		[187]=true,
		[317]=true,
		[330]=true,
		[320]=true,
		[362]=true,
	}
	local previous_EJ_IsValidInstanceDifficulty = EJ_IsValidInstanceDifficulty
	function EJ_IsValidInstanceDifficulty(difficultyID, ...)
		local instanceID = private.currentlyDisplayedInstanceID
		if difficultyID == 7 and instanceID and shouldHaveRaidFinder[instanceID] then
			return true
		end
		return previous_EJ_IsValidInstanceDifficulty(difficultyID, ...)
	end
end

