--[[--------------------------------------------------------------------
	oUF_Drak
	oUF-based Combat HUD for PvE.
	Copyright (c) 2016 Drak <drak@derpydo.com>. All rights reserved.
	https://github.com/Drak1814/oUF_Drak
----------------------------------------------------------------------]]

local _, ns = ...

-- Default Shared Config

ns.configDefault = {
	width = 200,
	height = 30,
	powerHeight = 0.3,				-- how much of the frame's height should be occupied by the power bar

	backdrop = { bgFile = [[Interface\BUTTONS\WHITE8X8]] },
	backdropColor = { 32/256, 32/256, 32/256, 1 },

	statusbar = "Neal",				-- bar texture

	font = "Arial Narrow",
	fontOutline = "OUTLINE",
	fontShadow = true,
	fontScale = 1, -- no UI

	dispelFilter = true,			-- only highlight the frame for debuffs you can dispel
	ignoreOwnHeals = false,			-- only show incoming heals from other players
	threatLevels = false,			-- show threat levels instead of binary aggro

	combatText = false,				-- show combat feedback text
	druidMana = false,				-- [druid] show a mana bar in cat/bear forms
	eclipseBar = true,				-- [druid] show an eclipse bar
	eclipseBarIcons = false,		-- [druid] show animated icons on the eclipse bar
	runeBars = true,				-- [deathknight] show rune cooldown bars
	staggerBar = true,				-- [monk] show stagger bar
	totemBars = true,				-- [shaman] show totem duration bars

	healthColorMode = "HEALTH",
	healthColor = { 0.1, 0.9, 0.1 },
	healthBG = 0.2,					

	powerColorMode = "CLASS",		
	powerColor = { 0.9, 0.1, 0.9 }, 
	powerBG = 0.2,					
	
	castColor = { 0.9, 0.9, 0.1 },	
	castBG = 0.2,					

	borderColor = { 0.5, 0.5, 0.5 },
	borderSize = 12,

	PVP = false, -- enable PVP mode, currently only affects aura filtering
	
	fastfocus = 'SHIFT'
}

-- Default Unit Config

ns.uconfigDefault = {
	player = {
		point = "BOTTOMRIGHT UIParent CENTER -200 -200",
		width = 1.3,
		power = true,
		castbar = true,
		visible = "custom [combat,novehicleui,nooverridebar,nopetbattle] show; hide"
	},
	pet = {
		point = "RIGHT player LEFT -12 0",
		width = 0.5,
		power = true,
		castbar = true,
		visible = defVisibleCond:format(",pet")
	}
	focus = {
		point = "TOPLEFT target BOTTOMLEFT 0 -60",
		power = true,
		visible = "custom [combat,novehicleui,nooverridebar,nopetbattle,@focus,exists] show; hide"
	},
	focustarget = {
		point = "LEFT focus RIGHT 12 0",
		width = 0.5,
		visible = "[combat,novehicleui,nooverridebar,nopetbattle,@focustarget,exists] show; hide"
	},
	target = {
		point = "BOTTOMLEFT UIParent CENTER 200 -200",
		width = 1.3,
		power = true,
		castbar = true,
		visible = "custom [combat,novehicleui,nooverridebar,nopetbattle,@focus,exists] show; hide"
	},
	targettarget = {
		point = "LEFT target RIGHT 12 0",
		width = 0.5,
		visible = "custom [combat,novehicleui,nooverridebar,nopetbattle,@focustarget,exists] show; hide"
	}
}

