--[[
	Afterlife Crowd Control
	TBC Classic and Mists of Pandaria Classic
	by Codermik
]]

local addonName, addonTable = ...
Afterlife = addonTable
AfterlifeGlobalSettings = AfterlifeGlobalSettings or {}
AfterlifeCharacterSettings = AfterlifeCharacterSettings or {}
local ADDON_VERSION = "2026.1.0.1.1"
local ADDON_DATE = "9th June 2026"

--- Resolves a localized string by key, with optional format arguments.
--- @param key string locale key
--- @param ... any optional format arguments passed to the locale lookup
--- @return string localized text, or the key if locale is unavailable
local function L(key, ...)
	if Afterlife_GetLocale then
		return Afterlife_GetLocale(key, ...)
	end
	return key
end

--- Removes the realm suffix from a player name when present.
--- @param name string|nil player name, possibly including realm
--- @return string|nil name without realm suffix, or unchanged input
function Afterlife:StripRealmName(name)
	if not name or name == "" then
		return name
	end
	if Ambiguate then
		return Ambiguate(name, "none")
	end
	local realm = GetRealmName and GetRealmName()
	if realm and realm ~= "" then
		local suffix = "-" .. realm
		if name:sub(-#suffix) == suffix then
			return name:sub(1, #name - #suffix)
		end
		local compactRealm = realm:gsub("%s+", "")
		if compactRealm ~= realm then
			suffix = "-" .. compactRealm
			if name:sub(-#suffix) == suffix then
				return name:sub(1, #name - #suffix)
			end
		end
	end
	return name
end

Afterlife.Version = ADDON_VERSION
Afterlife.Date = ADDON_DATE
Afterlife.CC_GROUP = "Afterlife_Controlled"
Afterlife.timerGroupsReady = false

AfterlifeControlledCC = {}

local CC_GROUP = Afterlife.CC_GROUP

local ADDON_CMD_HEADER = "AfterlifeCC"
local ADDON_CMD_PREFIX = "ACCCP-2.0"
local ADDON_CMD_LIST = { ACCA = true, ACCR = true, ACCF = true }
local TRAP_PENDING_DURATION = 30
local DR_WINDOW = 18
local SOUND_APPLIED = "Interface\\AddOns\\Afterlife\\assets\\sounds\\applied.ogg"
local SOUND_RENEWED = "Interface\\AddOns\\Afterlife\\assets\\sounds\\renewed.ogg"
local SOUND_BREAK = "Interface\\AddOns\\Afterlife\\assets\\sounds\\ccbreak.ogg"
local SOUNDS_ROOT = "Interface\\AddOns\\Afterlife\\assets\\sounds\\"
local LOCALE_SOUND_FALLBACK = "enUS"
local LOCALE_SOUND_FOLDERS = {
	enUS = true, deDE = true, esES = true, frFR = true, ruRU = true, zhCN = true, zhTW = true,
}
local ccCountdownLastSecond = {}
local killingBlowState = { currentIndex = 1, lastPlayTime = 0 }
local HandleOwnCCBreak

local RAID_ICON_CHAT = { "{rt1} ", "{rt2} ", "{rt3} ", "{rt4} ", "{rt5} ", "{rt6} ", "{rt7} ", "{rt8} ", "" }
local RAID_ICON_PATHS = {
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_1.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_2.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_3.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_4.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_5.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_6.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp",
	"Interface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp",
	"",
}
local RAID_ICON_LOOKUP = {
	[COMBATLOG_OBJECT_RAIDTARGET1] = 1,
	[COMBATLOG_OBJECT_RAIDTARGET2] = 2,
	[COMBATLOG_OBJECT_RAIDTARGET3] = 3,
	[COMBATLOG_OBJECT_RAIDTARGET4] = 4,
	[COMBATLOG_OBJECT_RAIDTARGET5] = 5,
	[COMBATLOG_OBJECT_RAIDTARGET6] = 6,
	[COMBATLOG_OBJECT_RAIDTARGET7] = 7,
	[COMBATLOG_OBJECT_RAIDTARGET8] = 8,
}

local playerGUID
local chatChannel = "SOLO"
local targetGuid
local focusGuid
local ccReady = false
local pendingCast3DUnit = nil

local AfterlifeDiminishTimers = {}
local AfterlifeTrapTimers = {}

local DEFAULT_TEXTURE = "Blizzard"
local DEFAULT_FONT = "Friz Quadrata TT"
local DEFAULT_FONT_SIZE = 10
local DEFAULT_FONT_FLAGS = ""

--- Prints a prefixed message to the default chat frame.
--- @param msg any message text to display
local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Afterlife|r: " .. tostring(msg))
end

--- Loads required addon libraries (NaturTimers and LibSharedMedia).
--- @return boolean true if both libraries loaded successfully
local function InitLibraries()
	local NT = LibStub:GetLibrary("NaturTimers-1.0", true)
	if not NT then
		Print("|cffff0000" .. L("MSG_NATURTIMERS_FAILED") .. "|r")
		return false
	end
	local LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)
	if not LSM then
		Print("|cffff0000" .. L("MSG_LSM_FAILED") .. "|r")
		return false
	end
	Afterlife.NaturTimers = NT
	Afterlife.LSM = LSM
	return true
end

--- Resolves a status bar texture key to a file path via LibSharedMedia.
--- @param key string|nil LSM status bar media key
--- @return string texture file path
local function ResolveTexture(key)
	local LSM = Afterlife.LSM
	if LSM and key then
		local path = LSM:Fetch("statusbar", key)
		if path and path ~= "" then
			return path
		end
	end
	if LSM then
		return LSM:Fetch("statusbar", LSM.DefaultMedia.statusbar or DEFAULT_TEXTURE)
	end
	return "Interface\\TargetingFrame\\UI-StatusBar"
end

--- Resolves a font key to a file path via LibSharedMedia.
--- @param key string|nil LSM font media key
--- @return string font file path
local function ResolveFont(key)
	local LSM = Afterlife.LSM
	if LSM and key then
		local path = LSM:Fetch("font", key)
		if path and path ~= "" then
			return path
		end
	end
	if LSM then
		return LSM:Fetch("font", LSM.DefaultMedia.font or DEFAULT_FONT)
	end
	return "Fonts\\FRIZQT__.TTF"
end

--- Returns saved timer group settings from global settings, initializing if needed.
--- @param groupName string|nil timer group name; defaults to the CC group
--- @return table|nil saved group settings table, or nil if missing
local function GetSavedGroupSettings(groupName)
	groupName = groupName or CC_GROUP
	if Afterlife_Options_InitGlobalSettings then
		Afterlife_Options_InitGlobalSettings()
	end
	local db = AfterlifeGlobalSettings
	if not db or not db.groups or not db.groups[groupName] then
		return nil
	end
	return db.groups[groupName]
end

--- Builds NaturTimers group options from saved settings with defaults applied.
--- @param saved table|nil persisted group settings
--- @return table NaturTimers group options table
local function BuildGroupOpts(saved)
	saved = saved or {}
	return {
		title = saved.title or L("CROWD_CONTROLS"),
		texture = ResolveTexture(saved.texture or DEFAULT_TEXTURE),
		font = ResolveFont(saved.font or DEFAULT_FONT),
		fontSize = saved.fontSize or DEFAULT_FONT_SIZE,
		fontFlags = saved.fontFlags or DEFAULT_FONT_FLAGS,
		rightJustifyTime = saved.rightJustifyTime ~= false,
		showRightIcon = AfterlifeGlobalSettings.showRaidIcons ~= false,
		point = saved.point or "CENTER",
		relativePoint = saved.relativePoint or "CENTER",
		x = saved.x or 320,
		y = saved.y or -120,
		width = saved.width or 250,
		height = saved.height or 25,
		spacing = saved.spacing or 2,
		growthDirection = saved.growthDirection or "DOWN",
		sortOrder = saved.sortOrder or "remaining_asc",
	}
end

--- Persists the anchor position of the CC timer group to global settings.
--- @param group Frame|nil NaturTimers group frame whose position to save
function Afterlife:SaveGroupPosition(group)
	local name = group and group:GetName()
	local key = name and name:match("^NaturTimersGroup_(.+)$")
	if key ~= CC_GROUP then
		return
	end
	local db = AfterlifeGlobalSettings
	if not db or not db.groups or not db.groups[key] then
		return
	end
	local saved = db.groups[key]
	local point, _, relativePoint, x, y = group:GetPoint(1)
	if point and relativePoint then
		saved.point = point
		saved.relativePoint = relativePoint
		saved.x = x
		saved.y = y
	end
end

--- Creates or updates the CC timer group from saved settings and wires drag-to-save.
function Afterlife:RefreshTimerGroup()
	local NT = self.NaturTimers
	if not NT then
		return
	end
	local saved = GetSavedGroupSettings()
	local opts = BuildGroupOpts(saved)
	opts.relativeTo = UIParent
	local group = NT:GetGroup(CC_GROUP)
	if group then
		NT:UpdateGroupOptions(CC_GROUP, opts)
	else
		NT:CreateGroup(CC_GROUP, opts)
	end
	group = NT:GetGroup(CC_GROUP)
	if group and group.anchor then
		group.anchor:SetScript("OnDragStop", function(self)
			local parent = self:GetParent()
			parent:StopMovingOrSizing()
			Afterlife:SaveGroupPosition(parent)
		end)
	end
	self.timerGroupsReady = true
	self:ApplyAnchorVisibility()
end

--- Ensures the CC timer group exists, creating it on first use.
function Afterlife:EnsureTimerGroups()
	if not self.NaturTimers then
		return
	end
	if not self.timerGroupsReady then
		self:RefreshTimerGroup()
	end
end

--- Returns whether timer group anchors are currently shown for repositioning.
--- @return boolean true if anchors are unlocked
function Afterlife:AreAnchorsUnlocked()
	local db = AfterlifeGlobalSettings
	return db and db.showAnchors and true or false
end

--- Shows or hides the CC timer group anchor based on global settings.
function Afterlife:ApplyAnchorVisibility()
	local NT = self.NaturTimers
	if not NT then
		return
	end
	local show = self:AreAnchorsUnlocked()
	NT:SetGroupAnchorVisible(CC_GROUP, show)
end

--- Sets whether timer group anchors are unlocked and updates their visibility.
--- @param unlocked boolean true to show anchors for dragging
function Afterlife:SetAnchorsUnlocked(unlocked)
	if Afterlife_Options_InitGlobalSettings then
		Afterlife_Options_InitGlobalSettings()
	end
	AfterlifeGlobalSettings.showAnchors = unlocked and true or false
	self:ApplyAnchorVisibility()
end

--- Toggles timer group anchor lock state.
--- @return boolean new anchor-unlocked state after toggling
function Afterlife:ToggleAnchors()
	self:SetAnchorsUnlocked(not self:AreAnchorsUnlocked())
	return self:AreAnchorsUnlocked()
end

--- Shows or hides the CC timer group based on per-character enabled state.
--- @param enabled boolean true to show timers, false to hide them
function Afterlife:SetEnabled(enabled)
	local NT = self.NaturTimers
	if not NT then
		return
	end
	self:EnsureTimerGroups()
	local group = NT:GetGroup(CC_GROUP)
	if group then
		if enabled then
			group:Show()
		else
			group:Hide()
		end
	end
end

--- Prints a debug message to chat when debug mode is enabled in settings.
--- @param msg any message to log
function Afterlife:DebugPrint(msg)
	local db = AfterlifeGlobalSettings
	if not db or not db.debugMode or not msg then
		return
	end
	local prefix = L("ADDON_TITLE") .. L("DEBUG_LABEL")
	local msgStr = tostring(msg)
	local textChat = "|cffff8800" .. prefix .. "|r|cffffffff : " .. msgStr .. "|r"
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(textChat)
	else
		print(textChat)
	end
end

--- Returns the icon texture for a spell by ID or name.
--- @param spellIdOrName number|string spell identifier
--- @return string|nil spell icon file path
local function GetSpellIcon(spellIdOrName)
	return select(3, GetSpellInfo(spellIdOrName))
end

local TEST_TIMER_SPELLS = { 12826, 6213, 710 }
local TEST_TIMER_REMAINING_FRACTION = { 0.75, 0.5, 0.75 }

--- Stops all preview/test CC timer bars used in options.
function Afterlife:ClearTestTimers()
	self:EnsureTimerGroups()
	local NT = self.NaturTimers
	if not NT then
		return
	end
	for i = 1, #TEST_TIMER_SPELLS do
		NT:StopTimer(CC_GROUP, "test_" .. i)
	end
end

--- Starts preview/test CC timer bars for options UI demonstration.
function Afterlife:AddTestTimers()
	self:EnsureTimerGroups()
	local NT = self.NaturTimers
	if not NT then
		return
	end
	for i, spellId in ipairs(TEST_TIMER_SPELLS) do
		local entry = Afterlife_GetCCSpell and Afterlife_GetCCSpell(spellId)
		local duration = (entry and entry.duration) or 10
		local fraction = TEST_TIMER_REMAINING_FRACTION[i] or 1
		local startRemaining = duration * fraction
		NT:StartTimer(CC_GROUP, "test_" .. i, duration, {
			label = GetSpellInfo(spellId) or tostring(spellId),
			reverse = true,
			startRemaining = startRemaining,
			iconLeft = GetSpellIcon(spellId),
		})
	end
end

--- Returns whether any preview/test CC timer bars are currently active.
--- @return boolean true if at least one test timer is active
function Afterlife:HasActiveTestTimers()
	self:EnsureTimerGroups()
	local NT = self.NaturTimers
	if not NT then
		return false
	end
	local group = NT:GetGroup(CC_GROUP)
	if not group or not group.timers then
		return false
	end
	for i = 1, #TEST_TIMER_SPELLS do
		local bar = group.timers["test_" .. i]
		if bar and bar.active then
			return true
		end
	end
	return false
end

--- Re-applies test timers when any are already active (e.g. after settings change).
function Afterlife:RefreshTestTimersIfActive()
	if self:HasActiveTestTimers() then
		self:AddTestTimers()
	end
end

---------------------------------------------------------------------------
-- CC registry and accessors
---------------------------------------------------------------------------

--- Builds a unique timer ID from a mob GUID and spell ID.
--- @param mobGuid string target unit GUID
--- @param spellId number crowd-control spell ID
--- @return string composite timer identifier
function Afterlife:MakeCCTimerId(mobGuid, spellId)
	return tostring(mobGuid) .. tostring(spellId)
end

--- Builds a timer ID for a diminish-returns cooldown bar.
--- @param mobGuid string target unit GUID
--- @return string DR timer identifier
function Afterlife:MakeDRTimerId(mobGuid)
	return "dr_" .. tostring(mobGuid)
end

--- Returns the active CC entry for a timer ID.
--- @param timerId string|nil CC timer identifier
--- @return table|nil CC entry table, or nil if not found
function Afterlife:GetCC(timerId)
	return timerId and AfterlifeControlledCC[timerId] or nil
end

--- Looks up an active CC entry by mob GUID and spell ID.
--- @param mobGuid string target unit GUID
--- @param spellId number crowd-control spell ID
--- @return table|nil CC entry table, or nil if not found
function Afterlife:GetCCByMobAndSpell(mobGuid, spellId)
	return self:GetCC(self:MakeCCTimerId(mobGuid, spellId))
end

--- Returns the first active CC entry cast by the given player GUID.
--- @param casterGuid string|nil caster player GUID
--- @return table|nil CC entry table, or nil if none found
function Afterlife:GetCCByCaster(casterGuid)
	if not casterGuid then
		return nil
	end
	for _, entry in pairs(AfterlifeControlledCC) do
		if entry.casterGuid == casterGuid then
			return entry
		end
	end
	return nil
end

--- Returns a shallow copy of all active CC entries keyed by timer ID.
--- @return table<string, table> map of timerId to CC entry
function Afterlife:GetAllCC()
	local copy = {}
	for timerId, entry in pairs(AfterlifeControlledCC) do
		copy[timerId] = entry
	end
	return copy
end

--- Counts the number of currently tracked CC entries.
--- @return number active CC count
function Afterlife:CountCC()
	local count = 0
	for _ in pairs(AfterlifeControlledCC) do
		count = count + 1
	end
	return count
end

--- Returns whether CC tracking is ready and enabled for this character.
--- @return boolean true if CC features should run
local function IsCCEnabled()
	if not ccReady or not Afterlife.NaturTimers then
		return false
	end
	local charSettings = Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings()
	return charSettings and charSettings.enabled ~= false
end

--- Returns whether the player is currently in a battleground or PvP instance.
--- @return boolean true if in a battleground
local function IsInBattleground()
	if UnitInBattleground and UnitInBattleground("player") then
		return true
	end
	if not IsInInstance() then
		return false
	end
	local _, instanceType = GetInstanceInfo()
	return instanceType == "pvp"
end

--- Returns the chat channel used for battleground announcements.
--- @return string "BATTLEGROUND" or "INSTANCE_CHAT"
local function GetBattlegroundAnnounceChannel()
	if UnitInBattleground and UnitInBattleground("player") then
		return "BATTLEGROUND"
	end
	return "INSTANCE_CHAT"
end

--- Determines the current group chat channel based on raid/party status.
--- @return string "RAID", "PARTY", or "SOLO"
local function GetChatChannel()
	if IsInRaid() then
		return "RAID"
	end
	if IsInGroup() then
		return "PARTY"
	end
	return "SOLO"
end

--- Refreshes the cached chat channel from current group state.
local function UpdateChatChannel()
	chatChannel = GetChatChannel()
end

--- Returns the chat channel to use for CC announcements.
--- @return string raid/party/solo or battleground channel as configured
local function GetAnnounceChatChannel()
	UpdateChatChannel()
	if AfterlifeGlobalSettings.announceInBattlegrounds and IsInBattleground() then
		return GetBattlegroundAnnounceChannel()
	end
	return chatChannel
end

--- Returns whether a GUID belongs to a player unit.
--- @param guid string|nil unit GUID
--- @return boolean true if the GUID is a player
local function IsPlayerGuid(guid)
	if not guid then
		return false
	end
	return strsplit("-", guid) == "Player"
end

--- Finds a group member's name matching the given unit name (realm-stripped).
--- @param unitName string|nil player name to look up
--- @return string|nil matching roster name with realm, or nil if not in group
local function CheckRoster(unitName)
	if not unitName then
		return nil
	end
	local stripped = Afterlife:StripRealmName(unitName)
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local name = GetRaidRosterInfo(i)
			if name and Afterlife:StripRealmName(name) == stripped then
				return name
			end
		end
	elseif IsInGroup() then
		for i = 1, GetNumGroupMembers() - 1 do
			local name = UnitName("party" .. i)
			if name and Afterlife:StripRealmName(name) == stripped then
				return name
			end
		end
		local player = UnitName("player")
		if player and Afterlife:StripRealmName(player) == stripped then
			return player
		end
	end
	return nil
end

--- Returns whether the caster is the player or a member of the current group.
--- @param sourceGUID string caster unit GUID
--- @param sourceName string caster name
--- @return boolean true if caster is tracked as a group member
local function IsGroupCaster(sourceGUID, sourceName)
	if not IsPlayerGuid(sourceGUID) then
		return false
	end
	if chatChannel == "SOLO" then
		return false
	end
	if sourceGUID == playerGUID then
		return true
	end
	return CheckRoster(sourceName) ~= nil
end

--- Extracts raid target icon index, chat token, and texture path from combat flags.
--- @param destRaidFlags number|nil COMBATLOG_OBJECT raid target flags
--- @return number icon index (1-8, or 0 for none)
--- @return string raid icon chat token
--- @return string raid icon texture path
local function GetRaidIconInfo(destRaidFlags)
	local index = RAID_ICON_LOOKUP[bit.band(destRaidFlags or 0, COMBATLOG_OBJECT_RAIDTARGET_MASK)]
	if index then
		return index, RAID_ICON_CHAT[index], RAID_ICON_PATHS[index]
	end
	return 0, RAID_ICON_CHAT[9], RAID_ICON_PATHS[9]
end

--- Looks up CC spell metadata and applies player-target duration caps.
--- @param spellId number crowd-control spell ID
--- @param destGuid string target unit GUID
--- @return table|nil spell entry from the CC spell registry
--- @return number|nil effective duration in seconds
--- @return string|nil spell icon file path
local function GetCCSpellDetails(spellId, destGuid)
	local entry = Afterlife_GetCCSpell and Afterlife_GetCCSpell(spellId)
	if not entry then
		return nil
	end
	local duration = entry.duration
	if IsPlayerGuid(destGuid) and duration > 9 then
		duration = 10
	end
	local icon = select(3, GetSpellInfo(spellId))
	return entry, duration, icon
end

--- Returns whether a spell entry represents freezing trap placement.
--- @param entry table|nil CC spell registry entry
--- @return boolean true if family is freezing_trap
local function IsTrapPlacementSpell(entry)
	return entry and entry.family == "freezing_trap"
end

--- Returns whether a spell entry represents freezing trap effect application.
--- @param entry table|nil CC spell registry entry
--- @return boolean true if family is freezing_trap_effect
local function IsTrapEffectSpell(entry)
	return entry and entry.family == "freezing_trap_effect"
end

--- Stops a CC timer bar in the NaturTimers CC group.
--- @param timerId string|nil timer identifier to stop
local function StopCCTimerBar(timerId)
	local NT = Afterlife.NaturTimers
	if NT and timerId then
		NT:StopTimer(CC_GROUP, timerId)
	end
end

--- Starts or refreshes a CC timer bar for the given CC entry.
--- @param entry table|nil CC entry with timerId, names, duration, and icons
local function StartCCTimerBar(entry)
	local NT = Afterlife.NaturTimers
	if not NT or not entry then
		return
	end
	Afterlife:EnsureTimerGroups()
	local opts = {
		label = (entry.mobName or "Unknown") .. " (" .. entry.casterName .. ")",
		reverse = true,
		iconLeft = entry.icon,
	}
	if entry.raidIconIndex and entry.raidIconIndex > 0 and AfterlifeGlobalSettings.showRaidIcons ~= false then
		opts.iconRight = RAID_ICON_PATHS[entry.raidIconIndex]
	end
	NT:StartTimer(CC_GROUP, entry.timerId, entry.duration+1, opts)
end

--- Rebuilds all active CC timer bars (e.g. after appearance settings change).
function Afterlife:RefreshAllCCTimerBars()
	for _, entry in pairs(AfterlifeControlledCC) do
		StartCCTimerBar(entry)
	end
end

--- Computes remaining CC duration for an entry based on applied time.
--- @param entry table|nil CC entry with duration and appliedAt
--- @return number seconds remaining, floored at zero
function Afterlife:GetCCRemaining(entry)
	if not entry then
		return 0
	end
	return math.max(0, entry.duration - (GetTime() - entry.appliedAt))
end

--- Clears countdown sound deduplication state for a timer ID.
--- @param timerId string|nil CC timer identifier
local function ClearCCCountdownSound(timerId)
	if timerId then
		ccCountdownLastSecond[timerId] = nil
	end
end

--- Removes a CC entry, stops its timer bar, and optionally clears the 3D frame.
--- @param timerId string CC timer identifier
--- @param silent boolean|nil when false, clears 3D frame if no own CC remains
--- @return table|nil removed CC entry, or nil if not found
function Afterlife:RemoveCC(timerId, silent)
	local entry = AfterlifeControlledCC[timerId]
	if not entry then
		return nil
	end
	AfterlifeControlledCC[timerId] = nil
	ClearCCCountdownSound(timerId)
	StopCCTimerBar(timerId)
	if not silent and entry.casterGuid == playerGUID then
		if not Afterlife:GetCCByCaster(playerGUID) then
			if Afterlife.Clear3DFrame then
				Afterlife:Clear3DFrame()
			end
		end
	end
	return entry
end

--- Removes all CC entries affecting the given mob GUID.
--- @param mobGuid string target unit GUID
--- @return table[] list of removed CC entries
function Afterlife:RemoveCCByMob(mobGuid)
	local removed = {}
	for timerId, entry in pairs(AfterlifeControlledCC) do
		if entry.mobGuid == mobGuid then
			removed[#removed + 1] = self:RemoveCC(timerId, true)
		end
	end
	if not self:GetCCByCaster(playerGUID) and Afterlife.Clear3DFrame then
		Afterlife:Clear3DFrame()
	end
	return removed
end

--- Removes all CC entries cast by the given player GUID.
--- @param casterGuid string caster player GUID
function Afterlife:RemoveCCByCaster(casterGuid)
	for timerId, entry in pairs(AfterlifeControlledCC) do
		if entry.casterGuid == casterGuid then
			self:RemoveCC(timerId, true)
		end
	end
	if casterGuid == playerGUID and Afterlife.Clear3DFrame then
		Afterlife:Clear3DFrame()
	end
end

--- Removes expired CC entries and triggers own-CC-break handling when applicable.
function Afterlife:PurgeExpiredCC()
	for timerId, entry in pairs(AfterlifeControlledCC) do
		if self:GetCCRemaining(entry) <= 0 then
			local wasOwn = entry.casterGuid == playerGUID
			local removed = self:RemoveCC(timerId, true)
			if wasOwn and removed and HandleOwnCCBreak then
				HandleOwnCCBreak(removed, nil, nil, false)
				if not self:GetCCByCaster(playerGUID) and Afterlife.Clear3DFrame then
					Afterlife:Clear3DFrame()
				end
			end
		end
	end
end

--- Sends a message to group chat or prints locally when solo.
--- @param msg string|nil message body (without addon header)
local function AnnounceToChat(msg)
	if not msg or msg == "" then
		return
	end
	local channel = GetAnnounceChatChannel()
	if channel ~= "SOLO" then
		SendChatMessage(L("CHAT_HEADER") .. msg, channel)
	else
		DEFAULT_CHAT_FRAME:AddMessage(L("CHAT_TITLE_SHORT") .. msg)
	end
end

--- Returns the locale folder name used for localized sound files.
--- @return string locale code (e.g. enUS), with fallback for unsupported locales
local function GetLocaleSoundFolder()
	local locale = (GetLocale and GetLocale()) or LOCALE_SOUND_FALLBACK
	if locale == "esMX" then
		locale = "esES"
	end
	if not LOCALE_SOUND_FOLDERS[locale] then
		locale = LOCALE_SOUND_FALLBACK
	end
	return locale
end

--- Plays a localized sound file, trying .ogg then .mp3 extension.
--- @param name string sound file base name without extension
local function PlayLocaleSoundFile(name)
	local path = SOUNDS_ROOT .. GetLocaleSoundFolder() .. "\\" .. name
	if not PlaySoundFile(path .. ".ogg", "Master") then
		PlaySoundFile(path .. ".mp3", "Master")
	end
end

--- Plays a localized sound by base file name.
--- @param name string|nil sound file base name without extension
function Afterlife:PlayLocaleSound(name)
	if name and name ~= "" then
		PlayLocaleSoundFile(name)
	end
end

--- Plays CC break sound followed by the localized "target free" voice line.
function Afterlife:PlayBreakSounds()
	PlaySoundFile(SOUND_BREAK, "Master")
	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, function()
			PlayLocaleSoundFile("targetfree")
		end)
	else
		PlayLocaleSoundFile("targetfree")
	end
end

--- Plays escalating PvP killing-blow voice lines when the player gets a kill.
--- @param sourceGUID string|nil killer unit GUID
--- @param destFlags number|nil victim COMBATLOG_OBJECT flags
local function HandleKillingBlow(sourceGUID, destFlags)
	if not IsCCEnabled() then
		return
	end
	if not sourceGUID or sourceGUID ~= playerGUID then
		return
	end
	local db = AfterlifeGlobalSettings
	if not db or not db.playPvPKillingBlowSounds then
		return
	end
	local isPlayerVictim = bit.band(destFlags or 0, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0
	if not isPlayerVictim and not db.playNPCKillingBlowSounds then
		return
	end
	local soundpack = (db.playPvPKillingBlowSoundpack == 1 or db.playPvPKillingBlowSoundpack == 2) and db.playPvPKillingBlowSoundpack or 1
	local now = GetTime()
	if now - killingBlowState.lastPlayTime > 60 then
		killingBlowState.currentIndex = 1
	end
	local soundPaths = AfterlifePvPSoundPaths
	local voicepack = soundPaths and (soundpack == 2 and soundPaths.killingBlowVoicepack2 or soundPaths.killingBlowVoicepack1)
	local path = voicepack and voicepack[killingBlowState.currentIndex]
	if path then
		PlaySoundFile(path, "Master")
		killingBlowState.currentIndex = killingBlowState.currentIndex + 1
		if killingBlowState.currentIndex > 6 then
			killingBlowState.currentIndex = 6
		end
		killingBlowState.lastPlayTime = now
	end
end

--- Plays apply/renew/break sounds for the player's own CC events when enabled.
--- @param kind string sound kind: "break", "renewed", or "applied"
local function PlayCCSound(kind)
	if not AfterlifeGlobalSettings.playSoundOnMyCCEvents then
		return
	end
	if kind == "break" then
		PlaySoundFile(SOUND_BREAK, "Master")
		PlayLocaleSoundFile("targetfree")
		return
	end
	local path = (kind == "renewed" and SOUND_RENEWED) or SOUND_APPLIED
	if path then
		PlaySoundFile(path, "Master")
	end
end

--- Plays countdown voice lines at 15s and 1-10s for the player's own CC.
--- @param entry table CC entry for the player's active crowd control
--- @param remaining number seconds remaining on the CC
local function UpdateCCCountdownSounds(entry, remaining)
	if not entry or entry.casterGuid ~= playerGUID then
		return
	end
	if not AfterlifeGlobalSettings.playSoundOnMyCCEvents then
		return
	end

	local second = math.floor(remaining+1)
	if second == 15 then
		if ccCountdownLastSecond[entry.timerId] == second then
			return
		end
		ccCountdownLastSecond[entry.timerId] = second
		PlayLocaleSoundFile("15secremain")
	elseif second >= 1 and second <= 10 then
		if ccCountdownLastSecond[entry.timerId] == second then
			return
		end
		ccCountdownLastSecond[entry.timerId] = second
		PlayLocaleSoundFile(tostring(second))
	end
end

--- Builds a chat label for a CC target, including raid icon when in a group channel.
--- @param entry table CC entry with mobName and optional raidIconChat
--- @return string formatted target label
local function CCTargetLabel(entry)
	local channel = GetAnnounceChatChannel()
	local raidIcon = (channel ~= "SOLO") and (entry.raidIconChat or "") or ""
	return raidIcon .. (entry.mobName or "Unknown")
end

--- Builds a chat label for an interrupt target with optional raid icon prefix.
--- @param destName string|nil interrupted unit name
--- @param destRaidFlags number|nil COMBATLOG_OBJECT raid target flags
--- @return string formatted target label
local function InterruptTargetLabel(destName, destRaidFlags)
	local channel = GetAnnounceChatChannel()
	local _, raidChat = GetRaidIconInfo(destRaidFlags)
	local raidIcon = (channel ~= "SOLO") and raidChat or ""
	return raidIcon .. (destName or "Unknown")
end

--- Announces the player's spell interrupt to chat when the setting is enabled.
--- @param destName string|nil interrupted unit name
--- @param destRaidFlags number|nil COMBATLOG_OBJECT raid target flags
--- @param interruptedSpellName string|nil name of the spell that was interrupted
--- @param interruptSpellId number|nil interrupting spell ID
--- @param interruptSpellName string|nil interrupting spell name
local function AnnounceMyInterrupt(destName, destRaidFlags, interruptedSpellName, interruptSpellId, interruptSpellName)
	if not AfterlifeGlobalSettings.announceMyInterrupts then
		return
	end
	local targetLabel = InterruptTargetLabel(destName, destRaidFlags)
	local interruptedLabel = interruptedSpellName or "Unknown"
	local msg
	if interruptSpellId or interruptSpellName then
		local interruptLink = GetSpellLink(interruptSpellId) or interruptSpellName
		msg = L("AFTERLIFE_INTERRUPT_SPELL", targetLabel, interruptedLabel, interruptLink)
	else
		msg = L("AFTERLIFE_INTERRUPT", targetLabel, interruptedLabel)
	end
	AnnounceToChat(msg)
end

--- Announces and plays sounds for the player's CC apply or renew event.
--- @param entry table CC entry cast by the player
--- @param isRenewal boolean true if the CC was refreshed rather than newly applied
local function AnnounceCCEvent(entry, isRenewal)
	if not entry or entry.casterGuid ~= playerGUID then
		return
	end
	local spellLink = GetSpellLink(entry.spellId) or entry.spellName
	local targetLabel = CCTargetLabel(entry)
	local db = AfterlifeGlobalSettings
	if isRenewal then
		if db.announceMyCCRenews then
			AnnounceToChat(L("AFTERLIFE_RENEWED", spellLink, targetLabel, entry.duration))
		end
		PlayCCSound("renewed")
	else
		if db.announceMyCCApply then
			AnnounceToChat(L("AFTERLIFE_APPLIED", spellLink, targetLabel, entry.duration))
		end
		PlayCCSound("applied")
	end
end

--- Announces the player's CC break to chat, optionally naming the breaker.
--- @param entry table CC entry that was broken
--- @param breakerName string|nil name of the player who broke the CC
--- @param breakerSpellId number|nil spell ID used to break the CC
local function AnnounceCCBreak(entry, breakerName, breakerSpellId)
	if not entry or entry.casterGuid ~= playerGUID then
		return
	end
	if not AfterlifeGlobalSettings.announceMyCCBreaks then
		return
	end
	local spellLink = GetSpellLink(entry.spellId) or entry.spellName
	local targetLabel = CCTargetLabel(entry)
	local msg
	if breakerName and breakerSpellId then
		local breakLink = GetSpellLink(breakerSpellId) or tostring(breakerSpellId)
		msg = L("AFTERLIFE_BROKENPLAYER", spellLink, targetLabel, Afterlife:StripRealmName(breakerName), breakLink)
	else
		msg = L("AFTERLIFE_BROKENNORM", spellLink, targetLabel)
	end
	AnnounceToChat(msg)
end

--- Broadcasts a CC sync addon message to the current group channel.
--- @param cmd string sync command code (ACCA, ACCR, or ACCF)
--- @param entry table CC entry data to serialize into the packet
local function SyncCCCommand(cmd, entry)
	if not entry or chatChannel == "SOLO" then
		return
	end
	local packet = table.concat({
		ADDON_CMD_PREFIX,
		ADDON_VERSION,
		Afterlife.Version or ADDON_VERSION,
		cmd,
		entry.mobGuid,
		entry.mobName or "Unknown",
		entry.casterGuid,
		entry.casterName,
		tostring(entry.spellId),
		entry.spellName,
		tostring(entry.raidIconIndex or 0),
		tostring(entry.destRaidFlags or 0),
	}, "¦")
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		C_ChatInfo.SendAddonMessage(ADDON_CMD_HEADER, packet, chatChannel)
	elseif SendAddonMessage then
		SendAddonMessage(ADDON_CMD_HEADER, packet, chatChannel)
	end
end

--- Handles feedback when the player's own CC ends: announce, sound, popup, and sync.
--- @param entry table CC entry that was broken or expired
--- @param breakerName string|nil name of the player who broke the CC
--- @param breakerSpellId number|nil spell ID used to break the CC
--- @param fromSync boolean true when triggered from a group sync message
HandleOwnCCBreak = function(entry, breakerName, breakerSpellId, fromSync)
	AnnounceCCBreak(entry, breakerName, breakerSpellId)
	PlayCCSound("break")
	if Afterlife_ShowPopup then
		Afterlife_ShowPopup("brokenfree")
	end
	if Afterlife.FlashBorderOnCCBreak then
		Afterlife:FlashBorderOnCCBreak()
	end
	if not fromSync then
		SyncCCCommand("ACCF", entry)
	end
end

--- Applies diminish returns to spell duration and tracks DR state for a mob.
--- @param mobGuid string target unit GUID
--- @param mobName string target display name
--- @param spellDuration number base CC duration in seconds
--- @param spellIcon string|nil spell icon file path
--- @param raidIconIndex number|nil raid target icon index for the mob
--- @return number effective duration after DR halving, if applicable
function Afterlife:UpdateDRDuration(mobGuid, mobName, spellDuration, spellIcon, raidIconIndex)
	if mobGuid == playerGUID then
		return spellDuration
	end
	self:PurgeExpiredDR()
	for _, value in ipairs(AfterlifeDiminishTimers) do
		if value.mobGuid == mobGuid then
			local halved = value.duration / 2
			value.duration = halved
			value.lastDRTime = GetTime()
			return halved
		end
	end
	AfterlifeDiminishTimers[#AfterlifeDiminishTimers + 1] = {
		mobGuid = mobGuid,
		mobName = mobName,
		lastDRTime = GetTime(),
		duration = spellDuration,
		icon = spellIcon,
		raidIconIndex = raidIconIndex or 0,
	}
	return spellDuration
end

--- Starts a DR cooldown timer bar when CC on a mob breaks.
--- @param mobGuid string target unit GUID
function Afterlife:DRTimerOnBreak(mobGuid)
	if mobGuid == playerGUID then
		return
	end
	local NT = self.NaturTimers
	if not NT then
		return
	end
	for _, value in ipairs(AfterlifeDiminishTimers) do
		if value.mobGuid == mobGuid then
			value.lastDRTime = GetTime()
			self:EnsureTimerGroups()
			NT:StartTimer(CC_GROUP, self:MakeDRTimerId(value.mobGuid), DR_WINDOW, {
				label = (value.mobName or "Unknown") .. " (DR)",
				reverse = true,
				iconLeft = value.icon,
			})
			return
		end
	end
end

--- Removes DR tracking entries and timer bars older than the DR window.
function Afterlife:PurgeExpiredDR()
	local NT = self.NaturTimers
	for i = #AfterlifeDiminishTimers, 1, -1 do
		local value = AfterlifeDiminishTimers[i]
		if GetTime() - value.lastDRTime > 17 then
			if NT then
				NT:StopTimer(CC_GROUP, Afterlife:MakeDRTimerId(value.mobGuid))
			end
			table.remove(AfterlifeDiminishTimers, i)
		end
	end
end

--- Removes pending freezing trap timers and bars for a caster GUID.
--- @param sourceGuid string hunter caster GUID
local function RemoveTrapTimer(sourceGuid)
	for i = #AfterlifeTrapTimers, 1, -1 do
		if AfterlifeTrapTimers[i].casterGuid == sourceGuid then
			StopCCTimerBar(sourceGuid)
			table.remove(AfterlifeTrapTimers, i)
		end
	end
end

--- Records a pending freezing trap placement and starts its timer bar.
--- @param sourceGuid string hunter caster GUID
--- @param spellId number trap placement spell ID
local function AddTrapTimer(sourceGuid, spellId)
	Afterlife:PurgeExpiredTrapTimers()
	local icon = select(3, GetSpellInfo(spellId))
	AfterlifeTrapTimers[#AfterlifeTrapTimers + 1] = {
		spellId = spellId,
		duration = TRAP_PENDING_DURATION,
		casterGuid = sourceGuid,
		appliedAt = GetTime(),
		icon = icon,
	}
	Afterlife:EnsureTimerGroups()
	local NT = Afterlife.NaturTimers
	if NT then
		NT:StartTimer(CC_GROUP, sourceGuid, TRAP_PENDING_DURATION, {
			label = L("TRAP_SET_LABEL"),
			reverse = true,
			iconLeft = icon,
		})
	end
end

--- Removes expired pending trap timers and clears the 3D frame when the player's trap expires.
function Afterlife:PurgeExpiredTrapTimers()
	for i = #AfterlifeTrapTimers, 1, -1 do
		local trap = AfterlifeTrapTimers[i]
		if GetTime() - trap.appliedAt > trap.duration then
			if trap.casterGuid == playerGUID and Afterlife.Clear3DFrame then
				Afterlife:Clear3DFrame()
			end
			StopCCTimerBar(trap.casterGuid)
			table.remove(AfterlifeTrapTimers, i)
		end
	end
end

--- Returns whether a pending freezing trap timer exists for a caster.
--- @param sourceGuid string hunter caster GUID
--- @return boolean true if a trap is pending
local function IsTrapActive(sourceGuid)
	for _, trap in ipairs(AfterlifeTrapTimers) do
		if trap.casterGuid == sourceGuid then
			return true
		end
	end
	return false
end

--- Finds a unit token (focus/target/mouseover) matching the given GUID.
--- @param mobGuid string|nil unit GUID to resolve
--- @return string|nil unit token name, or nil if not found
local function ResolveUnitTokenForGuid(mobGuid)
	if not mobGuid then
		return nil
	end
	if UnitExists("focus") and UnitGUID("focus") == mobGuid then
		return "focus"
	end
	if UnitExists("target") and UnitGUID("target") == mobGuid then
		return "target"
	end
	if UnitExists("mouseover") and UnitGUID("mouseover") == mobGuid then
		return "mouseover"
	end
	return nil
end

--- Updates or shows the 3D controlled-unit frame for the player's own CC.
--- @param entry table CC entry cast by the player
--- @param keepExistingModel boolean when true, only updates name/timer without rebinding model
local function Show3DForCC(entry, keepExistingModel)
	if not entry or entry.casterGuid ~= playerGUID then
		return
	end
	local remaining = Afterlife:GetCCRemaining(entry)
	if keepExistingModel and Afterlife.Update3DCC then
		-- Cast already captured the pre-CC model; only update name and timer.
		Afterlife:Update3DCC(entry.mobName, remaining)
		return
	end
	local unit = entry.displayUnit or pendingCast3DUnit or ResolveUnitTokenForGuid(entry.mobGuid)
	if unit then
		entry.displayUnit = unit
		if Afterlife.Bind3DUnit then
			Afterlife:Bind3DUnit(unit)
		end
	end
	if unit and Afterlife.Show3DControlledUnit then
		Afterlife:Show3DControlledUnit(unit, entry.mobName, remaining)
	elseif Afterlife.Update3DCC then
		Afterlife:Update3DCC(entry.mobName, remaining)
	end
end

--- Refreshes the 3D frame for the player's active CC when target frame is enabled.
function Afterlife:RefreshOwnCC3DFrame()
	local entry = self:GetCCByCaster(playerGUID)
	if not entry then
		return
	end
	local tf = self.GetTargetFrameSettings and self:GetTargetFrameSettings()
	if not tf or tf.active == false then
		return
	end
	Show3DForCC(entry, entry.displayUnit ~= nil)
end

--- Adds a new CC entry or renews an existing one and starts its timer bar.
--- @param mobGuid string target unit GUID
--- @param mobName string target display name
--- @param casterGuid string caster unit GUID
--- @param casterName string caster display name
--- @param spellId number crowd-control spell ID
--- @param spellName string crowd-control spell name
--- @param duration number CC duration in seconds
--- @param opts table|nil optional fields: breakable, raidIconIndex, raidIconChat, destRaidFlags, icon
--- @return table|nil CC entry table, or nil if mob name invalid
--- @return boolean isRenewal true if an existing entry was refreshed
function Afterlife:AddOrRenewCC(mobGuid, mobName, casterGuid, casterName, spellId, spellName, duration, opts)
	if not mobGuid or not mobName or mobName == "" then
		return nil, false
	end
	opts = opts or {}
	self:PurgeExpiredCC()
	local timerId = self:MakeCCTimerId(mobGuid, spellId)
	local oldEntry = AfterlifeControlledCC[timerId]
	local isRenewal = oldEntry ~= nil
	local entry = {
		timerId = timerId,
		mobGuid = mobGuid,
		mobName = mobName,
		spellId = spellId,
		spellName = spellName,
		casterGuid = casterGuid,
		casterName = Afterlife:StripRealmName(casterName),
		appliedAt = GetTime(),
		duration = duration,
		breakable = opts.breakable,
		raidIconIndex = opts.raidIconIndex or 0,
		raidIconChat = opts.raidIconChat or "",
		destRaidFlags = opts.destRaidFlags or 0,
		icon = opts.icon,
	}
	if oldEntry and oldEntry.displayUnit then
		entry.displayUnit = oldEntry.displayUnit
	end
	ClearCCCountdownSound(timerId)
	AfterlifeControlledCC[timerId] = entry
	StartCCTimerBar(entry)
	if casterGuid == playerGUID then
		local keepModel = isRenewal or pendingCast3DUnit ~= nil
		Show3DForCC(entry, keepModel)
		pendingCast3DUnit = nil
	end
	return entry, isRenewal
end

--- Handles non-instant CC application from combat log or group sync.
--- @param mobGuid string target unit GUID
--- @param mobName string target display name
--- @param casterGuid string caster unit GUID
--- @param casterName string caster display name
--- @param spellId number crowd-control spell ID
--- @param spellName string crowd-control spell name
--- @param destRaidFlags number COMBATLOG_OBJECT raid target flags
--- @param fromSync boolean|nil true when processing a group sync message
local function HandleCCApply(mobGuid, mobName, casterGuid, casterName, spellId, spellName, destRaidFlags, fromSync)
	if not IsCCEnabled() then
		return
	end
	local entryData, duration, icon = GetCCSpellDetails(spellId, mobGuid)
	if not entryData then
		return
	end
	if entryData.instant then
		return
	end
	local raidIndex, raidChat = GetRaidIconInfo(destRaidFlags)
	duration = duration or entryData.duration
	if entryData.diminishReturns and IsPlayerGuid(mobGuid) then
		duration = Afterlife:UpdateDRDuration(mobGuid, mobName, duration, icon, raidIndex)
	end
	local entry, isRenewal = Afterlife:AddOrRenewCC(mobGuid, mobName, casterGuid, casterName, spellId, spellName, duration, {
		breakable = entryData.breakable,
		raidIconIndex = raidIndex,
		raidIconChat = raidChat,
		destRaidFlags = destRaidFlags,
		icon = icon,
	})
	if not entry then
		return
	end
	if casterGuid == playerGUID and not fromSync then
		AnnounceCCEvent(entry, isRenewal)
		SyncCCCommand(isRenewal and "ACCR" or "ACCA", entry)
	end
	if IsTrapEffectSpell(entryData) then
		RemoveTrapTimer(casterGuid)
	end
end

--- Handles instant CC spells (e.g. stuns) from combat log or group sync.
--- @param mobGuid string target unit GUID
--- @param mobName string target display name
--- @param casterGuid string caster unit GUID
--- @param casterName string caster display name
--- @param spellId number crowd-control spell ID
--- @param spellName string crowd-control spell name
--- @param destRaidFlags number COMBATLOG_OBJECT raid target flags
--- @param fromSync boolean|nil true when processing a group sync message
local function HandleInstantCC(mobGuid, mobName, casterGuid, casterName, spellId, spellName, destRaidFlags, fromSync)
	fromSync = fromSync and true or false
	if not IsCCEnabled() or not mobGuid or not mobName or mobName == "" then
		return
	end
	local entryData, duration, icon = GetCCSpellDetails(spellId, mobGuid)
	if not entryData or not entryData.instant then
		return
	end
	local raidIndex, raidChat = GetRaidIconInfo(destRaidFlags)
	if entryData.diminishReturns and IsPlayerGuid(mobGuid) then
		duration = Afterlife:UpdateDRDuration(mobGuid, mobName, duration, icon, raidIndex)
	end
	local entry, isRenewal = Afterlife:AddOrRenewCC(mobGuid, mobName, casterGuid, casterName, spellId, spellName, duration, {
		breakable = entryData.breakable,
		raidIconIndex = raidIndex,
		raidIconChat = raidChat,
		destRaidFlags = destRaidFlags,
		icon = icon,
	})
	if not entry then
		return
	end
	if casterGuid == playerGUID and not fromSync then
		AnnounceCCEvent(entry, isRenewal)
		SyncCCCommand(isRenewal and "ACCR" or "ACCA", entry)
		Show3DForCC(entry, isRenewal)
	end
end

--- Handles CC aura refresh events by delegating to HandleCCApply.
--- @param mobGuid string target unit GUID
--- @param mobName string target display name
--- @param casterGuid string caster unit GUID
--- @param casterName string caster display name
--- @param spellId number crowd-control spell ID
--- @param spellName string crowd-control spell name
--- @param destRaidFlags number COMBATLOG_OBJECT raid target flags
--- @param fromSync boolean|nil true when processing a group sync message
local function HandleCCRefresh(mobGuid, mobName, casterGuid, casterName, spellId, spellName, destRaidFlags, fromSync)
	HandleCCApply(mobGuid, mobName, casterGuid, casterName, spellId, spellName, destRaidFlags, fromSync)
end

--- Removes a CC entry on break/expiry and triggers DR and own-CC-break handling.
--- @param mobGuid string target unit GUID
--- @param spellId number|nil crowd-control spell ID
--- @param breakerName string|nil name of the player who broke the CC
--- @param breakerSpellId number|nil spell ID used to break the CC
--- @param fromSync boolean|nil true when processing a group sync message
local function HandleCCBreak(mobGuid, spellId, breakerName, breakerSpellId, fromSync)
	local timerId = spellId and Afterlife:MakeCCTimerId(mobGuid, spellId) or nil
	local entry = timerId and Afterlife:GetCC(timerId) or nil
	if not entry then
		for id, cc in pairs(AfterlifeControlledCC) do
			if cc.mobGuid == mobGuid then
				entry = cc
				timerId = id
				break
			end
		end
	end
	if not entry or not timerId then
		return
	end
	local wasOwn = entry.casterGuid == playerGUID
	Afterlife:RemoveCC(timerId, true)
	Afterlife:DRTimerOnBreak(mobGuid)
	if wasOwn then
		HandleOwnCCBreak(entry, breakerName, breakerSpellId, fromSync)
	end
	if not Afterlife:GetCCByCaster(playerGUID) and Afterlife.Clear3DFrame then
		Afterlife:Clear3DFrame()
	end
end

--- Applies or removes CC state received from a group addon sync message.
--- @param cmd string sync command code (ACCA, ACCR, or ACCF)
--- @param mobGuid string target unit GUID
--- @param mobName string target display name
--- @param casterGuid string caster unit GUID
--- @param casterName string caster display name
--- @param spellId number crowd-control spell ID
--- @param spellName string crowd-control spell name
--- @param destRaidFlags number COMBATLOG_OBJECT raid target flags
local function HandleCCFromSync(cmd, mobGuid, mobName, casterGuid, casterName, spellId, spellName, destRaidFlags)
	if mobGuid == playerGUID then
		return
	end
	if cmd == "ACCF" then
		HandleCCBreak(mobGuid, nil, nil, nil, true)
		return
	end
	if not IsGroupCaster(casterGuid, casterName) then
		return
	end
	local entryData = Afterlife_GetCCSpell(spellId)
	if entryData and entryData.instant then
		HandleInstantCC(mobGuid, mobName, casterGuid, casterName, spellId, spellName, tonumber(destRaidFlags) or 0, true)
	else
		HandleCCApply(mobGuid, mobName, casterGuid, casterName, spellId, spellName, tonumber(destRaidFlags) or 0, true)
	end
end

--- Dispatches combat log events for CC tracking, traps, interrupts, and kills.
local function ProcessCombatLog()
	if not IsCCEnabled() then
		return
	end
	UpdateChatChannel()
	local timestamp, subEvent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
		destGUID, destName, destFlags, destRaidFlags, spellId, spellName = CombatLogGetCurrentEventInfo()

	if not spellId then
		return
	end

	local entryData = Afterlife_GetCCSpell and Afterlife_GetCCSpell(spellId)
	if entryData and AfterlifeGlobalSettings.debugMode then
		Afterlife:DebugPrint(subEvent .. " spell=" .. spellId .. " src=" .. tostring(sourceName) .. " dst=" .. tostring(destName))
	end

	if subEvent == "SPELL_CAST_START" then
		if sourceGUID == playerGUID and entryData and not IsTrapPlacementSpell(entryData) then
			if Afterlife.Show3DControlledUnit and Afterlife:GetTargetFrameSettings().active ~= false then
				local unit
				if UnitExists("target") then
					unit = "target"
				elseif UnitExists("focus") then
					unit = "focus"
				end
				if unit then
					local unitGuid = UnitGUID(unit)
					local existingCC = unitGuid and Afterlife:GetCCByMobAndSpell(unitGuid, spellId)

					if existingCC and existingCC.casterGuid == playerGUID then
						if Afterlife.Update3DCC then
							Afterlife:Update3DCC(existingCC.mobName, Afterlife:GetCCRemaining(existingCC))
							if Afterlife.Update3DFrame then
								Afterlife:Update3DFrame(L("CASTING_LABEL"), 0)
							end
						elseif Afterlife.Update3DFrame then
							Afterlife:Update3DFrame(L("CASTING_LABEL"), 0)
						end
					else
						pendingCast3DUnit = unit
						Afterlife:Show3DControlledUnit(unit, UnitName(unit), 0)
						if Afterlife.Update3DFrame then
							Afterlife:Update3DFrame(L("CASTING_LABEL"), 0)
						end
					end
				end
			end
		end
		return
	end

	if subEvent == "SPELL_CAST_FAILED" then
		if sourceGUID == playerGUID and not Afterlife:GetCCByCaster(playerGUID) and not IsTrapActive(playerGUID) and not pendingCast3DUnit then
			if Afterlife.Clear3DFrame then
				Afterlife:Clear3DFrame()
			end
		end
		return
	end

	if subEvent == "SPELL_CAST_SUCCESS" then
		if entryData and IsTrapPlacementSpell(entryData) and sourceGUID == playerGUID then
			AddTrapTimer(sourceGUID, spellId)
			if Afterlife.Show3DControlledUnit and Afterlife:GetTargetFrameSettings().active ~= false then
				local unit = targetGuid and "target" or "player"
				if UnitExists(unit) then
					Afterlife:Show3DControlledUnit(unit, UnitName(unit) or L("TRAP_SET_LABEL"), TRAP_PENDING_DURATION)
					if Afterlife.Update3DFrame then
						Afterlife:Update3DFrame(L("TRAP_SET_LABEL"), TRAP_PENDING_DURATION)
					end
				end
			end
			return
		end
		return
	end

	if subEvent == "SPELL_AURA_APPLIED" then
		if entryData then
			local handler = entryData.instant and HandleInstantCC or HandleCCApply
			if sourceGUID == playerGUID then
				handler(destGUID, destName, sourceGUID, sourceName, spellId, spellName, destRaidFlags)
			elseif destGUID ~= playerGUID and IsGroupCaster(sourceGUID, sourceName) then
				handler(destGUID, destName, sourceGUID, sourceName, spellId, spellName, destRaidFlags)
			end
		end
		return
	end

	if subEvent == "SPELL_AURA_REFRESH" then
		if entryData and IsPlayerGuid(sourceGUID) then
			if sourceGUID == playerGUID then
				HandleCCRefresh(destGUID, destName, sourceGUID, sourceName, spellId, spellName, destRaidFlags)
			elseif IsGroupCaster(sourceGUID, sourceName) then
				HandleCCRefresh(destGUID, destName, sourceGUID, sourceName, spellId, spellName, destRaidFlags)
			end
		end
		return
	end

	if subEvent == "SPELL_AURA_REMOVED" or subEvent == "SPELL_AURA_BROKEN" or subEvent == "SPELL_AURA_BROKEN_SPELL" then
		if entryData or Afterlife:GetCCByMobAndSpell(destGUID, spellId) then
			local breakerSpellId = (subEvent == "SPELL_AURA_BROKEN_SPELL") and select(15, CombatLogGetCurrentEventInfo()) or nil
			local breakerName = (subEvent == "SPELL_AURA_BROKEN_SPELL") and sourceName or nil
			HandleCCBreak(destGUID, spellId, breakerName, breakerSpellId)
		end
		return
	end

	if subEvent == "SPELL_INTERRUPT" then
		if sourceGUID == playerGUID then
			local extraSpellName = select(16, CombatLogGetCurrentEventInfo())
			AnnounceMyInterrupt(destName, destRaidFlags, extraSpellName, spellId, spellName)
		end
		return
	end

	if subEvent == "SPELL_MISSED" then
		local missType = select(15, CombatLogGetCurrentEventInfo())
		if sourceGUID == playerGUID and entryData and missType == "IMMUNE" and AfterlifeGlobalSettings.announceMyCCImmune then
			local spellLink = GetSpellLink(spellId) or spellName
			local targetLabel = destName or ""
			AnnounceToChat(L("AFTERLIFE_FAILED", spellLink, targetLabel))
			if AfterlifeGlobalSettings.graphicalPopups and Afterlife_ShowPopup then
				Afterlife_ShowPopup("immune")
			end
		end
		return
	end

	if subEvent == "PARTY_KILL" then
		HandleKillingBlow(sourceGUID, destFlags)
		Afterlife:RemoveCCByMob(destGUID)
		return
	end

	if subEvent == "UNIT_DIED" then
		Afterlife:RemoveCCByMob(destGUID)
	end
end

--- Parses and handles incoming CC sync addon messages from group members.
--- @param prefix string addon message prefix
--- @param message string serialized sync packet
--- @param channel string chat channel the message arrived on
--- @param sender string sender player name
local function ProcessAddonMessage(prefix, message, channel, sender)
	if prefix ~= ADDON_CMD_HEADER or not message then
		return
	end
	local player = UnitName("player")
	if sender and player and Afterlife:StripRealmName(sender) == Afterlife:StripRealmName(player) then
		return
	end
	local pktType, pktVer, pktBuild, pktCmd, pktData1, pktData2, pktData3, pktData4, pktData5, pktData6, pktData7, pktData8 =
		strsplit("¦", message, 12)
	if pktType ~= ADDON_CMD_PREFIX or not ADDON_CMD_LIST[pktCmd] then
		return
	end
	HandleCCFromSync(pktCmd, pktData1, pktData2, pktData3, pktData4, tonumber(pktData5), pktData6, tonumber(pktData8) or 0)
end

--- OnUpdate handler: purges expired state and updates own-CC sounds and 3D frame.
--- @param _ any unused frame reference
--- @param elapsed number seconds since last update
local function OnCCUpdate(_, elapsed)
	if not IsCCEnabled() then
		return
	end
	Afterlife:PurgeExpiredCC()
	Afterlife:PurgeExpiredDR()
	Afterlife:PurgeExpiredTrapTimers()

	local ownCC = Afterlife:GetCCByCaster(playerGUID)
	if ownCC then
		local remaining = Afterlife:GetCCRemaining(ownCC)
		if remaining > 0 then
			UpdateCCCountdownSounds(ownCC, remaining)
			if Afterlife.Update3DCC then
				Afterlife:Update3DCC(ownCC.mobName, remaining)
			elseif Afterlife.Update3DFrame then
				Afterlife:Update3DFrame(ownCC.mobName, remaining)
			end
		elseif not IsTrapActive(playerGUID) then
			if Afterlife.Clear3DFrame then
				Afterlife:Clear3DFrame()
			end
		end
	end

end

--- Caches the current target unit GUID.
local function CacheTargetGuid()
	targetGuid = UnitGUID("target")
end

--- Caches the current focus unit GUID, clearing it when focus is absent.
local function CacheFocusGuid()
	if UnitGUID("focus") then
		focusGuid = UnitGUID("focus")
	else
		focusGuid = nil
	end
end

--- Initializes addon state on player login: settings, events, timers, and load message.
local function OnPlayerLogin()
	if not Afterlife.NaturTimers then
		return
	end
	if Afterlife_Options_InitGlobalSettings then
		Afterlife_Options_InitGlobalSettings()
	end
	if Afterlife.InitCharacterSettings then
		Afterlife:InitCharacterSettings()
	end
	playerGUID = UnitGUID("player")
	ccReady = true
	UpdateChatChannel()
	CacheTargetGuid()
	CacheFocusGuid()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(ADDON_CMD_HEADER)
	elseif RegisterAddonMessagePrefix then
		RegisterAddonMessagePrefix(ADDON_CMD_HEADER)
	end
	Afterlife:RefreshTimerGroup()
	local charSettings = Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings()
	local enabled = charSettings and charSettings.enabled ~= false
	Afterlife:SetEnabled(enabled)
	if enabled then
		Print(L("MSG_LOADED", L("ADDON_TITLE"), ADDON_VERSION))
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnUpdate", OnCCUpdate)
eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
	if event == "ADDON_LOADED" and arg1 == addonName then
		if not InitLibraries() then
			return
		end
		if Afterlife_Options_InitGlobalSettings then
			Afterlife_Options_InitGlobalSettings()
		end
	elseif event == "PLAYER_LOGIN" then
		OnPlayerLogin()
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		ProcessCombatLog()
	elseif event == "CHAT_MSG_ADDON" then
		ProcessAddonMessage(arg1, arg2, arg3, arg4)
	elseif event == "PLAYER_TARGET_CHANGED" then
		CacheTargetGuid()
	elseif event == "PLAYER_FOCUS_CHANGED" then
		CacheFocusGuid()
	elseif event == "PLAYER_ENTERING_WORLD" then
		UpdateChatChannel()
		Afterlife:RemoveCCByCaster(playerGUID)
	end
end)

SLASH_AFTERLIFE1 = "/afterlife"
SlashCmdList["AFTERLIFE"] = function()
	if not Afterlife.NaturTimers then
		Print("|cffff0000" .. L("MSG_ADDON_INIT_FAILED") .. "|r")
		return
	end
	if Afterlife_Options_Open then
		Afterlife_Options_Open()
	end
end
