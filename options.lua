--[[
	Afterlife Crowd Control — options window and settings
]]

local CC_GROUP = "Afterlife_Controlled"
local DEFAULT_TEXTURE = "Blizzard"
local DEFAULT_FONT = "Friz Quadrata TT"
local DEFAULT_BAR_WIDTH = 250
local DEFAULT_BAR_HEIGHT = 25
local DEFAULT_SPACING = 2
local DEFAULT_3D_TARGET_FONT_SIZE = 16
local DEFAULT_3D_TIMER_FONT_SIZE = 14
local DEFAULT_3D_MODEL_SCALE = 1.10
local DEFAULT_3D_TEXT_GAP = 50
local TIMER_CONTROL_WIDTH = 210

--- Resolve a localized string via Afterlife_GetLocale, or return the key unchanged.
--- @param key string Locale key.
--- @param ... any Format arguments passed to Afterlife_GetLocale.
--- @return string
local function L(key, ...)
	if Afterlife_GetLocale then
		return Afterlife_GetLocale(key, ...)
	end
	return key
end

--- Deep-copy a table, recursing into nested non-array tables.
--- @param src table|any Value to copy.
--- @return table|any Copied value or primitive.
local function CopyTable(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for key, value in pairs(src) do
		if type(value) == "table" and not (value[1] or value[0]) then
			dst[key] = CopyTable(value)
		else
			dst[key] = value
		end
	end
	return dst
end

--- Recursively fill nil keys in target from defaults without overwriting existing values.
--- @param target table Settings table to update in place.
--- @param defaults table Default values to merge in.
local function MergeDefaults(target, defaults)
	if type(defaults) ~= "table" then
		return
	end
	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" and not (value[1] or value[0]) then
				target[key] = {}
				MergeDefaults(target[key], value)
			else
				target[key] = value
			end
		elseif type(target[key]) == "table" and type(value) == "table" and not (value[1] or value[0]) then
			MergeDefaults(target[key], value)
		end
	end
end

--- Build the default account-wide Afterlife options table.
--- @return table
local function GetDefaultGlobalOptions()
	return {
		showAnchors = true,
		debugMode = false,
		playSoundOnMyCCEvents = true,
		announceMyCCApply = true,
		announceMyCCRenews = true,
		announceMyCCBreaks = true,
		announceMyCCImmune = true,
		announceMyInterrupts = true,
		announceInBattlegrounds = false,
		playPvPKillingBlowSounds = true,
		playNPCKillingBlowSounds = false,
		playPvPKillingBlowSoundpack = 1,
		graphicalPopups = true,
		flashBorderOnCCBreak = true,
		showRaidIcons = true,
		playOptionsWelcomeSound = true,
		groups = {
			[CC_GROUP] = {
				title = L("CROWD_CONTROLS"),
				texture = DEFAULT_TEXTURE,
				font = DEFAULT_FONT,
				fontSize = 12,
				fontFlags = "",
				rightJustifyTime = true,
				point = "CENTER",
				relativePoint = "CENTER",
				x = 320,
				y = -120,
				width = DEFAULT_BAR_WIDTH,
				height = DEFAULT_BAR_HEIGHT,
				spacing = DEFAULT_SPACING,
				growthDirection = "DOWN",
				sortOrder = "remaining_asc",
			},
		},
	}
end

--- Build the default per-character options table.
--- @return table
local function GetDefaultCharacterOptions()
	return {
		enabled = true,
	}
end

--- Ensure AfterlifeGlobalSettings contains all default account-wide option keys.
function Afterlife_Options_InitGlobalSettings()
	local db = AfterlifeGlobalSettings
	MergeDefaults(db, GetDefaultGlobalOptions())
	if Afterlife and Afterlife.Version then
		db.version = Afterlife.Version
	end
end

--- Return the initialized account-wide settings table.
--- @return table
function Afterlife_Options_GetGlobal()
	Afterlife_Options_InitGlobalSettings()
	return AfterlifeGlobalSettings
end

--- Push reset global and character settings into live addon modules and UI.
local function ApplyOptionsAfterReset()
	local db = AfterlifeGlobalSettings
	local charSettings = Afterlife and Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings()

	if Afterlife and Afterlife.SetEnabled and charSettings then
		Afterlife:SetEnabled(charSettings.enabled ~= false)
	end
	if Afterlife and Afterlife.SetPopupEnabled then
		Afterlife:SetPopupEnabled(db.graphicalPopups ~= false)
	end
	if Afterlife and Afterlife.SetBorderFlashEnabled then
		Afterlife:SetBorderFlashEnabled(db.flashBorderOnCCBreak and true or false)
	end
	if Afterlife and Afterlife.SetAnchorsUnlocked then
		Afterlife:SetAnchorsUnlocked(db.showAnchors and true or false)
	end
	if Afterlife and Afterlife.RefreshTimerGroup then
		Afterlife:RefreshTimerGroup()
	end
	if Afterlife and Afterlife.ApplyTargetFrameSettings then
		Afterlife:ApplyTargetFrameSettings()
	end
	if Afterlife and Afterlife.RefreshTestTimersIfActive then
		Afterlife:RefreshTestTimersIfActive()
	end
end

--- Reset global and current-character settings to factory defaults and reapply them.
function Afterlife_Options_ResetToDefaults()
	wipe(AfterlifeGlobalSettings)
	for key, value in pairs(GetDefaultGlobalOptions()) do
		if type(value) == "table" and not (value[1] or value[0]) then
			AfterlifeGlobalSettings[key] = CopyTable(value)
		else
			AfterlifeGlobalSettings[key] = value
		end
	end
	if Afterlife and Afterlife.Version then
		AfterlifeGlobalSettings.version = Afterlife.Version
	end

	if Afterlife and Afterlife.InitCharacterSettings then
		Afterlife:InitCharacterSettings()
	end

	local realm = GetRealmName and GetRealmName()
	local char = UnitName and UnitName("player")
	if realm and char then
		if not AfterlifeCharacterSettings[realm] then
			AfterlifeCharacterSettings[realm] = {}
		end
		local charDefaults = CopyTable(GetDefaultCharacterOptions())
		if Afterlife and Afterlife.GetDefaultTargetFrameSettings then
			charDefaults.targetFrame = CopyTable(Afterlife:GetDefaultTargetFrameSettings())
		end
		AfterlifeCharacterSettings[realm][char] = charDefaults
	end

	ApplyOptionsAfterReset()
end

--- Ensure the current character has a settings entry with defaults merged in.
function Afterlife:InitCharacterSettings()
	local realm = GetRealmName()
	local char = UnitName("player")
	if not realm or not char then
		return
	end

	if not AfterlifeCharacterSettings[realm] then
		AfterlifeCharacterSettings[realm] = {}
	end

	local charSettings = AfterlifeCharacterSettings[realm][char]
	if not charSettings then
		charSettings = {}
		AfterlifeCharacterSettings[realm][char] = charSettings
	end

	if charSettings.showAnchors ~= nil and AfterlifeGlobalSettings.showAnchors == nil then
		AfterlifeGlobalSettings.showAnchors = charSettings.showAnchors and true or false
		charSettings.showAnchors = nil
	end

	MergeDefaults(charSettings, GetDefaultCharacterOptions())
end

--- Return per-character settings for the logged-in player, merged with defaults.
--- @return table
function Afterlife:GetCharacterSettings()
	self:InitCharacterSettings()

	local realm = GetRealmName()
	local char = UnitName("player")
	if not realm or not char then
		return GetDefaultCharacterOptions()
	end

	local realmSettings = AfterlifeCharacterSettings[realm]
	local charSettings = realmSettings and realmSettings[char]
	if not charSettings then
		return GetDefaultCharacterOptions()
	end

	return charSettings
end

local BANNER_PATH = "Interface\\AddOns\\Afterlife\\assets\\graphics\\optbanner.tga"

local BANNER_INSET = 5
local BANNER_SCALE = 2
local BANNER_HEIGHT_SCALE = 0.82
local BANNER_BASE_W = 390
local BANNER_BASE_H = 88
local BANNER_DISPLAY_H = BANNER_BASE_H * BANNER_SCALE * BANNER_HEIGHT_SCALE
local FRAME_WIDTH = BANNER_BASE_W * BANNER_SCALE + BANNER_INSET * 2
local FRAME_HEIGHT = 905 + (BANNER_DISPLAY_H - BANNER_BASE_H)

--- Build the localized version and release date string for the options header.
--- @return string
local function GetVersion()
	local version = (Afterlife and Afterlife.Version) or "?"
	local releaseDate = (Afterlife and Afterlife.Date) or "?"
	return L("BUILD_VERSION", version, releaseDate)
end

local TIMER_BAR_REFRESH_FIELDS = {
	height = true,
	width = true,
	growthDirection = true,
	texture = true,
	font = true,
	fontSize = true,
	fontFlags = true,
	rightJustifyTime = true,
}

local RESTART_TEST_TIMERS_ON_REFRESH = {
	growthDirection = true,
	texture = true,
	font = true,
}

local timerBarRefreshFrame = CreateFrame("Frame")
local pendingTimerBarRefresh = false
local pendingTimerBarRefreshField

--- Defer a timer bar group refresh to the next frame to coalesce rapid slider changes.
--- @param field string|nil Setting key that triggered the refresh.
local function ScheduleTimerGroupBarRefresh(field)
	if pendingTimerBarRefresh then
		pendingTimerBarRefreshField = field
		return
	end
	pendingTimerBarRefresh = true
	pendingTimerBarRefreshField = field
	timerBarRefreshFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		pendingTimerBarRefresh = false
		local refreshField = pendingTimerBarRefreshField
		pendingTimerBarRefreshField = nil
		if Afterlife and Afterlife.RefreshTimerGroup then
			Afterlife:RefreshTimerGroup()
		end
		if RESTART_TEST_TIMERS_ON_REFRESH[refreshField] and Afterlife and Afterlife.RefreshTestTimersIfActive then
			Afterlife:RefreshTestTimersIfActive()
		end
	end)
