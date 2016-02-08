--[[--------------------------------------------------------------------
	oUF_Drak
	oUF-based Combat HUD for PvE.
	Copyright (c) 2016 Drak <drak@derpydo.com>. All rights reserved.
	https://github.com/Drak1814/oUF_Drak
----------------------------------------------------------------------
	Element to display AFK times on oUF frames.
	Based on code from oUF_Smurf by Merl@chainweb.net.
	Written and distributed with permission.

	Minimal usage:
	frame.AFK = frame:CreateFontString(nil, "OVERLAY")
	frame.AFK:SetPoint("CENTER")
----------------------------------------------------------------------]]

local _, ns = ...

local times = {}
local elements = {}

local updater = CreateFrame("Frame")
updater:Hide()

local lastUpdate = 0
local floor, mod, next, pairs, GetTime = floor, mod, next, pairs, GetTime
updater:SetScript("OnUpdate", function(self, elapsed)
	lastUpdate = lastUpdate + elapsed
	if lastUpdate > 0.2 then
		lastUpdate = 0
		if not next(times) then
			self:Hide()
		end
		for element, unit in pairs(elements) do
			local t = times[unit]
			if t then
				t = GetTime() - t
				element:SetFormattedText("AFK %d:%02.0f", floor(t / 60), mod(t, 60))
			else
				elements[element] = nil
				element:SetText("") -- nil gives it 0 height which might disturb the layout
			end
		end
	end
end)

local function Update(self, event, unit)
	if unit ~= self.unit then return end

	local element = self.AFK
	local afk = UnitIsAFK(unit)
	--print("AFK", event, unit, afk, times[unit])

	if afk and not times[unit] then
		times[unit] = GetTime()
		elements[element] = unit
		updater:Show()
	elseif times[unit] and not afk then
		times[unit] = nil
		element:SetText("")
	end
end

local ForceUpdate = function(element)
	return Update(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self)
	local element = self.AFK
	if not element then return end

	element.__owner = self
	element.ForceUpdate = Update

	if not element:GetFont() then
		element:SetFontObject("GameFontHighlightSmall")
	end

	self:RegisterEvent("PLAYER_FLAGS_CHANGED", Update)
	return true
end

local function Disable(self)
	local element = self.AFK
	if not element then return end

	self:UnregisterEvent("PLAYER_FLAGS_CHANGED", Update)
	element:Hide()
end

dUF:AddElement("AFK", Update, Enable, Disable)