--[[--------------------------------------------------------------------
	oUF_Drak
	oUF-based Combat HUD for PvE.
	Copyright (c) 2016 Drak <drak@derpydo.com>. All rights reserved.
	https://github.com/Drak1814/oUF_Drak
----------------------------------------------------------------------]]

local _, ns = ...

local GetLootMethod, IsResting, UnitAffectingCombat, UnitBuff, UnitClass, UnitInRaid, UnitIsConnected, UnitIsDeadOrGhost, UnitIsEnemy, UnitIsGroupAssistant, UnitIsGroupLeader, UnitIsPlayer, UnitIsTapped, UnitIsTappedByPlayer, UnitIsUnit, UnitPowerType, UnitReaction = GetLootMethod, IsResting, UnitAffectingCombat, UnitBuff, UnitClass, UnitInRaid, UnitIsConnected, UnitIsDeadOrGhost, UnitIsEnemy, UnitIsGroupAssistant, UnitIsGroupLeader, UnitIsPlayer, UnitIsTapped, UnitIsTappedByPlayer, UnitIsUnit, UnitPowerType, UnitReaction

------------------------------------------------------------------------
--	Colors

dUF.Tags.Events["unitcolor"] = "UNIT_HEALTH UNIT_CLASSIFICATION_CHANGED UNIT_CONNECTION UNIT_FACTION UNIT_REACTION"
dUF.Tags.Methods["unitcolor"] = function(unit)
	local color
	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		color = dUF.colors.disconnected
	elseif UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		color = dUF.colors.class[class]
	elseif UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) and not UnitIsTappedByAllThreatList(unit) then
		color = dUF.colors.tapped
	elseif UnitIsEnemy(unit, "player") then
		color = dUF.colors.reaction[1]
	else
		color = dUF.colors.reaction[UnitReaction(unit, "player") or 5]
	end
	return color and ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255) or "|cffffffff"
end

dUF.Tags.Events["powercolor"] = "UNIT_DISPLAYPOWER"
dUF.Tags.Methods["powercolor"] = function(unit)
	local _, type = UnitPowerType(unit)
	local color = ns.colors.power[type] or ns.colors.power.FUEL
	return format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

------------------------------------------------------------------------
--	Icons

dUF.Tags.Events["combaticon"] = "PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED"
dUF.Tags.SharedEvents["PLAYER_REGEN_DISABLED"] = true
dUF.Tags.SharedEvents["PLAYER_REGEN_ENABLED"] = true
dUF.Tags.Methods["combaticon"] = function(unit)
	if unit == "player" and UnitAffectingCombat("player") then
		return [[|TInterface\CharacterFrame\UI-StateIcon:0:0:0:0:64:64:37:58:5:26|t]]
	end
end

dUF.Tags.Events["leadericon"] = "GROUP_ROSTER_UPDATE"
dUF.Tags.SharedEvents["GROUP_ROSTER_UPDATE"] = true
dUF.Tags.Methods["leadericon"] = function(unit)
	if UnitIsGroupLeader(unit) then
		return [[|TInterface\GroupFrame\UI-Group-LeaderIcon:0|t]]
	elseif UnitInRaid(unit) and UnitIsGroupAssistant(unit) then
		return [[|TInterface\GroupFrame\UI-Group-AssistantIcon:0|t]]
	end
end

dUF.Tags.Events["mastericon"] = "PARTY_LOOT_METHOD_CHANGED GROUP_ROSTER_UPDATE"
dUF.Tags.SharedEvents["PARTY_LOOT_METHOD_CHANGED"] = true
dUF.Tags.SharedEvents["GROUP_ROSTER_UPDATE"] = true
dUF.Tags.Methods["mastericon"] = function(unit)
	local method, pid, rid = GetLootMethod()
	if method ~= "master" then return end
	local munit
	if pid then
		if pid == 0 then
			munit = "player"
		else
			munit = "party" .. pid
		end
	elseif rid then
		munit = "raid" .. rid
	end
	if munit and UnitIsUnit(munit, unit) then
		return [[|TInterface\GroupFrame\UI-Group-MasterLooter:0:0:0:2|t]]
	end
