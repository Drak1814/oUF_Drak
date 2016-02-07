--[[--------------------------------------------------------------------
	oUF_Drak
	oUF-based Combat HUD for PvE.
	Copyright (c) 2016 Drak <drak@derpydo.com>. All rights reserved.
	https://github.com/Drak1814/oUF_Drak
----------------------------------------------------------------------]]

local _name, ns = ...
local Media

-- import TOC info

ns.toc = {
	title = GetAddOnMetadata(_name, 'Title'),
	version = GetAddOnMetadata(_name, 'Version'),
	style = GetAddOnMetadata(_name, 'X-oUF-Style'),
}

-- debugging 

ns.debug = function (...)
	if ns.config.debug then ChatFrame3:AddMessage(strjoin(" ", "|cffff7f4f" .. _name .. ":|r", tostringall(...))) end
end

local debug = ns.debug

-- dependency check

assert(oUF, _name .. " was unable to locate oUF install.")

ns.fontstrings = {}
ns.statusbars = {}
ns.grabberPool = {}

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

-- create Loader frame

local Loader = CreateFrame("Frame")
Loader:RegisterEvent("ADDON_LOADED")
Loader:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, event, ...)
end)

-- create Options frame

local Options = CreateFrame("Frame", "oUFDrakOptions")
Options:Hide()
Options.name = "oUF Drak"
InterfaceOptions_AddCategory(Options)

