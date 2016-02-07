--[[--------------------------------------------------------------------
	oUF_Drak
	oUF-based Combat HUD for PvE.
	Copyright (c) 2016 Drak <drak@derpydo.com>. All rights reserved.
	https://github.com/Drak1814/oUF_Drak
----------------------------------------------------------------------]]

if select(2, UnitClass("player")) ~= "DRUID" then return end

dUF.colors.power.ECLIPSE_LUNAR = { 0, 0.6, 1 }
dUF.colors.power.ECLIPSE_SOLAR = { 0.8, 0.5, 0 }

local _, ns = ...
local EclipseBar

local ECLIPSE_MARKER_COORDS = ECLIPSE_MARKER_COORDS
local SPELL_POWER_ECLIPSE = SPELL_POWER_ECLIPSE

local LUNAR_COLOR = dUF.colors.power.ECLIPSE_LUNAR
local SOLAR_COLOR = dUF.colors.power.ECLIPSE_SOLAR

local BRIGHT = 1.2
local NORMAL = 0.8
local DIMMED = 0.5

local function PostUpdateVisibility(self, unit)
	--ChatFrame3:AddMessage(strjoin(" ", "|cffff7f4foUF_Drak:|r", tostringall("EclipseBar PostUpdateVisibility", self:IsShown())))
	self.isHidden = not self:IsShown()
	self:PostUnitAura(unit)
end

local function PostUpdatePower(self, unit, power, maxPower)
	if not power or self.isHidden then return end
	--ChatFrame3:AddMessage(strjoin(" ", "|cffff7f4foUF_Drak:|r", tostringall("EclipseBar PostUpdatePower", power, maxPower)))
	local x = (power / maxPower) * (self:GetWidth() / 2)
	self.lunarBG:SetPoint("RIGHT", self, "CENTER", x, 0)
end

local function PostUnitAura(self, unit)
	if self.isHidden then return end
	local hasLunarEclipse, hasSolarEclipse = self.hasLunarEclipse, self.hasSolarEclipse
	--ChatFrame3:AddMessage(strjoin(" ", "|cffff7f4foUF_Drak:|r", tostringall("EclipseBar PostUnitAura", hasLunarEclipse, hasSolarEclipse)))

	if hasLunarEclipse then
		self.lunarBG:SetVertexColor(LUNAR_COLOR[1] * DIMMED, LUNAR_COLOR[2] * DIMMED, LUNAR_COLOR[3] * DIMMED)
		self.solarBG:SetVertexColor(LUNAR_COLOR[1] * BRIGHT, LUNAR_COLOR[2] * BRIGHT, LUNAR_COLOR[3] * BRIGHT)
	elseif hasSolarEclipse then
		self.lunarBG:SetVertexColor(SOLAR_COLOR[1] * BRIGHT, SOLAR_COLOR[2] * BRIGHT, SOLAR_COLOR[3] * BRIGHT)
		self.solarBG:SetVertexColor(SOLAR_COLOR[1] * DIMMED, SOLAR_COLOR[2] * DIMMED, SOLAR_COLOR[3] * DIMMED)
	else
		self.lunarBG:SetVertexColor(LUNAR_COLOR[1] * NORMAL, LUNAR_COLOR[2] * NORMAL, LUNAR_COLOR[3] * NORMAL)
		self.solarBG:SetVertexColor(SOLAR_COLOR[1] * NORMAL, SOLAR_COLOR[2] * NORMAL, SOLAR_COLOR[3] * NORMAL)
	end
end

local function PostDirectionChange(self, unit)
	if self.isHidden then return end
	local direction = GetEclipseDirection()
	--ChatFrame3:AddMessage(strjoin(" ", "|cffff7f4foUF_Drak:|r", tostringall("EclipseBar PostDirectionChanged", direction)))

	local coords = ECLIPSE_MARKER_COORDS[direction]
	self.directionArrow:SetTexCoord(coords[1], coords[2], coords[3], coords[4])

	if direction == "moon" then
		self.directionArrow:SetPoint("CENTER", self.lunarBG, "RIGHT", 1, 1)
	elseif direction == "sun" then
		self.directionArrow:SetPoint("CENTER", self.lunarBG, "RIGHT", -1, 1)
	else
		self.directionArrow:SetPoint("CENTER", self.lunarBG, "RIGHT", 0, 1)
	end
end

function ns.CreateEclipseBar(self)
	if EclipseBar then
		return EclipseBar
	end

	EclipseBar = CreateFrame("Frame", nil, self)
	EclipseBar:Hide()

	EclipseBar:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 0)
	EclipseBar:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 0)
	EclipseBar:SetHeight(self:GetHeight() * ns.config.powerHeight + 1)

	local texture = self.Health:GetStatusBarTexture():GetTexture()

	local bg = EclipseBar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(true)
	bg:SetTexture(texture)
	bg:SetVertexColor(0, 0, 0, 1)
	tinsert(ns.statusbars, bg)
	EclipseBar.bg = bg

	local lunarBG = EclipseBar:CreateTexture(nil, "BACKGROUND", nil, 1)
	lunarBG:SetPoint("TOPLEFT", EclipseBar, 1, -1)
	lunarBG:SetPoint("BOTTOMLEFT", EclipseBar, 1, 0)
	lunarBG:SetPoint("RIGHT", EclipseBar, "CENTER")
	lunarBG:SetTexture(texture)
	tinsert(ns.statusbars, lunarBG)
	EclipseBar.lunarBG = lunarBG

	local solarBG = EclipseBar:CreateTexture(nil, "BACKGROUND", nil, 1)
	solarBG:SetPoint("TOPRIGHT", EclipseBar, 1, 1)
	solarBG:SetPoint("BOTTOMRIGHT", EclipseBar, 1, 0)
	solarBG:SetPoint("LEFT", lunarBG, "RIGHT")
	solarBG:SetTexture(texture)
	tinsert(ns.statusbars, solarBG)
	EclipseBar.solarBG = solarBG

	local eclipseArrow = EclipseBar:CreateTexture(nil, "OVERLAY")
	eclipseArrow:SetPoint("CENTER", lunarBG, "RIGHT", 0, 1)
	eclipseArrow:SetSize(24, 24)
	eclipseArrow:SetTexture([[Interface\PlayerFrame\UI-DruidEclipse]])
	eclipseArrow:SetBlendMode("ADD")
	EclipseBar.directionArrow = eclipseArrow

	local eclipseText = ns.CreateFontString(EclipseBar, 16, "CENTER")
	eclipseText:SetPoint("CENTER", EclipseBar, "CENTER", 0, 1)
	eclipseText:Hide()
	self:Tag(eclipseText, "[pereclipse]%")
	tinsert(self.mouseovers, eclipseText)
	EclipseBar.value = eclipseText

	EclipseBar:SetScript("OnEnter", ns.UnitFrame_OnEnter)
	EclipseBar:SetScript("OnLeave", ns.UnitFrame_OnLeave)

	EclipseBar.__name = "EclipseBar"
	EclipseBar:Hide()
	EclipseBar:SetScript("OnShow", ns.ExtraBar_OnShow)
	EclipseBar:SetScript("OnHide", ns.ExtraBar_OnHide)
	
	EclipseBar.frequentUpdates = true

	EclipseBar.PostDirectionChange  = PostDirectionChange
	EclipseBar.PostUnitAura         = PostUnitAura
	EclipseBar.PostUpdatePower      = PostUpdatePower
	EclipseBar.PostUpdateVisibility = PostUpdateVisibility

	return EclipseBar
end