end

dUF.Tags.Events["restingicon"] = "PLAYER_UPDATE_RESTING"
dUF.Tags.SharedEvents["PLAYER_UPDATE_RESTING"] = true
dUF.Tags.Methods["restingicon"] = function(unit)
	if unit == "player" and IsResting() then
		return [[|TInterface\CharacterFrame\UI-StateIcon:0:0:0:-6:64:64:28:6:6:28|t]]
	end
end

dUF.Tags.Methods["battlepeticon"] = function(unit)
	if UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit) then
		local petType = UnitBattlePetType(unit)
		return [[|TInterface\TargetingFrame\PetBadge-]] .. PET_TYPE_SUFFIX[petType]
	end
end

------------------------------------------------------------------------
--	Threat

do
	local colors = {
		[0] = "|cffffffff",
		[1] = "|cffffff33",
		[2] = "|cffff9933",
		[3] = "|cffff3333",
	}
	dUF.Tags.Events["threatpct"] = "UNIT_THREAT_LIST_UPDATE"
	dUF.Tags.Methods["threatpct"] = function(unit)
		local isTanking, status, percentage, rawPercentage = UnitDetailedThreatSituation("player", unit)
		local pct = rawPercentage
		if isTanking then
			pct = UnitThreatPercentageOfLead("player", unit)
		end
		if pct and pct > 0 and pct < 300 then
			return format("%s%d%%", colors[status] or colors[0], pct + 0.5)
		end
	end
end

------------------------------------------------------------------------
--	Buffs

do
	local EVANGELISM = GetSpellInfo(81661) -- 81660 for rank 1
	local DARK_EVANGELISM = GetSpellInfo(87118) -- 87117 for rank 1
	dUF.Tags.Events["evangelism"] = "UNIT_AURA"
	dUF.Tags.Methods["evangelism"] = function(unit)
		if unit == "player" then
			local name, _, icon, count = UnitBuff("player", EVANGELISM)
			if name then return count end

			name, _, icon, count = UnitBuff("player", DARK_EVANGELISM)
			return name and count
		end
	end
end

do
	local MAELSTROM_WEAPON = GetSpellInfo(53817)
	dUF.Tags.Events["maelstrom"] = "UNIT_AURA"
	dUF.Tags.Methods["maelstrom"] = function(unit)
		if unit == "player" then
			local name, _, icon, count = UnitBuff("player", MAELSTROM_WEAPON)
			return name and count
		end
	end
end

do
	local EARTH_SHIELD = GetSpellInfo(974)
	local LIGHTNING_SHIELD = GetSpellInfo(324)
	local WATER_SHIELD = GetSpellInfo(52127)

	local EARTH_TEXT = setmetatable({}, { __index = function(t,i)
		return format("|cffa7c466%d|r", i)
	end })
	local LIGHTNING_TEXT = setmetatable({}, { __index = function(t,i)
		return format("|cff7f97f7%d|r", i)
	end })
	local WATER_TEXT = setmetatable({}, { __index = function(t,i)
		return format("|cff7cbdff%d|r", i)
	end })

	dUF.Tags.Events["elementalshield"] = "UNIT_AURA"
	dUF.Tags.Methods["elementalshield"] = function(unit)
		local name, _, icon, count = UnitBuff(unit, EARTH_SHIELD, nil, "PLAYER")
		if name then
			return EARTH_TEXT[count]
		end
		if unit == "player" then
			name, _, icon, count = UnitBuff(unit, LIGHTNING_SHIELD)
			if name then
				return LIGHTNING_TEXT[count]
			end
			name, _, icon, count = UnitBuff(unit, WATER_SHIELD)
			if name then
				return WATER_TEXT[count]
			end
		end
	end
end