function Loader:ADDON_LOADED(event, addon)

	if addon ~= _name then return end

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
	
	debug("ADDON_LOADED")
	
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

		Media.RegisterCallback(_name, "LibSharedMedia_Registered", function(callback, mediaType, key)
			--debug(callback, mediaType, key)
			if mediaType == "font" and key == ns.config.font then
				ns.SetAllFonts()
			elseif mediaType == "statusbar" and key == ns.config.statusbar then
				ns.SetAllStatusBarTextures()
			end
		end)
		Media.RegisterCallback(_name, "LibSharedMedia_SetGlobal", function(callback, mediaType)
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
		debug("Enabling FastFocus")
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
	oUF:RegisterInitCallback(ns.restorePosition)
	oUF:Factory(ns.Factory)
	
	-- Startup events
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- Combat events
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	
	-- Sounds for target/focus changing and PVP flagging
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterUnitEvent("UNIT_FACTION", "player")

	-- CTRL+ALT to temporarily show all buffs
	self:RegisterEvent("MODIFIER_STATE_CHANGED")

	-- Load options on demand
	Options:SetScript("OnShow", function(self)
		debug("Loading Options")
		oUFDrak = ns
		local loaded, reason = LoadAddOn(_name .. "_Config")
		if not loaded then
			local text = self:CreateFontString(nil, nil, "GameFontHighlight")
			text:SetPoint("BOTTOMLEFT", 16, 16)
			text:SetPoint("TOPRIGHT", -16, -16)
			text:SetFormattedText(ADDON_LOAD_FAILED, _name .. "_Config", _G[reason])
			oUFDrak = nil
		end
	end)

	SLASH_OUFDrak1 = "/douf"
	function SlashCmdList.OUFDrak(cmd)
		cmd = strlower(cmd)
		debug("SlashCmdList", cmd)
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
				DEFAULT_CHAT_FRAME:AddMessage(format("|cff00ddba" .. _name .. ":|r Your current target has %d %s:", #tmp, cmd))
				for i = 1, #tmp do
					DEFAULT_CHAT_FRAME:AddMessage("   ", tmp[i])
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage(format("|cff00ddba" .. _name .. ":|r Your current target does not have any %s.", cmd))
			end
		elseif cmd == "debug" then
			oUFDrakConfig.debug = not oUFDrakConfig.debug
			print(_name .. ": Debugging " .. (oUFDrakConfig.debug and "Enable" or "Disabled"))
		elseif cmd == "move" then
			ns.ToggleGrabbers()
		else
			InterfaceOptionsFrame_OpenToCategory("oUF Drak")
			InterfaceOptionsFrame_OpenToCategory("oUF Drak")
		end
	end
	
	print(_name .. " " .. ns.toc.version .. " Loaded")
	print(_name .. ": FastFocus " .. (ns.config.fastfocus and "Enabled" or "Disabled"))
	print(_name .. ": ExpandedZoom " ..(ns.config.expandzoom and "Enabled" or "Disabled"))
			
end

------------------------------------------------------------------------

function Loader:PLAYER_ENTERING_WORLD(event)
	debug(event)
	if (ns.config.expandzoom) then
		debug("Expanding Zoom")
		ConsoleExec("CameraDistanceMaxFactor 3")
		ConsoleExec("CameraDistanceMoveSpeed 40")
		ConsoleExec("CameraDistanceSmoothSpeed 40")
	end
end
	
function Loader:PLAYER_LOGOUT(event)
	--debug(event)
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

function Loader:PLAYER_REGEN_DISABLED(event)
	debug(event)
	if ns.anchor then
		print("Anchors hidden due to combat.")
		for k, bdrop in next, backdropPool do
			bdrop:Hide()
		end
		ns.anchor = nil
	end
end
	
function Loader:PLAYER_FOCUS_CHANGED(event)
	debug(event)
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
	debug(event)
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
	debug(event)
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
	debug(event)
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
	--debug("CreateFontString", parent:GetName(), size, justify)
	
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
	debug("SetAllFonts")
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
	debug("SetAllTextures")
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

-- Custom Frame Positions

function ns.getObjectInfo(obj)
	local style = obj.style or 'Unknown'
	local ident = obj.unit or obj:GetName()

	-- Is this oUF frame from us?
	if style ~= ns.toc.style then return end
	
	-- Are we dealing with header units?
	local isHeader
	local parent = obj:GetParent()

	if(parent) then
		if(parent:GetAttribute'initialConfigFunction' and parent.style) then
			isHeader = parent
			ident = parent.unit or parent:GetName()
		elseif(parent:GetAttribute'oUF-onlyProcessChildren') then
			isHeader = parent:GetParent()
			ident = isHeader.unit or isHeader:GetName()
		end
	end 

	return ident, isHeader
end

function ns.getPosition(obj, anchor)
	debug("getPosition", obj.unit)
	if not anchor then
		local UIx, UIy = UIParent:GetCenter()
		local Ox, Oy = obj:GetCenter()

		-- Frame doesn't really have a positon yet.
		if(not Ox) then return end

		local OS = obj:GetScale()
		Ox, Oy = Ox * OS, Oy * OS

		local UIWidth, UIHeight = UIParent:GetRight(), UIParent:GetTop()

		local LEFT = UIWidth / 3
		local RIGHT = UIWidth * 2 / 3

		local point, x, y
		if(Ox >= RIGHT) then
			point = 'RIGHT'
			x = obj:GetRight() - UIWidth
		elseif(Ox <= LEFT) then
			point = 'LEFT'
			x = obj:GetLeft()
		else
			x = Ox - UIx
		end

		local BOTTOM = UIHeight / 3
		local TOP = UIHeight * 2 / 3

		if(Oy >= TOP) then
			point = 'TOP' .. (point or '')
			y = obj:GetTop() - UIHeight
		elseif(Oy <= BOTTOM) then
			point = 'BOTTOM' .. (point or '')
			y = obj:GetBottom()
		else
			if(not point) then point = 'CENTER' end
			y = Oy - UIy
		end

		return { point = point, parent = 'UIParent', x = x, y = y, scale = OS }

	else
	
		local point, parent, _, x, y = anchor:GetPoint()
		return { point = point, parent = 'UIParent', x = x, y = y, scale = obj:GetScale() }

	end
end

function ns.restorePosition(obj)
	if InCombatLockdown() then return end

	local unit, isHeader = ns.getObjectInfo(obj)
	if not unit then return end
	
	debug("restorePosition", unit)
	
	-- We've not saved any custom position for this style.
	if not ns.uconfig[unit] 
		or	not ns.uconfig[unit].position 
		or not ns.uconfig[unit].position.custom 
		then return end

	local pos = ns.uconfig[unit].position.custom
	
	debug("restorePosition", unit)

	local target = isHeader or obj 
	if not target._SetPoint then
		target._SetPoint = target.SetPoint
		target.SetPoint = ns.restorePosition
		target._SetScale = target.SetScale
		target.SetScale = ns.restorePosition
	end
	target:ClearAllPoints()

	if not pos.scale then pos.scale = 1	end

	if scale then
		target:_SetScale(pos.scale)
	else
		pos.scale = target:GetScale()
	end
	
	target:_SetPoint(pos.point, pos.parent, pos.point, pos.x / pos.scale, pos.y / pos.scale)
end
 
function ns.saveDefaultPosition(obj)
	local unit, isHeader = ns.getObjectInfo(obj)
	if not unit then return end
	debug("saveDefaultPosition", unit)
	if not ns.uconfig[unit] then ns.uconfig[unit] = {} end
	if not ns.uconfig[unit].position then ns.uconfig[unit].position = {} end
	if not ns.uconfig[unit].position.default then
		local pos
		if isHeader then
			pos = ns.getPosition(isHeader)
		else
			pos = ns.getPosition(obj)
		end
		ns.uconfig[unit].position.default = pos
	end
end

function ns.savePosition(obj, anchor)
	local unit, isHeader = ns.getObjectInfo(obj)
	if not unit then return end
	debug("savePosition", unit)
	if not ns.uconfig[unit] then ns.uconfig[unit] = {} end
	if not ns.uconfig[unit].position then ns.uconfig[unit].position = {} end
	ns.uconfig[unit].position.custom = ns.getPosition(isHeader or obj, anchor)
end

function ns.saveUnitPosition(unit, point, x, y, scale)
	debug("saveUnitPosition", unit, point, x, y, scale)
	if not ns.uconfig[unit] then ns.uconfig[unit] = {} end
	if not ns.uconfig[unit].position then ns.uconfig[unit].position = {} end	
	ns.uconfig[unit].position.custom = {
		point = point,
		parent = 'UIParent',
		x = x,
		y = y,
		scale = scale
	}
end

-- Attempt to figure out a more sane name to display
ns.nameCache = {}
function ns.smartName(obj, header)
	local validNames = {
		'player',
		'pet',
		'focus',
		'focustarget',
		'target',
		'targettarget'
	}
	
	local function validName(smartName)
		-- Not really a valid name, but we'll accept it for simplicities sake.
		if tonumber(smartName) then
			return smartName
		end

		if type(smartName) == 'string' then
			-- strip away trailing s from pets, but don't touch boss/focus.
			smartName = smartName:gsub('([^us])s$', '%1')

			for _, v in pairs(validNames) do
				if(v == smartName) then	return smartName end
			end

			if(
				smartName:match'^party%d?$' or
				smartName:match'^arena%d?$' or
				smartName:match'^boss%d?$' or
				smartName:match'^partypet%d?$' or
				smartName:match'^raid%d?%d?$' or
				smartName:match'%w+target$' or
				smartName:match'%w+pet$'
				) then
				return smartName
			end
		end
	end

	local function guessName(...)
		local name = validName(select(1, ...))
		local n = select('#', ...)
		if n > 1 then
			for i=2, n do
				local inp = validName(select(i, ...))
				if inp then	name = (name or '') .. inp end
			end
		end
		return name
	end

	local function smartString(name)
		if ns.nameCache[name] then return ns.nameCache[name] end

		-- Here comes the substitute train!
		local n = name
			:gsub('ToT', 'targettarget')
			:gsub('(%l)(%u)', '%1_%2')
			:gsub('([%l%u])(%d)', '%1_%2_')
			:gsub('Main_', 'Main')
			:lower()

		n = guessName(string.split('_', n))
		if n then
			ns.nameCache[name] = n
			return n
		end

		return name
	end

	if type(obj) == 'string' then
		return smartString(obj)
	elseif header then
		return smartString(header:GetName())
	else
		local name = obj:GetName()
		if name then return smartString(name) end
		return obj.unit or '<unknown>'
	end
end

function ns.getGrabber(obj, isHeader)

	local target = isHeader or obj
	if not target:GetCenter() then return end
	if ns.grabberPool[target] then return ns.grabberPool[target] end

	local grabber = CreateFrame("Frame")
	grabber:SetParent(UIParent)
	grabber:Hide()

	grabber:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})
	grabber:SetFrameStrata('TOOLTIP')
	grabber:SetAllPoints(target)

	grabber:EnableMouse(true)
	grabber:SetMovable(true)
	grabber:SetResizable(true)
	grabber:RegisterForDrag("LeftButton")

	local name = grabber:CreateFontString(nil, 'OVERLAY', "GameFontNormal")
	name:SetPoint('CENTER')
	name:SetJustifyH('CENTER')
	name:SetFont(GameFontNormal:GetFont(), 12)
	name:SetTextColor(1, 1, 1)

	local scale = CreateFrame("Button", nil, grabber)
	scale:SetPoint('BOTTOMRIGHT')
	scale:SetSize(16, 16)

	scale:SetNormalTexture[[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]]
	scale:SetHighlightTexture[[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]]
	scale:SetPushedTexture[[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down]]

	scale:SetScript("OnMouseDown", function(self)
		local grabber = self:GetParent()
		ns.saveDefaultPosition(grabber.obj)
		grabber:StartSizing('BOTTOMRIGHT')

		local frame = grabber.header or grabber.obj
		frame:ClearAllPoints()
		frame:SetAllPoints(grabber)

		self:SetButtonState("PUSHED", true)
	end)

	scale:SetScript("OnMouseUp", function(self)
		local grabber = self:GetParent()
		self:SetButtonState("NORMAL", false)

		grabber:StopMovingOrSizing()
		ns.savePosition(grabber.obj, grabber)
	end)
	
	grabber.name = name
	grabber.obj = obj
	grabber.header = isHeader
	grabber.target = target

	grabber:SetBackdropBorderColor(0, .9, 0)
	grabber:SetBackdropColor(0, .9, 0)

	grabber.baseWidth, grabber.baseHeight = obj:GetSize()

	-- We have to define a minHeight on the header if it doesn't have one. The
	-- reason for this is that the header frame will have an height of 0.1 when
	-- it doesn't have any frames visible.
	if isHeader and
		( 	
			not isHeader:GetAttribute("minHeight") and math.floor(isHeader:GetHeight()) == 0 
			or not isHeader:GetAttribute("minWidth") and math.floor(isHeader:GetWidth()) == 0 
		)
	then
		isHeader:SetHeight(obj:GetHeight())
		isHeader:SetWidth(obj:GetWidth())

		if not isHeader:GetAttribute("minHeight") then
			isHeader.dirtyMinHeight = true
			isHeader:SetAttribute('minHeight', obj:GetHeight())
		end

		if not isHeader:GetAttribute("minWidth") then
			isHeader.dirtyMinWidth = true
			isHeader:SetAttribute("minWidth", obj:GetWidth())
		end
	elseif isHeader then
		grabber.baseWidth, grabber.baseHeight = isHeader:GetSize()
	end
	
	grabber:SetScript("OnShow", function(self)
		return self.name:SetText(ns.smartName(self.obj, self.header))
	end)
	
	grabber:SetScript("OnHide",  function(self)
		if self.dirtyMinHeight then
			self:SetAttribute('minHeight', nil)
		end

		if self.dirtyMinWidth then
			self:SetAttribute('minWidth', nil)
		end
	end)
	
	grabber:SetScript("OnDragStart", function(self)
		ns.saveDefaultPosition(self.obj)
		self:StartMoving()

		local frame = self.header or self.obj
		frame:ClearAllPoints()
		frame:SetAllPoints(self)
	end)
	
	grabber:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ns.savePosition(self.obj, self)

		-- Restore the initial anchoring, so the anchor follows the frame when we
		-- edit positions through the UI.
		ns.restorePosition(self.obj)
		self:ClearAllPoints()
		self:SetAllPoints(self.header or self.obj)
	end)

	grabber:SetScript("OnSizeChanged", function(self, width, height)
		local baseWidth, baseHeight = self.baseWidth, self.baseHeight

		local scale = width / baseWidth

		if scale <= .3 then
			scale = .3
		end

		self:SetSize(scale * baseWidth, scale * baseHeight)
		local target = self.target
		local SetScale = target._SetScale or target.SetScale
		SetScale(target, scale)
	end)

	ns.grabberPool[target] = grabber

	return grabber
end

function ns.ToggleGrabbers()
	if InCombatLockdown() then
		print("Frames cannot be toggled while in combat")
		return
	end
	
	debug("ToggleGrabbers")
	
	if not ns.anchor then
		for k, obj in next, oUF.objects do
			local unit, isHeader = ns.getObjectInfo(obj)
			if unit then
				local grabber = ns.getGrabber(obj, isHeader)
				if grabber then grabber:Show() end
			end
		end
		ns.anchor = true
	else
		for _, grabber in pairs(ns.grabberPool) do
			grabber:Hide()
		end
		ns.anchor = nil
	end
end

