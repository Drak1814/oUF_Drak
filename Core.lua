--[[--------------------------------------------------------------------
	oUF_Drak
	oUF-based Combat HUD for PvE.
	Copyright (c) 2016 Drak <drak@derpydo.com>. All rights reserved.
	https://github.com/Drak1814/oUF_Drak
----------------------------------------------------------------------]]

local _, ns = ...
local Media

ns.fontstrings = {}
ns.statusbars = {}

------------------------------------------------------------------------
--	Colors
------------------------------------------------------------------------

oUF.colors.fallback = { 1, 1, 0.8 }
oUF.colors.uninterruptible = { 1, 0.7, 0 }

oUF.colors.threat = {}
for i = 1, 3 do
	local r, g, b = GetThreatStatusColor(i)
	oUF.colors.threat[i] = { r, g, b }
end

do
	local pcolor = oUF.colors.power
	pcolor.MANA[1], pcolor.MANA[2], pcolor.MANA[3] = 0, 0.8, 1
	pcolor.RUNIC_POWER[1], pcolor.RUNIC_POWER[2], pcolor.RUNIC_POWER[3] = 0.8, 0, 1

	local rcolor = oUF.colors.reaction
	rcolor[1][1], rcolor[1][2], rcolor[1][3] = 1, 0.2, 0.2 -- Hated
	rcolor[2][1], rcolor[2][2], rcolor[2][3] = 1, 0.2, 0.2 -- Hostile
	rcolor[3][1], rcolor[3][2], rcolor[3][3] = 1, 0.6, 0.2 -- Unfriendly
	rcolor[4][1], rcolor[4][2], rcolor[4][3] = 1,   1, 0.2 -- Neutral
	rcolor[5][1], rcolor[5][2], rcolor[5][3] = 0.2, 1, 0.2 -- Friendly
	rcolor[6][1], rcolor[6][2], rcolor[6][3] = 0.2, 1, 0.2 -- Honored
	rcolor[7][1], rcolor[7][2], rcolor[7][3] = 0.2, 1, 0.2 -- Revered
	rcolor[8][1], rcolor[8][2], rcolor[8][3] = 0.2, 1, 0.2 -- Exalted
end

------------------------------------------------------------------------
--	Load stuff
------------------------------------------------------------------------

local function debug(...)
	ChatFrame3:AddMessage(strjoin(" ", "|cffff7f4foUF_Drak:|r", tostringall(...)))
end

local Loader = CreateFrame("Frame")
Loader:RegisterEvent("ADDON_LOADED")
Loader:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, event, ...)
end)

local Options = CreateFrame("Frame", "oUFDrakOptions")
Options:Hide()
Options.name = "oUF Drak"
InterfaceOptions_AddCategory(Options)