end

--- Save a per-character 3D target frame setting and notify the 3D frame module.
--- @param field string Setting key to update.
--- @param value any New setting value.
local function ApplyTargetFrameSetting(field, value)
	if not Afterlife or not Afterlife.InitCharacterSettings then
		return
	end

	Afterlife:InitCharacterSettings()

	local realm = GetRealmName()
	local char = UnitName("player")
	if not realm or not char then
		return
	end

	local charSettings = AfterlifeCharacterSettings[realm] and AfterlifeCharacterSettings[realm][char]
	if not charSettings then
		return
	end

	if not charSettings.targetFrame then
		charSettings.targetFrame = {}
	end
	charSettings.targetFrame[field] = value

	if Afterlife.OnTargetFrameSettingChanged then
		Afterlife:OnTargetFrameSettingChanged(field, value)
	elseif Afterlife.ApplyTargetFrameSettings then
		Afterlife:ApplyTargetFrameSettings()
	end
end

--- Save a CC timer bar group setting and refresh bars when appearance changes.
--- @param field string Setting key to update.
--- @param value any New setting value.
local function ApplyTimerGroupSetting(field, value)
	local db = Afterlife_Options_GetGlobal()
	if not db.groups then
		db.groups = {}
	end
	if not db.groups[CC_GROUP] then
		db.groups[CC_GROUP] = {}
	end
	db.groups[CC_GROUP][field] = value
	if TIMER_BAR_REFRESH_FIELDS[field] then
		ScheduleTimerGroupBarRefresh(field)
	elseif Afterlife and Afterlife.RefreshTimerGroup then
		Afterlife:RefreshTimerGroup()
	end
end

--- Toggle the options window; create it on first open and play the welcome sound.
function Afterlife_Options_Open()
	if _G.AfterlifeOptionsFrame and _G.AfterlifeOptionsFrame:IsShown() then
		_G.AfterlifeOptionsFrame:Hide()
		return
	end

	Afterlife_Options_InitGlobalSettings()
	if Afterlife and Afterlife.InitCharacterSettings then
		Afterlife:InitCharacterSettings()
	end

	Afterlife_Options_CreateFrame()

	local frame = _G.AfterlifeOptionsFrame
	if frame then
		if frame.RefreshLockButton then
			frame:RefreshLockButton()
		end
		if frame.RefreshControls then
			frame:RefreshControls()
		end
		frame:Show()
		local db = Afterlife_Options_GetGlobal()
		if db.playOptionsWelcomeSound ~= false and Afterlife and Afterlife.PlayLocaleSound then
			local playWelcome = function()
				local settings = Afterlife_Options_GetGlobal()
				if settings.playOptionsWelcomeSound ~= false and Afterlife and Afterlife.PlayLocaleSound then
					Afterlife:PlayLocaleSound("welcome")
				end
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(0, playWelcome)
			else
				playWelcome()
			end
		end
	end
end

