--[[
RatingBuster StatLogic - Classic/Ascension Edition
Embedded StatLogic implementation specifically tuned for Classic WoW mechanics
Replaces external LibStatLogic dependency for better compatibility and control
]]

-- Force create StatLogic namespace (overwrites any existing one)
StatLogic = StatLogic or {}

-- Ensure we have a clean StatLogic table for RatingBuster
local RBStatLogic = StatLogic

-- Debug: Confirm StatLogic is loaded
print("RatingBuster: StatLogic loaded successfully")

local scanTooltip = CreateFrame("GameTooltip", "RBStatLogicScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

--=====================================--
-- Rating Conversions                  --
--=====================================--

function StatLogic:GetEffectFromRating(rating, ratingType, level)
	if not rating or not ratingType then return 0 end
	
	local ratingPerPercent = {
		-- Rating conversions for Classic/TBC (level 70 values)
		-- These are the main ratings that existed in Classic/TBC:
		[8] = 22.08,   -- CR_CRIT_MELEE (Classic values)
		[9] = 22.08,   -- CR_CRIT_RANGED  
		[11] = 22.08,  -- CR_CRIT_SPELL
		[12] = 15.77,  -- CR_HIT_MELEE
		[13] = 15.77,  -- CR_HIT_RANGED
		[14] = 12.62,  -- CR_HIT_SPELL
		[15] = 25.0,   -- CR_RESILIENCE_CRIT_TAKEN
		[16] = 25.0,   -- CR_RESILIENCE_PLAYER_DAMAGE_TAKEN
		[17] = 25.0,   -- CR_CRIT_TAKEN_SPELL
		-- Note: Haste rating didn't exist in Classic, was added in TBC
		[18] = 15.77,  -- CR_HASTE_MELEE (if it exists)
		[19] = 15.77,  -- CR_HASTE_RANGED
		[20] = 15.77,  -- CR_HASTE_SPELL
		-- Expertise was added in TBC
		[24] = 15.77,  -- CR_EXPERTISE (if it exists)
	}
	
	local divisor = ratingPerPercent[ratingType]
	if not divisor then
		-- For unknown rating types, return 0 (might not exist in Classic)
		return 0
	end
	
	return rating / divisor
end

--=====================================--
-- Stat Conversions                    --
--=====================================--

function StatLogic:GetAPPerStr(class)
	-- Attack power per strength by class
	if class == "PALADIN" or class == "WARRIOR" or class == "DEATHKNIGHT" then
		return 2
	else
		return 1
	end
end

function StatLogic:GetAPPerAgi(class)
	-- Melee attack power per agility by class
	-- In Classic, most classes don't get melee AP from agility
	if class == "HUNTER" then
		return 1  -- Hunters get 1 melee AP per agility
	elseif class == "ROGUE" then
		return 1  -- Rogues get 1 melee AP per agility
	elseif class == "SHAMAN" then
		return 1  -- Enhancement shamans get 1 melee AP per agility  
	else
		return 0  -- Other classes get no melee AP from agility
	end
end

function StatLogic:GetRAPPerAgi(class)
	-- Ranged attack power per agility (for hunters mainly)
	if class == "HUNTER" then
		return 2
	elseif class == "ROGUE" or class == "WARRIOR" then
		return 1
	else
		return 0
	end
end

function StatLogic:GetBlockValuePerStr(class)
	-- Block value per strength (Warriors and Paladins only)
	if class == "WARRIOR" or class == "PALADIN" then
		return 0.5
	end
	return 0
end

--=====================================--
-- Secondary Stats from Primary Stats  --
--=====================================--

function StatLogic:GetDodgeFromAgi(agi, class, level)
	-- Classic dodge calculation from agility
	-- Classic values are much lower than WotLK
	local dodgePerAgi = {
		["WARRIOR"] = 0.02,    -- Classic: ~50 agility per 1% dodge
		["PALADIN"] = 0.02,
		["HUNTER"] = 0.025,    -- Hunters get slightly more
		["ROGUE"] = 0.025,     -- Rogues get slightly more
		["PRIEST"] = 0.015,    -- Casters get less
		["SHAMAN"] = 0.02,
		["MAGE"] = 0.015,      -- Casters get less
		["WARLOCK"] = 0.015,   -- Casters get less
		["DRUID"] = 0.02,
		["DEATHKNIGHT"] = 0.02,
	}
	
	local playerClass = select(2, UnitClass("player"))
	local ratio = dodgePerAgi[playerClass] or 0.02
	return (agi or 0) * ratio
end

function StatLogic:GetCritFromAgi(agi, class, level)
	-- Classic crit calculation from agility  
	-- Classic values are much lower than WotLK
	local critPerAgi = {
		["WARRIOR"] = 0.02,    -- Classic: ~50 agility per 1% crit
		["PALADIN"] = 0.02,
		["HUNTER"] = 0.025,    -- Hunters get more from agility
		["ROGUE"] = 0.025,     -- Rogues get more from agility
		["PRIEST"] = 0.015,    -- Casters get less
		["SHAMAN"] = 0.02,
		["MAGE"] = 0.015,      -- Casters get less
		["WARLOCK"] = 0.015,   -- Casters get less
		["DRUID"] = 0.02,      -- Variable based on form, using average
		["DEATHKNIGHT"] = 0.02,
	}
	
	local playerClass = select(2, UnitClass("player"))
	local ratio = critPerAgi[playerClass] or 0.02
	return (agi or 0) * ratio
end

function StatLogic:GetSpellCritFromInt(int, class, level)
	-- Classic spell crit calculation from intellect
	-- In Classic, spell crit from intellect is much lower than WotLK
	-- Based on observed data: 6 int = 0.20% crit, so ratio is about 0.033% per int
	local spellCritPerInt = {
		["WARRIOR"] = 0,
		["PALADIN"] = 0.033,   -- Classic values are much lower than WotLK
		["HUNTER"] = 0.033,
		["ROGUE"] = 0,
		["PRIEST"] = 0.033,   -- About 30 int per 1% spell crit in Classic
		["SHAMAN"] = 0.033,
		["MAGE"] = 0.033,
		["WARLOCK"] = 0.033,
		["DRUID"] = 0.033,
		["DEATHKNIGHT"] = 0,
	}
	
	local playerClass = select(2, UnitClass("player"))
	local ratio = spellCritPerInt[playerClass] or 0.033
	return (int or 0) * ratio
end

--=====================================--
-- Regeneration                        --
--=====================================--

function StatLogic:GetNormalManaRegenFromSpi(spi, int, level)
	-- Classic mana regen calculation from spirit
	-- In Classic, spirit provides significant mana regeneration
	-- Base formula: (Spirit / 4 + 12.5) per 5 seconds when not casting
	-- Simplified: roughly 0.5 MP5 per spirit point
	return (spi or 0) * 0.5 -- Classic: ~0.5 MP5 per spirit
end

function StatLogic:GetHealthRegenFromSpi(spi, class)
	-- Classic health regen calculation from spirit  
	-- In Classic, spirit gives health regen: roughly 0.25 HP5 per spirit
	return (spi or 0) * 0.25 -- Classic: ~0.25 HP5 per spirit
end

--=====================================--
-- Stat Modifiers (Classic Mechanics)  --
--=====================================--

function StatLogic:GetStatMod(stat, school, talentGroup)
	-- Classic mechanics - no spell damage/healing from stat conversions for most cases
	-- Return 0 for WotLK-specific stat conversions that don't exist in Classic
	
	-- Spell damage modifiers (WotLK only)
	if stat == "ADD_SPELL_DMG_MOD_AP" then
		return 0  -- No spell damage from attack power in Classic
	elseif stat == "ADD_SPELL_DMG_MOD_STA" then
		return 0  -- No spell damage from stamina in Classic
	elseif stat == "ADD_SPELL_DMG_MOD_INT" then
		return 0  -- No spell damage from intellect in Classic - INT only gives mana
	elseif stat == "ADD_SPELL_DMG_MOD_STR" then
		return 0  -- No spell damage from strength in Classic
	elseif stat == "ADD_SPELL_DMG_MOD_SPI" then
		return 0  -- No spell damage from spirit in Classic
	elseif stat == "ADD_SPELL_DMG_MOD_PET_STA" then
		return 0  -- No spell damage from pet stamina in Classic
	
	-- Healing modifiers (WotLK only)
	elseif stat == "ADD_HEAL_MOD_AP" then
		return 0  -- No healing from attack power in Classic
	elseif stat == "ADD_HEAL_MOD_STR" then
		return 0  -- No healing from strength in Classic
	elseif stat == "ADD_HEAL_MOD_AGI" then
		return 0  -- No healing from agility in Classic
	elseif stat == "ADD_HEAL_MOD_INT" then
		return 0  -- No healing from intellect in Classic - INT only gives mana
	elseif stat == "ADD_HEAL_MOD_SPI" then
		return 0  -- No healing from spirit in Classic
	
	-- Pet stat modifiers (WotLK only)
	elseif stat == "ADD_PET_STA_MOD_STA" then
		return 0  -- Pet stat scaling didn't work this way in Classic
	
	-- Rating modifiers (some didn't exist in Classic)
	elseif stat == "ADD_PARRY_RATING_MOD_STR" then
		return 0  -- Parry rating didn't exist in Classic
	end
	
	-- For other stat modifiers, return neutral
	return 1
end

--=====================================--
-- Tooltip Processing                  --
--=====================================--

function StatLogic:GetDiffID(tooltip, ignoreEnchant, ignoreGems, red, yellow, blue, meta, ignorePris)
	local name, link = nil, nil
	
	-- Try different ways to get the item link
	if type(tooltip) == "string" then
		-- If tooltip is actually a link string
		link = tooltip
	elseif tooltip and tooltip.GetItem then
		-- If tooltip has GetItem method
		name, link = tooltip:GetItem()
	elseif tooltip and tooltip.GetName then
		-- Try to get name and construct from that
		name = tooltip:GetName()
		if name and type(name) == "string" then
			-- This is a fallback, won't work perfectly but prevents errors
			link = name
		end
	end
	
	if not link then
		return nil, nil, nil, nil
	end
	
	-- Extract item ID from the link if it's a proper item link
	local itemID = nil
	if link:match("item:") then
		itemID = link:match("item:(%d+)")
	end
	
	-- Return basic diff ID info
	return link, link, "NOITEM", nil
end

function StatLogic:GetSum(link, targetTable)
	if not link then
		return targetTable or {}
	end
	
	if not targetTable then
		targetTable = {}
	end
	
	-- Get item information
	local name, itemLink, quality, iLevel, reqLevel, class, subclass, maxStack, equipLoc, texture = GetItemInfo(link)
	if not name then
		return targetTable
	end
	
	-- Clear and set the tooltip
	scanTooltip:ClearLines()
	scanTooltip:SetHyperlink(link)
	
	-- Parse tooltip lines for stats
	local statPatterns = {
		["+(%d+) Strength"] = "STR",
		["+(%d+) Agility"] = "AGI", 
		["+(%d+) Stamina"] = "STA",
		["+(%d+) Intellect"] = "INT",
		["+(%d+) Spirit"] = "SPI",
		["Equip: Improves critical strike rating by (%d+)"] = "CRIT_RATING",
		["Equip: Improves hit rating by (%d+)"] = "HIT_RATING",
		["Equip: Improves haste rating by (%d+)"] = "HASTE_RATING",
		["Equip: Increases attack power by (%d+)"] = "AP",
		["Equip: Increases spell power by (%d+)"] = "SPELL_POWER",
		["+(%d+) Attack Power"] = "AP",
		["+(%d+) Spell Power"] = "SPELL_POWER",
	}
	
	-- Scan tooltip lines
	for i = 1, scanTooltip:NumLines() do
		local line = _G["RBStatLogicScanTooltipTextLeft" .. i]
		if line then
			local text = line:GetText()
			if text then
				-- Try to match stat patterns
				for pattern, statID in pairs(statPatterns) do
					local value = text:match(pattern)
					if value then
						targetTable[statID] = (targetTable[statID] or 0) + tonumber(value)
					end
				end
			end
		end
	end
	
	-- Store item type for equipment slot detection
	targetTable.itemType = equipLoc
	
	return targetTable
end

function StatLogic:GetDiff(item, diff1, diff2, ignoreEnchant, ignoreGem, red, yellow, blue, meta, ignorePris)
	-- Check if item link exists
	local link = nil
	if type(item) == "string" then
		link = item
	elseif item and item.GetItem then
		_, link = item:GetItem()
	end
	
	if not link then
		return nil
	end
	
	-- Simple diff implementation - just return empty stat tables for now
	-- This prevents the error while keeping the addon functional
	if not diff1 then
		diff1 = {}
	end
	if not diff2 then
		diff2 = {}
	end
	
	-- Clear the tables
	for k in pairs(diff1) do
		diff1[k] = nil
	end
	for k in pairs(diff2) do
		diff2[k] = nil
	end
	
	-- Return empty diff tables to prevent errors
	-- The actual comparison logic would be more complex in a full implementation
	return diff1, diff2
end

--=====================================--
-- Utility Functions                   --
--=====================================--

function StatLogic:GetGemID(value)
	-- Simple gem ID extraction - placeholder implementation
	if type(value) == "string" and value:match("item:") then
		return value:match("item:(%d+)")
	end
	return nil
end

--=====================================--
-- Avoidance Diminishing Returns       --
--=====================================--

function StatLogic:GetAvoidanceGainAfterDR(avoidanceType, currentValue)
	-- Classic WoW diminishing returns for avoidance
	-- In Classic, diminishing returns are much simpler than later expansions
	
	if not currentValue or currentValue < 0 then
		return 0
	end
	
	-- Classic diminishing returns formulas (simplified)
	if avoidanceType == "DODGE" then
		-- Classic dodge DR: much more linear than later expansions
		-- Cap around 50-60% for most classes
		if currentValue > 50 then
			return currentValue * 0.85  -- Soft cap reduction
		else
			return currentValue
		end
	elseif avoidanceType == "PARRY" then
		-- Classic parry DR: similar to dodge
		if currentValue > 45 then
			return currentValue * 0.90  -- Slightly less harsh than dodge
		else
			return currentValue
		end
	elseif avoidanceType == "BLOCK" then
		-- Block chance doesn't have as severe DR in Classic
		if currentValue > 70 then
			return currentValue * 0.95
		else
			return currentValue
		end
	end
	
	-- Default: no DR applied
	return currentValue
end

--=====================================--
-- Item Link Manipulation             --
--=====================================--

function StatLogic:RemoveEnchant(link)
	-- Remove enchant from item link
	-- Item link format: |cffffffff|Hitem:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:level|h[name]|h|r
	if not link or type(link) ~= "string" then
		return link
	end
	
	-- Match the item link pattern and remove enchant (second field)
	local itemString = link:match("|H(item:[^|]+)|h")
	if itemString then
		local parts = {strsplit(":", itemString)}
		if #parts >= 2 then
			parts[2] = "0" -- Set enchant to 0 (no enchant)
			local newItemString = strjoin(":", unpack(parts))
			return link:gsub("|H(item:[^|]+)|h", "|H" .. newItemString .. "|h")
		end
	end
	
	return link
end

function StatLogic:RemoveGem(link)
	-- Remove all gems from item link
	if not link or type(link) ~= "string" then
		return link
	end
	
	-- Match the item link pattern and remove gems (fields 3-6)
	local itemString = link:match("|H(item:[^|]+)|h")
	if itemString then
		local parts = {strsplit(":", itemString)}
		if #parts >= 6 then
			parts[3] = "0" -- gem1
			parts[4] = "0" -- gem2
			parts[5] = "0" -- gem3
			parts[6] = "0" -- gem4
			local newItemString = strjoin(":", unpack(parts))
			return link:gsub("|H(item:[^|]+)|h", "|H" .. newItemString .. "|h")
		end
	end
	
	return link
end

function StatLogic:RemoveExtraSocketGem(link)
	-- Remove extra socket gems (prismatic gems in non-matching slots)
	-- For Classic, this is mostly a placeholder since prismatic gems are rare
	if not link or type(link) ~= "string" then
		return link
	end
	
	-- In Classic, prismatic sockets don't exist the same way as later expansions
	-- This function mostly just removes meta gems that don't belong
	local itemString = link:match("|H(item:[^|]+)|h")
	if itemString then
		local parts = {strsplit(":", itemString)}
		if #parts >= 6 then
		-- For Classic compatibility, just ensure meta gem (slot 4) is appropriate
		-- This is a simplified implementation
		if parts[6] and parts[6] ~= "0" then
			-- Remove meta gem if it seems inappropriate (basic check)
			parts[6] = "0"
		end
		local newItemString = strjoin(":", unpack(parts))
		return link:gsub("|H(item:[^|]+)|h", "|H" .. newItemString .. "|h")
	end
end

return link
end

function StatLogic:BuildGemmedTooltip(link, red, yellow, blue, meta)
	-- Build item link with specified gems
	if not link or type(link) ~= "string" then
		return link
	end
	
	-- Match the item link pattern and set gems
	local itemString = link:match("|H(item:[^|]+)|h")
	if itemString then
		local parts = {strsplit(":", itemString)}
		if #parts >= 6 then
			-- Set gems if provided (0 means no gem)
			if red and red > 0 then parts[3] = tostring(red) end
			if yellow and yellow > 0 then parts[4] = tostring(yellow) end
			if blue and blue > 0 then parts[5] = tostring(blue) end
			if meta and meta > 0 then parts[6] = tostring(meta) end
			
			local newItemString = strjoin(":", unpack(parts))
			return link:gsub("|H(item:[^|]+)|h", "|H" .. newItemString .. "|h")
		end
	end
	
	return link
end