function Loader:ADDON_LOADED(event, addon)

	if addon ~= "oUF_Drak" then return end

	local function initDB(db, defaults)
		if type(db) ~= "table" then db = {} end
		if type(defaults) ~= "table" then return db end
		for k, v in pairs(defaults) do
			if type(v) == "table" then
				db[k] = initDB(db[k], v)
			elseif type(v) ~= type(db[k]) then
				db[k] = v
			end
		end
		return db
	end

	-- Global settings:
	oUFDrakConfig = initDB(oUFDrakConfig, ns.configDefault)
	ns.config = oUFDrakConfig

	-- Global unit settings:
	oUFDrakUnitConfig = initDB(oUFDrakUnitConfig, ns.uconfigDefault)
	ns.uconfig = oUFDrakUnitConfig

	-- Aura settings stored per character:
	local AURA_CONFIG_VERSION = 3
	oUFDrakAuraConfig = initDB(oUFDrakAuraConfig, {
		customFilters = {},
		deleted = {},
	})
	
	-- Remove default values
	for id, flag in pairs(oUFDrakAuraConfig.customFilters) do
		if flag == ns.defaultAuras[id] then
			oUFDrakAuraConfig.customFilters[id] = nil
		end
	end
	oUFDrakAuraConfig.VERSION = AURA_CONFIG_VERSION
	ns.UpdateAuraList()

	-- SharedMedia
	Media = LibStub("LibSharedMedia-3.0", true)

	if Media then

		Media:Register("statusbar", "Flat", [[Interface\BUTTONS\WHITE8X8]])
		Media:Register("statusbar", "Neal", [[Interface\AddOns\oUF_Drak\Media\Neal]])
		--Media:Register("border", "SimpleSquare", [[Interface\AddOns\oUF_Drak\Media\SimpleSquare.tga]])

		Media.RegisterCallback("oUF_Drak", "LibSharedMedia_Registered", function(callback, mediaType, key)
			--debug(callback, mediaType, key)
			if mediaType == "font" and key == ns.config.font then
				ns.SetAllFonts()
			elseif mediaType == "statusbar" and key == ns.config.statusbar then
				ns.SetAllStatusBarTextures()
			end
		end)
		Media.RegisterCallback("oUF_Drak", "LibSharedMedia_SetGlobal", function(callback, mediaType)
			--debug(callback, mediaType)
			if mediaType == "font" then
				ns.SetAllFonts()
			elseif mediaType == "statusbar" then
				ns.SetAllStatusBarTextures()
			end
		end)
	end
	
	-- FastFocus Key
	if (ns.config.fastfocus) then
		--debug("Enabling FastFocus")
		--Blizzard raid frame
		hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame, ...)
			if frame then
				frame:SetAttribute("shift-type1", "focus")
			end
		end)
		-- World Models
		local foc = CreateFrame("CheckButton", "FastFocuser", UIParent, "SecureActionButtonTemplate")
		foc:SetAttribute("type1", "macro")
		foc:SetAttribute("macrotext", "/focus mouseover")
		SetOverrideBindingClick(FastFocuser, true, "SHIFT-BUTTON1", "FastFocuser")
	end
	
	-- Cleanup
	self:UnregisterEvent(event)
	self.ADDON_LOADED = nil
	self:RegisterEvent("PLAYER_LOGOUT")

	-- Go
	oUF:Factory(ns.Factory)
	
	-- Startup events
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- Sounds for target/focus changing and PVP flagging
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterUnitEvent("UNIT_FACTION", "player")

	-- CTRL+ALT to temporarily show all buffs
	self:RegisterEvent("MODIFIER_STATE_CHANGED")

	-- Load options on demand
--@non-debug@
	Options:SetScript("OnShow", function(self)
		oUFDrak = ns
		local loaded, reason = LoadAddOn("oUF_Drak_Config")
		if not loaded then
			local text = self:CreateFontString(nil, nil, "GameFontHighlight")
			text:SetPoint("BOTTOMLEFT", 16, 16)
			text:SetPoint("TOPRIGHT", -16, -16)
			text:SetFormattedText(ADDON_LOAD_FAILED, "oUF_Drak_Config", _G[reason])
			oUFDrak = nil
		end
	end)