--- Build the Afterlife options frame and all controls if not already created.
function Afterlife_Options_CreateFrame()
	if _G.AfterlifeOptionsFrame then
		return
	end

	local db = Afterlife_Options_GetGlobal()
	local perChar = Afterlife and Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings() or GetDefaultCharacterOptions()
	local LSM = Afterlife and Afterlife.LSM

	local frame = CreateFrame("Frame", "AfterlifeOptionsFrame", UIParent, "BackdropTemplate")
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	end

	local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	versionText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -20)
	versionText:SetJustifyH("RIGHT")
	versionText:SetText(GetVersion())
	frame.versionText = versionText

	local copyrightText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	local copyrightFont, copyrightSize, copyrightFlags = copyrightText:GetFont()
	if copyrightFont and copyrightSize then
		copyrightText:SetFont(copyrightFont, copyrightSize - 2, copyrightFlags)
	end
	copyrightText:SetPoint("TOPRIGHT", versionText, "BOTTOMRIGHT", 0, -2)
	copyrightText:SetJustifyH("RIGHT")
	copyrightText:SetText(L("COPYRIGHT"))
	frame.copyrightText = copyrightText

	local creditsBody = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	creditsBody:SetPoint("TOP", copyrightText, "BOTTOM", 0, -32)
	creditsBody:SetPoint("RIGHT", frame, "RIGHT", -19, 0)
	creditsBody:SetWidth(frame:GetWidth() - 48)
	creditsBody:SetJustifyH("RIGHT")
	creditsBody:SetNonSpaceWrap(true)
	creditsBody:SetText(L("OPT_DISCORD_INFO"))
	frame.creditsBody = creditsBody

	local banner = frame:CreateTexture(nil, "ARTWORK")
	banner:SetTexture(BANNER_PATH)
	banner:SetPoint("TOP", frame, "TOP", 0, -BANNER_INSET)
	banner:SetSize(BANNER_BASE_W * BANNER_SCALE, BANNER_DISPLAY_H)
	banner:SetHorizTile(false)
	banner:SetVertTile(false)
	frame.banner = banner

	local y = -(BANNER_INSET + BANNER_DISPLAY_H + BANNER_INSET) - 30
	frame.checkboxes = {}

	--- Create and place a checkbox bound to a global or per-character option key.
	--- @param label string Checkbox label text.
	--- @param key string SavedVariables option key.
	--- @param isPerChar boolean True when stored in character settings.
	--- @param tooltip string|nil Tooltip text shown on hover.
	--- @param xOffset number|nil Extra horizontal offset from the left margin.
	--- @param noDecrement boolean|nil Skip advancing the vertical layout cursor.
	--- @param small boolean|nil Use a smaller label font.
	--- @return CheckButton
	local function AddCheckbox(label, key, isPerChar, tooltip, xOffset, noDecrement, small)
		local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		box:SetPoint("TOPLEFT", 24 + (xOffset or 0), y)
		box.optionKey = key
		box.isPerChar = isPerChar
		box.label = box:CreateFontString(nil, "OVERLAY", small and "GameFontHighlightSmall" or "GameFontNormal")
		box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
		box.label:SetText(label)
		if tooltip and tooltip ~= "" then
			box:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(tooltip)
				GameTooltip:Show()
			end)
			box:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
		box:SetChecked(isPerChar and perChar[key] or db[key])
		box:SetScript("OnClick", function(self)
			local checked = self:GetChecked()
			if isPerChar then
				perChar[key] = checked
				if Afterlife and Afterlife.SetEnabled then
					Afterlife:SetEnabled(checked)
				end
			else
				db[key] = checked
				if key == "graphicalPopups" and Afterlife and Afterlife.SetPopupEnabled then
					Afterlife:SetPopupEnabled(checked)
				elseif key == "flashBorderOnCCBreak" and Afterlife and Afterlife.SetBorderFlashEnabled then
					Afterlife:SetBorderFlashEnabled(checked)
				end
			end
			if key == "enabled" or (not isPerChar and key == "debugMode") then
				frame:UpdateDebugModeState()
			end
		end)
		if not xOffset and not noDecrement then
			y = y - 24
		end
		frame.checkboxes[#frame.checkboxes + 1] = box
		return box
	end

	local addonEnabledBox = AddCheckbox(L("OPT_ADDON_ENABLED"), "enabled", true, L("OPT_ADDON_ENABLED_TT"), nil, true)
	frame.addonEnabledBox = addonEnabledBox
	if addonEnabledBox.label then
		addonEnabledBox.label:SetTextColor(0, 1, 0)
	end

	local welcomeSoundBox = AddCheckbox(L("OPT_OPTIONS_WELCOME_SOUND"), "playOptionsWelcomeSound", false, L("OPT_OPTIONS_WELCOME_SOUND_TT"), nil, true)
	welcomeSoundBox:ClearAllPoints()
	welcomeSoundBox:SetPoint("TOP", addonEnabledBox, "TOP", 0, 0)
	welcomeSoundBox:SetPoint("LEFT", addonEnabledBox.label, "RIGHT", 40, 0)
	if welcomeSoundBox.label then
		welcomeSoundBox.label:SetTextColor(0, 1, 0)
	end
	frame.welcomeSoundBox = welcomeSoundBox

	y = y - 24
	frame.debugModeBox = AddCheckbox(L("OPT_DEBUG_MODE"), "debugMode", false, L("OPT_DEBUG_MODE_TT"), 24, true)
	frame.debugModeBox:ClearAllPoints()
	frame.debugModeBox:SetPoint("TOPLEFT", addonEnabledBox, "BOTTOMLEFT", 44, 9)
	frame.debugModeBox:SetScale(0.85)
	if frame.debugModeBox.label then
		frame.debugModeBox.label:SetFontObject(GameFontHighlightSmall)
		frame.debugModeBox.label:SetTextColor(0, 1, 0)
	end
	y = y - 45

	local ccHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	ccHeading:SetPoint("TOPLEFT", addonEnabledBox, "BOTTOMLEFT", 2, -50)
	ccHeading:SetText(L("OPT_CC_SETTINGS"))
	ccHeading:SetTextColor(1, 1, 0)
	ccHeading:SetScale(0.92)
	frame.ccHeading = ccHeading

	local barSettingsHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	barSettingsHeading:SetPoint("TOP", ccHeading, "TOP", 0, 0)
	barSettingsHeading:SetPoint("LEFT", ccHeading, "LEFT", 410, 0)
	barSettingsHeading:SetText(L("OPT_TIMER_BAR_SETTINGS"))
	barSettingsHeading:SetTextColor(1, 1, 0)
	barSettingsHeading:SetScale(0.92)
	frame.barSettingsHeading = barSettingsHeading

	local ccHeadingSpacer = frame:CreateTexture(nil, "ARTWORK")
	ccHeadingSpacer:SetSize(1, 10)
	ccHeadingSpacer:SetPoint("TOPLEFT", ccHeading, "BOTTOMLEFT", 0, 0)
	ccHeadingSpacer:SetColorTexture(0, 0, 0, 0)

	local barHeadingSpacer = frame:CreateTexture(nil, "ARTWORK")
	barHeadingSpacer:SetSize(1, 10)
	barHeadingSpacer:SetPoint("TOPLEFT", barSettingsHeading, "BOTTOMLEFT", 0, 0)
	barHeadingSpacer:SetColorTexture(0, 0, 0, 0)

	local playSoundBox = AddCheckbox(L("OPT_PLAY_CC_SOUNDS"), "playSoundOnMyCCEvents", false, L("OPT_PLAY_CC_SOUNDS_TT"), nil, nil, true)
	playSoundBox:ClearAllPoints()
	playSoundBox:SetPoint("TOPLEFT", ccHeadingSpacer, "BOTTOMLEFT", -2, 0)

	--- Create a small label anchored above or beside a slider or dropdown control.
	--- @param parent Frame Parent frame for the label.
	--- @param text string Label text.
	--- @param point string Anchor point on the label.
	--- @param relPoint Frame|nil Relative anchor frame.
	--- @param x number|nil Horizontal offset.
	--- @param yOff number|nil Vertical offset.
	--- @param relativePoint string|nil Named anchor on relPoint instead of default TOPLEFT.
	--- @return FontString
	local function addSliderLabel(parent, text, point, relPoint, x, yOff, relativePoint)
		local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		if relativePoint then
			label:SetPoint(point or "TOPLEFT", relPoint or parent, relativePoint, x or 0, yOff or 0)
		else
			label:SetPoint(point or "TOPLEFT", relPoint or parent, x or 0, yOff or 0)
		end
		label:SetText(text)
		return label
	end

	--- Create a horizontal slider with value readout for timer or 3D frame settings.
	--- @param anchor Region Control to position below.
	--- @param minVal number Minimum slider value.
	--- @param maxVal number Maximum slider value.
	--- @param step number Value step size.
	--- @param xOff number|nil Horizontal offset from anchor.
	--- @param yOff number|nil Vertical offset from anchor.
	--- @return Slider
	local function createTimerSlider(anchor, minVal, maxVal, step, xOff, yOff)
		local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
		slider:SetSize(TIMER_CONTROL_WIDTH, 17)
		slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff or 0, yOff or -18)
		if slider.SetOrientation then
			slider:SetOrientation("HORIZONTAL")
		end
		slider:SetMinMaxValues(minVal, maxVal)
		slider:SetValueStep(step)
		slider:SetValue(minVal)
		if slider.SetObeyStepOnDrag then
			slider:SetObeyStepOnDrag(true)
		end
		local thumb = slider:CreateTexture(nil, "ARTWORK")
		thumb:SetSize(16, 24)
		thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
		slider:SetThumbTexture(thumb)
		if slider.SetBackdrop then
			slider:SetBackdrop({
				bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				edgeSize = 8,
				insets = { left = 2, right = 2, top = 2, bottom = 2 },
			})
			slider:SetBackdropColor(0.2, 0.2, 0.2, 0.6)
			slider:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
		end
		local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
		slider.valueText = valueText
		valueText:SetText(tostring(minVal))
		return slider
	end

	local timerBarColumn = CreateFrame("Frame", nil, frame)
	timerBarColumn:SetSize(1, 1)
	timerBarColumn:SetPoint("TOPLEFT", barHeadingSpacer, "BOTTOMLEFT", 0, 0)

	local barHeightLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	barHeightLabel:SetText(L("OPT_BAR_HEIGHT"))
	barHeightLabel:SetPoint("LEFT", timerBarColumn, "LEFT", 0, 0)
	barHeightLabel:SetPoint("TOP", playSoundBox.label, "TOP", 0, 0)

	local heightSlider = createTimerSlider(barHeightLabel, 8, 48, 1, 0, -4)
	heightSlider:ClearAllPoints()
	heightSlider:SetPoint("TOPLEFT", barHeightLabel, "BOTTOMLEFT", 0, -4)
	heightSlider:SetValue(DEFAULT_BAR_HEIGHT)
	heightSlider.valueText:SetText(tostring(DEFAULT_BAR_HEIGHT))
	heightSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ApplyTimerGroupSetting("height", value)
		self.valueText:SetText(tostring(value))
	end)
	frame.timerHeightSlider = heightSlider
	frame.barHeightLabel = barHeightLabel

	local timerControlsAnchor = heightSlider

	local widthSlider = createTimerSlider(timerControlsAnchor, 80, 500, 5, 0)
	widthSlider:SetValue(DEFAULT_BAR_WIDTH)
	widthSlider.valueText:SetText(tostring(DEFAULT_BAR_WIDTH))
	widthSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ApplyTimerGroupSetting("width", value)
		self.valueText:SetText(tostring(value))
	end)
	addSliderLabel(frame, L("OPT_BAR_WIDTH"), "BOTTOMLEFT", widthSlider, 0, 4, "TOPLEFT")
	frame.timerWidthSlider = widthSlider
	timerControlsAnchor = widthSlider

	local growthDropdown = CreateFrame("Frame", "AfterlifeOptionsGrowthDropdown", frame, "UIDropDownMenuTemplate")
	growthDropdown:SetPoint("TOPLEFT", timerControlsAnchor, "BOTTOMLEFT", 0, -18)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(growthDropdown, TIMER_CONTROL_WIDTH)
	end
	local growthOptions = { "DOWN", "UP", "LEFT", "RIGHT" }
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(growthDropdown, function(_, level)
			if level and level == 1 then
				for _, dir in ipairs(growthOptions) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = L("OPT_GROWTH_" .. dir)
					info.value = dir
					info.arg1 = dir
					info.func = function(_, val)
						ApplyTimerGroupSetting("growthDirection", val)
						if UIDropDownMenu_SetSelectedValue then
							UIDropDownMenu_SetSelectedValue(growthDropdown, val)
						end
						if UIDropDownMenu_SetText then
							UIDropDownMenu_SetText(growthDropdown, L("OPT_GROWTH_" .. val))
						end
					end
					local saved = db.groups and db.groups[CC_GROUP]
					local cur = (saved and saved.growthDirection) or "DOWN"
					info.checked = (cur == dir)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end)
	end
	addSliderLabel(frame, L("OPT_GROWTH_DIRECTION"), "BOTTOMLEFT", growthDropdown, 0, 4, "TOPLEFT")
	frame.timerGrowthDropdown = growthDropdown
	timerControlsAnchor = growthDropdown

	local textureDropdown = CreateFrame("Frame", "AfterlifeOptionsTextureDropdown", frame, "UIDropDownMenuTemplate")
	textureDropdown:SetPoint("TOPLEFT", timerControlsAnchor, "BOTTOMLEFT", 0, -18)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(textureDropdown, TIMER_CONTROL_WIDTH)
	end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(textureDropdown, function(_, level)
			if level and level == 1 then
				local list = (LSM and LSM:HashTable("statusbar")) or {}
				local keys = {}
				for k in pairs(list) do
					keys[#keys + 1] = k
				end
				table.sort(keys)
				if #keys == 0 then
					keys[1] = DEFAULT_TEXTURE
				end
				for _, k in ipairs(keys) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = k
					info.value = k
					info.arg1 = k
					info.func = function(_, val)
						if val then
							ApplyTimerGroupSetting("texture", val)
							if UIDropDownMenu_SetSelectedValue then
								UIDropDownMenu_SetSelectedValue(textureDropdown, val)
							end
							if UIDropDownMenu_SetText then
								UIDropDownMenu_SetText(textureDropdown, val)
							end
						end
					end
					local saved = db.groups and db.groups[CC_GROUP]
					local cur = (saved and saved.texture) or DEFAULT_TEXTURE
					info.checked = (cur == k)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end)
	end
	addSliderLabel(frame, L("OPT_TEXTURE"), "BOTTOMLEFT", textureDropdown, 0, 4, "TOPLEFT")
	frame.timerTextureDropdown = textureDropdown
	timerControlsAnchor = textureDropdown

	local fontDropdown = CreateFrame("Frame", "AfterlifeOptionsFontDropdown", frame, "UIDropDownMenuTemplate")
	fontDropdown:SetPoint("TOPLEFT", timerControlsAnchor, "BOTTOMLEFT", 0, -18)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(fontDropdown, TIMER_CONTROL_WIDTH)
	end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(fontDropdown, function(_, level)
			if level and level == 1 then
				local list = (LSM and LSM:HashTable("font")) or {}
				local keys = {}
				for k in pairs(list) do
					keys[#keys + 1] = k
				end
				table.sort(keys)
				if #keys == 0 then
					keys[1] = DEFAULT_FONT
				end
				for _, k in ipairs(keys) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = k
					info.value = k
					info.arg1 = k
					info.func = function(_, val)
						if val then
							ApplyTimerGroupSetting("font", val)
							if UIDropDownMenu_SetSelectedValue then
								UIDropDownMenu_SetSelectedValue(fontDropdown, val)
							end
							if UIDropDownMenu_SetText then
								UIDropDownMenu_SetText(fontDropdown, val)
							end
						end
					end
					local saved = db.groups and db.groups[CC_GROUP]
					local cur = (saved and saved.font) or DEFAULT_FONT
					info.checked = (cur == k)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end)
	end
	addSliderLabel(frame, L("OPT_FONT"), "BOTTOMLEFT", fontDropdown, 0, 4, "TOPLEFT")
	frame.timerFontDropdown = fontDropdown
	timerControlsAnchor = fontDropdown

	local fontSizeSlider = createTimerSlider(timerControlsAnchor, 6, 24, 1, 0)
	fontSizeSlider:SetValue(10)
	fontSizeSlider.valueText:SetText("10")
	fontSizeSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ApplyTimerGroupSetting("fontSize", value)
		self.valueText:SetText(tostring(value))
	end)
	addSliderLabel(frame, L("OPT_FONT_SIZE"), "BOTTOMLEFT", fontSizeSlider, 0, 4, "TOPLEFT")
	frame.timerFontSizeSlider = fontSizeSlider

	local rightJustifyCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	rightJustifyCheckbox:SetPoint("TOPLEFT", fontSizeSlider, "BOTTOMLEFT", -4, -8)
	rightJustifyCheckbox:SetScale(0.85)
	rightJustifyCheckbox.label = rightJustifyCheckbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rightJustifyCheckbox.label:SetPoint("LEFT", rightJustifyCheckbox, "RIGHT", 4, 0)
	rightJustifyCheckbox.label:SetText(L("OPT_RIGHT_JUSTIFY_TIME"))
	rightJustifyCheckbox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L("OPT_RIGHT_JUSTIFY_TIME_TT"))
		GameTooltip:Show()
	end)
	rightJustifyCheckbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	rightJustifyCheckbox:SetScript("OnClick", function(self)
		ApplyTimerGroupSetting("rightJustifyTime", self:GetChecked() and true or false)
	end)
	frame.timerRightJustifyCheckbox = rightJustifyCheckbox

	local frame3dHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame3dHeading:SetPoint("TOPLEFT", rightJustifyCheckbox, "BOTTOMLEFT", 4, -30)
	frame3dHeading:SetText(L("OPT_3D_FRAME_SETTINGS"))
	frame3dHeading:SetTextColor(1, 1, 0)
	frame3dHeading:SetScale(0.92)
	frame.frame3dHeading = frame3dHeading

	--- Create an LSM font dropdown for a 3D target frame font setting.
	--- @param anchor Region Control to position below.
	--- @param settingKey string targetFrame field name (targetFont or timerFont).
	--- @param labelKey string Locale key for the control label.
	--- @param yOffset number|nil Vertical offset from anchor (default -18).
	--- @return Frame Dropdown frame.
	local function createTargetFrameFontDropdown(anchor, settingKey, labelKey, yOffset)
		local dropdown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
		dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset or -18)
		if UIDropDownMenu_SetWidth then
			UIDropDownMenu_SetWidth(dropdown, TIMER_CONTROL_WIDTH)
		end
		if UIDropDownMenu_Initialize then
			UIDropDownMenu_Initialize(dropdown, function(_, level)
				if level and level == 1 then
					local list = (LSM and LSM:HashTable("font")) or {}
					local keys = {}
					for k in pairs(list) do
						keys[#keys + 1] = k
					end
					table.sort(keys)
					if #keys == 0 then
						keys[1] = DEFAULT_FONT
					end
					local charSettings = Afterlife and Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings()
					local tf = charSettings and charSettings.targetFrame or {}
					local cur = tf[settingKey] or DEFAULT_FONT
					for _, k in ipairs(keys) do
						local fontKey = k
						local info = UIDropDownMenu_CreateInfo()
						info.text = fontKey
						info.value = fontKey
						info.arg1 = fontKey
						info.func = function()
							ApplyTargetFrameSetting(settingKey, fontKey)
							if UIDropDownMenu_SetSelectedValue then
								UIDropDownMenu_SetSelectedValue(dropdown, fontKey)
							end
							if UIDropDownMenu_SetText then
								UIDropDownMenu_SetText(dropdown, fontKey)
							end
						end
						info.checked = (cur == fontKey)
						UIDropDownMenu_AddButton(info, level)
					end
				end
			end)
		end
		addSliderLabel(frame, L(labelKey), "BOTTOMLEFT", dropdown, 0, 4, "TOPLEFT")
		return dropdown
	end

	local target3dFontDropdown = createTargetFrameFontDropdown(frame3dHeading, "targetFont", "OPT_3D_TARGET_FONT", -33)
	frame.target3dFontDropdown = target3dFontDropdown

	local target3dFontSizeSlider = createTimerSlider(target3dFontDropdown, 8, 36, 1, 0)
	target3dFontSizeSlider:SetValue(DEFAULT_3D_TARGET_FONT_SIZE)
	target3dFontSizeSlider.valueText:SetText(tostring(DEFAULT_3D_TARGET_FONT_SIZE))
	target3dFontSizeSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ApplyTargetFrameSetting("targetSize", value)
		self.valueText:SetText(tostring(value))
	end)
	addSliderLabel(frame, L("OPT_3D_TARGET_FONT_SIZE"), "BOTTOMLEFT", target3dFontSizeSlider, 0, 4, "TOPLEFT")
	frame.target3dFontSizeSlider = target3dFontSizeSlider

	local timer3dFontDropdown = createTargetFrameFontDropdown(target3dFontSizeSlider, "timerFont", "OPT_3D_TIMER_FONT")
	frame.timer3dFontDropdown = timer3dFontDropdown

	local timer3dFontSizeSlider = createTimerSlider(timer3dFontDropdown, 8, 36, 1, 0)
	timer3dFontSizeSlider:SetValue(DEFAULT_3D_TIMER_FONT_SIZE)
	timer3dFontSizeSlider.valueText:SetText(tostring(DEFAULT_3D_TIMER_FONT_SIZE))
	timer3dFontSizeSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ApplyTargetFrameSetting("timerSize", value)
		self.valueText:SetText(tostring(value))
	end)
	addSliderLabel(frame, L("OPT_3D_TIMER_FONT_SIZE"), "BOTTOMLEFT", timer3dFontSizeSlider, 0, 4, "TOPLEFT")
	frame.timer3dFontSizeSlider = timer3dFontSizeSlider

	local model3dScaleSlider = createTimerSlider(timer3dFontSizeSlider, 0.5, 2, 0.05, 0)
	model3dScaleSlider:SetValue(DEFAULT_3D_MODEL_SCALE)
	model3dScaleSlider.valueText:SetText(string.format("%.2f", DEFAULT_3D_MODEL_SCALE))
	model3dScaleSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value * 20 + 0.5) / 20
		ApplyTargetFrameSetting("modelScale", value)
		self.valueText:SetText(string.format("%.2f", value))
	end)
	addSliderLabel(frame, L("OPT_3D_MODEL_SCALE"), "BOTTOMLEFT", model3dScaleSlider, 0, 4, "TOPLEFT")
	frame.model3dScaleSlider = model3dScaleSlider

	local model3dTextGapSlider = createTimerSlider(model3dScaleSlider, -20, 60, 1, 0)
	model3dTextGapSlider:SetValue(DEFAULT_3D_TEXT_GAP)
	model3dTextGapSlider.valueText:SetText(tostring(DEFAULT_3D_TEXT_GAP))
	model3dTextGapSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		ApplyTargetFrameSetting("textGap", value)
		self.valueText:SetText(tostring(value))
	end)
	addSliderLabel(frame, L("OPT_3D_TEXT_GAP"), "BOTTOMLEFT", model3dTextGapSlider, 0, 4, "TOPLEFT")
	frame.model3dTextGapSlider = model3dTextGapSlider

	local announceApplyBox = AddCheckbox(L("OPT_ANNOUNCE_MY_CC"), "announceMyCCApply", false, L("OPT_ANNOUNCE_MY_CC_TT"), nil, nil, true)
	announceApplyBox:ClearAllPoints()
	announceApplyBox:SetPoint("TOPLEFT", playSoundBox, "BOTTOMLEFT", 0, 7)

	local announceImmuneBox = AddCheckbox(L("OPT_ANNOUNCE_IMMUNE"), "announceMyCCImmune", false, L("OPT_ANNOUNCE_IMMUNE_TT"), nil, nil, true)
	announceImmuneBox:ClearAllPoints()
	announceImmuneBox:SetPoint("TOP", announceApplyBox, "TOP", 0, 0)
	announceImmuneBox:SetPoint("LEFT", announceApplyBox.label, "RIGHT", 60, 0)

	local announceRenewBox = AddCheckbox(L("OPT_ANNOUNCE_RENEWED"), "announceMyCCRenews", false, L("OPT_ANNOUNCE_RENEWED_TT"), nil, nil, true)
	announceRenewBox:ClearAllPoints()
	announceRenewBox:SetPoint("TOPLEFT", announceApplyBox, "BOTTOMLEFT", 0, 7)

	local announceBreakBox = AddCheckbox(L("OPT_ANNOUNCE_BREAKS"), "announceMyCCBreaks", false, L("OPT_ANNOUNCE_BREAKS_TT"), nil, nil, true)
	announceBreakBox:ClearAllPoints()
	announceBreakBox:SetPoint("TOP", announceRenewBox, "TOP", 0, 0)
	announceBreakBox:SetPoint("LEFT", announceApplyBox.label, "RIGHT", 60, 0)

	local announceBattlegroundBox = AddCheckbox(L("OPT_ANNOUNCE_BATTLEGROUND"), "announceInBattlegrounds", false, L("OPT_ANNOUNCE_BATTLEGROUND_TT"), nil, nil, true)
	announceBattlegroundBox:ClearAllPoints()
	announceBattlegroundBox:SetPoint("TOPLEFT", announceRenewBox, "BOTTOMLEFT", 0, 7)

	local announceInterruptBox = AddCheckbox(L("OPT_ANNOUNCE_INTERRUPTS"), "announceMyInterrupts", false, L("OPT_ANNOUNCE_INTERRUPTS_TT"), nil, nil, true)
	announceInterruptBox:ClearAllPoints()
	announceInterruptBox:SetPoint("TOP", announceBattlegroundBox, "TOP", 0, 0)
	announceInterruptBox:SetPoint("LEFT", announceApplyBox.label, "RIGHT", 60, 0)

	local graphicalPopupBox = AddCheckbox(L("OPT_GRAPHICAL_POPUP"), "graphicalPopups", false, L("OPT_GRAPHICAL_POPUP_TT"), nil, nil, true)
	graphicalPopupBox:ClearAllPoints()
	graphicalPopupBox:SetPoint("TOPLEFT", announceBattlegroundBox, "BOTTOMLEFT", 0, 7)

	local flashBorderBox = AddCheckbox(L("OPT_FLASH_BORDER"), "flashBorderOnCCBreak", false, L("OPT_FLASH_BORDER_TT"), nil, nil, true)
	flashBorderBox:ClearAllPoints()
	flashBorderBox:SetPoint("TOPLEFT", graphicalPopupBox, "BOTTOMLEFT", 0, 7)

	local showRaidIconsBox = AddCheckbox(L("OPT_SHOW_RAID_ICONS"), "showRaidIcons", false, L("OPT_SHOW_RAID_ICONS_TT"), nil, nil, true)
	showRaidIconsBox:ClearAllPoints()
	showRaidIconsBox:SetPoint("TOPLEFT", flashBorderBox, "BOTTOMLEFT", 0, 7)
	local prevRaidIconClick = showRaidIconsBox:GetScript("OnClick")
	showRaidIconsBox:SetScript("OnClick", function(self)
		if prevRaidIconClick then
			prevRaidIconClick(self)
		end
		if Afterlife and Afterlife.RefreshTimerGroup then
			Afterlife:RefreshTimerGroup()
		end
		if Afterlife and Afterlife.RefreshAllCCTimerBars then
			Afterlife:RefreshAllCCTimerBars()
		end
	end)

	local tfSettings = Afterlife and Afterlife.GetTargetFrameSettings and Afterlife:GetTargetFrameSettings() or {}
	local frame3dEnabledBox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	frame3dEnabledBox:SetPoint("TOPLEFT", showRaidIconsBox, "BOTTOMLEFT", 0, 7)
	frame3dEnabledBox.label = frame3dEnabledBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame3dEnabledBox.label:SetPoint("LEFT", frame3dEnabledBox, "RIGHT", 4, 0)
	frame3dEnabledBox.label:SetText(L("OPT_3D_FRAME_ENABLED"))
	frame3dEnabledBox:SetChecked(tfSettings.active ~= false)
	frame3dEnabledBox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L("OPT_3D_FRAME_ENABLED_TT"))
		GameTooltip:Show()
	end)
	frame3dEnabledBox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	frame3dEnabledBox:SetScript("OnClick", function(self)
		ApplyTargetFrameSetting("active", self:GetChecked() and true or false)
	end)
	frame.target3dEnabledBox = frame3dEnabledBox

	local killingBlowHeading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	killingBlowHeading:SetPoint("TOPLEFT", frame3dEnabledBox, "BOTTOMLEFT", 2, -30)
	killingBlowHeading:SetText(L("OPT_KILLING_BLOW_SOUNDS"))
	killingBlowHeading:SetTextColor(1, 1, 0)
	killingBlowHeading:SetScale(0.92)
	frame.killingBlowHeading = killingBlowHeading

	local killingBlowHeadingSpacer = frame:CreateTexture(nil, "ARTWORK")
	killingBlowHeadingSpacer:SetSize(1, 10)
	killingBlowHeadingSpacer:SetPoint("TOPLEFT", killingBlowHeading, "BOTTOMLEFT", 0, 0)
	killingBlowHeadingSpacer:SetColorTexture(0, 0, 0, 0)

	local playPvPKillingBlowBox = AddCheckbox(L("OPT_PLAY_PVP_KILLING_BLOW_SOUNDS"), "playPvPKillingBlowSounds", false, L("OPT_PLAY_PVP_KILLING_BLOW_SOUNDS_TT"), nil, nil, true)
	playPvPKillingBlowBox:ClearAllPoints()
	playPvPKillingBlowBox:SetPoint("TOPLEFT", killingBlowHeadingSpacer, "BOTTOMLEFT", -2, 0)

	local playNPCKillingBlowBox = AddCheckbox(L("OPT_PLAY_NPC_KILLING_BLOW_SOUNDS"), "playNPCKillingBlowSounds", false, L("OPT_PLAY_NPC_KILLING_BLOW_SOUNDS_TT"), nil, nil, true)
	playNPCKillingBlowBox:ClearAllPoints()
	playNPCKillingBlowBox:SetPoint("TOPLEFT", playPvPKillingBlowBox, "BOTTOMLEFT", 30, 8)

	local soundpackDropdown = CreateFrame("Frame", "AfterlifeOptionsPvPKillingBlowSoundpackDropdown", frame, "UIDropDownMenuTemplate")
	soundpackDropdown:SetPoint("TOPLEFT", playNPCKillingBlowBox, "BOTTOMLEFT", -15, -18)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(soundpackDropdown, 150)
	end
	if UIDropDownMenu_JustifyText then
		UIDropDownMenu_JustifyText(soundpackDropdown, "LEFT")
	end
	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(soundpackDropdown, function(_, level)
			if level and level == 1 then
				for i = 1, 2 do
					local info = UIDropDownMenu_CreateInfo()
					info.text = L("OPT_PVP_SOUNDPACK_NAME", i)
					info.value = i
					info.arg1 = i
					info.func = function(_, val)
						local globalDb = Afterlife_Options_GetGlobal()
						if globalDb then
							globalDb.playPvPKillingBlowSoundpack = val
							if UIDropDownMenu_SetSelectedValue then
								UIDropDownMenu_SetSelectedValue(soundpackDropdown, val)
							end
							if UIDropDownMenu_SetText then
								UIDropDownMenu_SetText(soundpackDropdown, L("OPT_PVP_SOUNDPACK_NAME", val))
							end
							local paths = AfterlifePvPSoundPaths
							local pack = paths and (val == 2 and paths.killingBlowVoicepack2 or paths.killingBlowVoicepack1)
							local firstPath = pack and pack[1]
							if firstPath then
								PlaySoundFile(firstPath, "Master")
							end
						end
					end
					local cur = (Afterlife_Options_GetGlobal() and Afterlife_Options_GetGlobal().playPvPKillingBlowSoundpack) or 1
					info.checked = (cur == i)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end)
	end
	local initialSoundpack = (db.playPvPKillingBlowSoundpack == 1 or db.playPvPKillingBlowSoundpack == 2) and db.playPvPKillingBlowSoundpack or 1
	if UIDropDownMenu_SetSelectedValue then
		UIDropDownMenu_SetSelectedValue(soundpackDropdown, initialSoundpack)
	end
	if UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(soundpackDropdown, L("OPT_PVP_SOUNDPACK_NAME", initialSoundpack))
	end
	addSliderLabel(frame, L("OPT_PVP_KILLING_BLOW_SOUNDPACK"), "BOTTOMLEFT", soundpackDropdown, 18, 4, "TOPLEFT")
	frame.pvpKillingBlowSoundpackDropdown = soundpackDropdown
	frame.pvpKillingBlowDependentBoxes = { playNPCKillingBlowBox }

	--- Sync timer bar and 3D frame control widgets to current saved settings.
	local function RefreshTimerSettingsControls()
		local saved = db.groups and db.groups[CC_GROUP] or {}
		if frame.timerHeightSlider then
			local v = saved.height or DEFAULT_BAR_HEIGHT
			frame.timerHeightSlider:SetValue(v)
			frame.timerHeightSlider.valueText:SetText(tostring(v))
		end
		if frame.timerWidthSlider then
			local v = saved.width or DEFAULT_BAR_WIDTH
			frame.timerWidthSlider:SetValue(v)
			frame.timerWidthSlider.valueText:SetText(tostring(v))
		end
		if frame.timerGrowthDropdown and UIDropDownMenu_SetSelectedValue then
			local dir = saved.growthDirection or "DOWN"
			UIDropDownMenu_SetSelectedValue(frame.timerGrowthDropdown, dir)
			if UIDropDownMenu_SetText then
				UIDropDownMenu_SetText(frame.timerGrowthDropdown, L("OPT_GROWTH_" .. dir))
			end
		end
		if frame.timerTextureDropdown and UIDropDownMenu_SetSelectedValue then
			local tex = saved.texture or DEFAULT_TEXTURE
			UIDropDownMenu_SetSelectedValue(frame.timerTextureDropdown, tex)
			if UIDropDownMenu_SetText then
				UIDropDownMenu_SetText(frame.timerTextureDropdown, tex)
			end
		end
		if frame.timerFontDropdown and UIDropDownMenu_SetSelectedValue then
			local font = saved.font or DEFAULT_FONT
			UIDropDownMenu_SetSelectedValue(frame.timerFontDropdown, font)
			if UIDropDownMenu_SetText then
				UIDropDownMenu_SetText(frame.timerFontDropdown, font)
			end
		end
		if frame.timerFontSizeSlider then
			local v = saved.fontSize or 10
			frame.timerFontSizeSlider:SetValue(v)
			frame.timerFontSizeSlider.valueText:SetText(tostring(v))
		end
		if frame.timerRightJustifyCheckbox then
			frame.timerRightJustifyCheckbox:SetChecked(saved.rightJustifyTime ~= false)
		end
		local pc = Afterlife and Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings()
		local tf = (pc and pc.targetFrame) or {}
		if frame.target3dEnabledBox then
			frame.target3dEnabledBox:SetChecked(tf.active ~= false)
		end
		if frame.target3dFontDropdown and UIDropDownMenu_SetSelectedValue then
			local font = tf.targetFont or DEFAULT_FONT
			UIDropDownMenu_SetSelectedValue(frame.target3dFontDropdown, font)
			if UIDropDownMenu_SetText then
				UIDropDownMenu_SetText(frame.target3dFontDropdown, font)
			end
		end
		if frame.timer3dFontDropdown and UIDropDownMenu_SetSelectedValue then
			local font = tf.timerFont or DEFAULT_FONT
			UIDropDownMenu_SetSelectedValue(frame.timer3dFontDropdown, font)
			if UIDropDownMenu_SetText then
				UIDropDownMenu_SetText(frame.timer3dFontDropdown, font)
			end
		end
		if frame.target3dFontSizeSlider then
			local v = tf.targetSize or DEFAULT_3D_TARGET_FONT_SIZE
			frame.target3dFontSizeSlider:SetValue(v)
			frame.target3dFontSizeSlider.valueText:SetText(tostring(v))
		end
		if frame.timer3dFontSizeSlider then
			local v = tf.timerSize or DEFAULT_3D_TIMER_FONT_SIZE
			frame.timer3dFontSizeSlider:SetValue(v)
			frame.timer3dFontSizeSlider.valueText:SetText(tostring(v))
		end
		if frame.model3dScaleSlider then
			local v = tf.modelScale or DEFAULT_3D_MODEL_SCALE
			frame.model3dScaleSlider:SetValue(v)
			frame.model3dScaleSlider.valueText:SetText(string.format("%.2f", v))
		end
		if frame.model3dTextGapSlider then
			local v = tf.textGap or DEFAULT_3D_TEXT_GAP
			frame.model3dTextGapSlider:SetValue(v)
			frame.model3dTextGapSlider.valueText:SetText(tostring(v))
		end
	end

	--- Enable or disable the debug mode checkbox based on whether the addon is enabled.
	function frame:UpdateDebugModeState()
		local pc = Afterlife and Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings()
		local addonOn = pc and pc.enabled ~= false
		if self.debugModeBox then
			if addonOn then
				self.debugModeBox:Enable()
			else
				self.debugModeBox:Disable()
			end
		end
	end

	--- Enable or disable PvP killing blow dependent controls from global settings.
	function frame:RefreshPvPKillingBlowControls()
		local globalDb = Afterlife_Options_GetGlobal()
		local pvpKbOn = globalDb and globalDb.playPvPKillingBlowSounds
		for _, box in ipairs(self.pvpKillingBlowDependentBoxes or {}) do
			if pvpKbOn then
				box:Enable()
			else
				box:Disable()
			end
		end
		if self.pvpKillingBlowSoundpackDropdown then
			local ddBtn = self.pvpKillingBlowSoundpackDropdown.Button
			if ddBtn then
				if pvpKbOn then
					ddBtn:Enable()
				else
					ddBtn:Disable()
				end
			end
			local soundpackVal = (globalDb and (globalDb.playPvPKillingBlowSoundpack == 1 or globalDb.playPvPKillingBlowSoundpack == 2)) and globalDb.playPvPKillingBlowSoundpack or 1
			if UIDropDownMenu_SetSelectedValue then
				UIDropDownMenu_SetSelectedValue(self.pvpKillingBlowSoundpackDropdown, soundpackVal)
			end
			if UIDropDownMenu_SetText then
				UIDropDownMenu_SetText(self.pvpKillingBlowSoundpackDropdown, L("OPT_PVP_SOUNDPACK_NAME", soundpackVal))
			end
		end
	end

	--- Reload all checkbox, slider, and dropdown values from saved settings.
	function frame:RefreshControls()
		db = Afterlife_Options_GetGlobal()
		perChar = Afterlife and Afterlife.GetCharacterSettings and Afterlife:GetCharacterSettings() or GetDefaultCharacterOptions()
		for _, box in ipairs(self.checkboxes or {}) do
			local val = box.isPerChar and perChar[box.optionKey] or db[box.optionKey]
			if val ~= nil then
				box:SetChecked(val)
			end
		end
		RefreshTimerSettingsControls()
		self:UpdateDebugModeState()
		self:RefreshPvPKillingBlowControls()
		if self.RefreshLockButton then
			self:RefreshLockButton()
		end
	end

	frame.RefreshTimerSettingsControls = RefreshTimerSettingsControls
	frame.RefreshControls = frame.RefreshControls

	for _, box in ipairs(frame.checkboxes) do
		if box.optionKey == "playPvPKillingBlowSounds" then
			local oldOnClick = box:GetScript("OnClick")
			box:SetScript("OnClick", function(self)
				if oldOnClick then
					oldOnClick(self)
				end
				frame:RefreshPvPKillingBlowControls()
			end)
			break
		end
	end

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(120, 22)
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)
	close:SetText(L("BTN_CLOSE"))
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local testTimers = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	testTimers:SetSize(100, 22)
	testTimers:SetPoint("BOTTOMRIGHT", close, "BOTTOMLEFT", -10, 0)
	testTimers:SetText(L("BTN_TEST"))
	testTimers:SetScript("OnClick", function()
		if Afterlife and Afterlife.AddTestTimers then
			Afterlife:AddTestTimers()
		end
		if Afterlife and Afterlife.PlayBreakSounds then
			Afterlife:PlayBreakSounds()
		end
		if _G.Afterlife_ShowPopup then
			Afterlife_ShowPopup("brokenfree")
		end
	end)

	local lockToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	lockToggle:SetSize(110, 22)
	lockToggle:SetPoint("BOTTOMRIGHT", testTimers, "BOTTOMLEFT", -10, 0)
	lockToggle:SetText(L("BTN_UNLOCK_TIMERS"))
	frame.lockToggle = lockToggle

	--- Update the timer anchor lock button label to match current anchor state.
	function frame:RefreshLockButton()
		local unlocked = Afterlife and Afterlife.AreAnchorsUnlocked and Afterlife:AreAnchorsUnlocked()
		self.lockToggle:SetText(unlocked and L("BTN_LOCK_TIMERS") or L("BTN_UNLOCK_TIMERS"))
	end

	lockToggle:SetScript("OnClick", function()
		if Afterlife and Afterlife.ToggleAnchors then
			Afterlife:ToggleAnchors()
			frame:RefreshLockButton()
		end
	end)

	local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	resetBtn:SetSize(100, 22)
	resetBtn:SetPoint("BOTTOMRIGHT", lockToggle, "BOTTOMLEFT", -10, 0)
	resetBtn:SetText(L("BTN_RESET"))
	resetBtn:SetScript("OnClick", function()
		if StaticPopup_Show then
			StaticPopup_Show("AFTERLIFE_RESET_OPTIONS")
		else
			Afterlife_Options_ResetToDefaults()
			frame:RefreshControls()
			frame:RefreshLockButton()
		end
	end)

	if not StaticPopupDialogs then
		StaticPopupDialogs = {}
	end
	StaticPopupDialogs["AFTERLIFE_RESET_OPTIONS"] = {
		text = L("OPT_RESET_CONFIRM"),
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			Afterlife_Options_ResetToDefaults()
			local optionsFrame = _G.AfterlifeOptionsFrame
			if optionsFrame then
				if optionsFrame.RefreshControls then
					optionsFrame:RefreshControls()
				end
				if optionsFrame.RefreshLockButton then
					optionsFrame:RefreshLockButton()
				end
			end
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(L("CHAT_TITLE_SHORT") .. L("MSG_RESET_DONE"))
			end
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = STATICPOPUP_NUMDIALOGS and 3 or nil,
	}

	frame:SetScript("OnShow", function(self)
		if self.versionText then
			self.versionText:SetText(GetVersion())
		end
		if self.creditsBody then
			self.creditsBody:SetText(L("OPT_DISCORD_INFO"))
		end
		if self.copyrightText then
			self.copyrightText:SetText(L("COPYRIGHT"))
		end
		if self.RefreshControls then
			self:RefreshControls()
		end
	end)

	frame:SetScript("OnHide", function()
		if Afterlife and Afterlife.ClearTestTimers then
			Afterlife:ClearTestTimers()
		end
	end)

	RefreshTimerSettingsControls()
	frame:UpdateDebugModeState()
	frame:RefreshPvPKillingBlowControls()
	frame:RefreshLockButton()
end