--@end-non-debug@

	SLASH_OUFDrak1 = "/douf"
	function SlashCmdList.OUFDrak(cmd)
		cmd = strlower(cmd)
		if cmd == "buffs" or cmd == "debuffs" then
			local tmp = {}
			local func = cmd == "buffs" and UnitBuff or UnitDebuff
			for i = 1, 40 do
				local name, _, _, _, _, _, _, _, _, _, id = func("target", i)
				if not name then break end
				tinsert(tmp, format("%s [%d]", name, id))
			end
			if #tmp > 0 then
				sort(tmp)
				DEFAULT_CHAT_FRAME:AddMessage(format("|cff00ddbaoUF Drak:|r Your current target has %d %s:", #tmp, cmd))
				for i = 1, #tmp do
					DEFAULT_CHAT_FRAME:AddMessage("   ", tmp[i])
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage(format("|cff00ddbaoUF Drak:|r Your current target does not have any %s.", cmd))
			end
		else
			InterfaceOptionsFrame_OpenToCategory("oUF Drak")
			InterfaceOptionsFrame_OpenToCategory("oUF Drak")
		end
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("oUF_Drak Loaded")
	DEFAULT_CHAT_FRAME:AddMessage("oUF_Drak: FastFocus " .. (ns.config.fastfocus and "Enabled" or "Disabled"))
	DEFAULT_CHAT_FRAME:AddMessage("oUF_Drak: ExpandedZoom " ..(ns.config.expandzoom and "Enabled" or "Disabled"))
			
end

------------------------------------------------------------------------

function Loader:PLAYER_ENTERING_WORLD(event)
	--config = oUFDrakConfig
	if (ns.config.expandzoom) then
		--debug("Expanding Zoom")
		ConsoleExec("CameraDistanceMaxFactor 3")
		ConsoleExec("CameraDistanceMoveSpeed 40")
		ConsoleExec("CameraDistanceSmoothSpeed 40")
	end
end
	
function Loader:PLAYER_LOGOUT(event)
	local function cleanDB(db, defaults)
		if type(db) ~= "table" then return {} end
		if type(defaults) ~= "table" then return db end
		for k, v in pairs(db) do
			if type(v) == "table" then
				if not next(cleanDB(v, defaults[k])) then
					-- Remove empty subtables
					db[k] = nil
				end
			elseif v == defaults[k] then
				-- Remove default values
				db[k] = nil
			end
		end
		return db
	end

	oUFDrakConfig = cleanDB(oUFDrakConfig, ns.configDefault)
	oUFDrakUnitConfig = cleanDB(oUFDrakUnitConfig, ns.uconfigDefault)
end

------------------------------------------------------------------------

function Loader:PLAYER_FOCUS_CHANGED(event)
	if UnitExists("focus") then
		if UnitIsEnemy("focus", "player") then
			PlaySound("igCreatureAggroSelect")
		elseif UnitIsFriend("player", "focus") then
			PlaySound("igCharacterNPCSelect")
		else
			PlaySound("igCreatureNeutralSelect")
		end
	else
		PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
	end
end

-- Sound on target change

function Loader:PLAYER_TARGET_CHANGED(event)
	if UnitExists("target") then
		if UnitIsEnemy("target", "player") then
			PlaySound("igCreatureAggroSelect")
		elseif UnitIsFriend("player", "target") then
			PlaySound("igCharacterNPCSelect")
		else
			PlaySound("igCreatureNeutralSelect")
		end
	else
		PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
	end
end

-- Sound on PVP

local announcedPVP
function Loader:UNIT_FACTION(event, unit)
	if UnitIsPVPFreeForAll("player") or UnitIsPVP("player") then
		if not announcedPVP then
			announcedPVP = true
			PlaySound("igPVPUpdate")
		end
	else
		announcedPVP = nil
	end
end

-- Show all auras

function Loader:MODIFIER_STATE_CHANGED(event, key, state)
	if 	
		( IsControlKeyDown() and (key == 'LALT' or key == 'RALT')) or
		( IsAltKeyDown() and (key == 'LCTRL' or key == 'RCTRL')) 
	then
		local a, b
		if state == 1 then
			a, b = "CustomFilter", "__CustomFilter"
		else
			a, b = "__CustomFilter", "CustomFilter"
		end
		for i = 1, #oUF.objects do
			local object = oUF.objects[i]
			local buffs = object.Auras or object.Buffs
			if buffs and buffs[a] then
				buffs[b] = buffs[a]
				buffs[a] = nil
				buffs:ForceUpdate()
			end
			local debuffs = object.Debuffs
			if debuffs and debuffs[a] then
				debuffs[b] = debuffs[a]
				debuffs[a] = nil
				debuffs:ForceUpdate()
			end
		end
	end
end

function ns.si(value, raw)
	if not value then return "" end
	local absvalue = abs(value)
	local str, val

	if absvalue >= 1e10 then
		str, val = "%.0fb", value / 1e9
	elseif absvalue >= 1e9 then
		str, val = "%.1fb", value / 1e9
	elseif absvalue >= 1e7 then
		str, val = "%.1fm", value / 1e6
	elseif absvalue >= 1e6 then
		str, val = "%.2fm", value / 1e6
	elseif absvalue >= 1e5 then
		str, val = "%.0fk", value / 1e3
	elseif absvalue >= 1e3 then
		str, val = "%.1fk", value / 1e3
	else
		str, val = "%d", value
	end

	if raw then
		return str, val
	else
		return format(str, val)
	end
end

local FALLBACK_FONT_SIZE = 16 -- some Blizzard bug

function ns.CreateFontString(parent, size, justify)
	local file = Media:Fetch("font", ns.config.font) or STANDARD_TEXT_FONT
	if not size or size == 0 then size = FALLBACK_FONT_SIZE end
	size = size * ns.config.fontScale

	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(file, size, ns.config.fontOutline)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetShadowOffset(ns.config.fontShadow and 1 or 0, ns.config.fontShadow and -1 or 0)
	fs.baseSize = size

	tinsert(ns.fontstrings, fs)
	return fs
end

function ns.SetAllFonts()
	local file = Media:Fetch("font", ns.config.font) or STANDARD_TEXT_FONT
	local outline = ns.config.fontOutline
	local shadow = ns.config.fontShadow and 1 or 0
	--print("SetAllFonts", strmatch(file, "[^/\\]+$"), outline)

	for i = 1, #ns.fontstrings do
		local fontstring = ns.fontstrings[i]
		local _, size = fontstring:GetFont()
		if not size or size == 0 then size = FALLBACK_FONT_SIZE end
		fontstring:SetFont(file, size, outline)
		fontstring:SetShadowOffset(shadow, -shadow)
	end

	if not MirrorTimer3.text then return end -- too soon!
	for i = 1, 3 do
		local bar = _G["MirrorTimer" .. i]
		local _, size = bar.text:GetFont()
		bar.text:SetFont(file, size, outline)
	end
end

do
	local function SetReverseFill(self, reverse)
		self.__reverse = reverse
	end

	local function SetTexCoord(self, v)
		local mn, mx = self:GetMinMaxValues()
		if v > 0 and v > mn and v <= mx then
			local pct = (v - mn) / (mx - mn)
			if self.__reverse then
				self.texture:SetTexCoord(1 - pct, 1, 0, 1)
			else
				self.texture:SetTexCoord(0, pct, 0, 1)
			end
		end
	end

	function ns.CreateStatusBar(parent, size, justify, noBG)
		local file = Media:Fetch("statusbar", ns.config.statusbar) or "Interface\\TargetingFrame\\UI-StatusBar"

		local sb = CreateFrame("StatusBar", nil, parent)
		sb:SetStatusBarTexture(file)
		tinsert(ns.statusbars, sb)

		sb.texture = sb:GetStatusBarTexture()
		sb.texture:SetDrawLayer("BORDER")
		sb.texture:SetHorizTile(false)
		sb.texture:SetVertTile(false)

		hooksecurefunc(sb, "SetReverseFill", SetReverseFill)
		hooksecurefunc(sb, "SetValue", SetTexCoord)

		if not noBG then
			sb.bg = sb:CreateTexture(nil, "BACKGROUND")
			sb.bg:SetTexture(file)
			sb.bg:SetAllPoints(true)
			tinsert(ns.statusbars, sb.bg)
		end

		if size then
			sb.value = ns.CreateFontString(sb, size, justify)
		end

		return sb
	end
end

function ns.SetAllStatusBarTextures()
	local file = Media:Fetch("statusbar", ns.config.statusbar) or "Interface\\TargetingFrame\\UI-StatusBar"
	--print("SetAllFonts", strmatch(file, "[^/\\]+$"))

	for i = 1, #ns.statusbars do
		local sb = ns.statusbars[i]
		if sb.SetStatusBarTexture then
			local r, g, b, a = sb:GetStatusBarColor()
			sb:SetStatusBarTexture(file)
			sb:SetStatusBarColor(r, g, b, a)
		else
			local r, g, b, a = sb:GetVertexColor()
			sb:SetTexture(file)
			sb:SetVertexColor(r, g, b, a)
		end
	end

	if not MirrorTimer3.bar then return end -- too soon!
	for i = 1, 3 do
		local bar = _G["MirrorTimer" .. i]

		local r, g, b, a = bar.bar:GetStatusBarColor()
		bar.bar:SetStatusBarTexture(file)
		bar.bar:SetStatusBarColor(r, g, b, a)

		local r, g, b, a = bar.bg:GetVertexColor()
		bar.bg:SetTexture(file)
		bar.bg:SetVertexColor(r, g, b, a)
	end
end