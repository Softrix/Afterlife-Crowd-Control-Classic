--[[
	Afterlife Crowd Control — 3D controlled target frame
]]

local ANCHOR_HEIGHT = 18
local DEFAULT_TEXT_GAP = 50
local BASE_MODEL_WIDTH = 255
local BASE_MODEL_HEIGHT = 355
local DEFAULT_MODEL_SCALE = 1.10
local DEFAULT_TARGET_FONT = "Friz Quadrata TT"

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
local ANCHOR_SPACING = 4

local containerFrame
local dragFrame
local dragText
local model
local infoFrame
local titleText
local timerText
local CreateTargetFrameUI

local positioningMode = false
local controlledState = {
	active = false,
	unit = nil,
}
--- Build the default 3D target frame settings table.
--- @return table
local function GetDefaultTargetFrameSettings()
	return {
		active = true,
		point = "CENTER",
		relativePoint = "CENTER",
		x = 0,
		y = 0,
		width = 255,
		height = 355,
		rotation = 0,
		modelScale = DEFAULT_MODEL_SCALE,
		textGap = DEFAULT_TEXT_GAP,
		targetSize = 16,
		timerSize = 14,
		targetFont = DEFAULT_TARGET_FONT,
		timerFont = DEFAULT_TARGET_FONT,
	}
end

--- Resolve a LibSharedMedia font key to a font file path.
--- @param key string|nil LSM font media key.
--- @return string Font file path.
local function ResolveTargetFont(key)
	local LSM = Afterlife and Afterlife.LSM
	if LSM and key then
		local path = LSM:Fetch("font", key)
		if path and path ~= "" then
			return path
		end
	end
	if LSM then
		return LSM:Fetch("font", LSM.DefaultMedia.font or DEFAULT_TARGET_FONT)
	end
	return "Fonts\\FRIZQT__.TTF"
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

--- Return a shallow copy of the default 3D target frame settings.
--- @return table
function Afterlife:GetDefaultTargetFrameSettings()
	local defaults = GetDefaultTargetFrameSettings()
	local copy = {}
	for key, value in pairs(defaults) do
		copy[key] = value
	end
	return copy
end

--- Return per-character 3D target frame settings, merged with defaults.
--- @return table
function Afterlife:GetTargetFrameSettings()
	if self.InitCharacterSettings then
		self:InitCharacterSettings()
	end

	local settings = self.GetCharacterSettings and self:GetCharacterSettings()
	if not settings then
		return GetDefaultTargetFrameSettings()
	end

	if not settings.targetFrame then
		settings.targetFrame = {}
	end

	MergeDefaults(settings.targetFrame, GetDefaultTargetFrameSettings())
	return settings.targetFrame
end

--- Return whether the 3D target frame feature is enabled in settings.
--- @return boolean
local function IsTargetFrameEnabled()
	local settings = Afterlife:GetTargetFrameSettings()
	return settings.active ~= false
end

--- Return whether the Afterlife options window is currently visible.
--- @return boolean
local function IsOptionsFrameOpen()
	local frame = _G.AfterlifeOptionsFrame
	return frame and frame:IsShown()
end

--- Apply the standard tooltip-style backdrop to a drag anchor frame.
--- @param anchor Frame|nil Frame supporting SetBackdrop.
local function ApplyAnchorStyle(anchor)
	if not anchor or not anchor.SetBackdrop then
		return
	end

	anchor:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	anchor:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
end

--- Persist the container frame screen position into character settings.
local function SaveDragPosition()
	if not containerFrame then
		return
	end

	local settings = Afterlife:GetTargetFrameSettings()
	local point, _, relativePoint, x, y = containerFrame:GetPoint(1)
	settings.point = point or "CENTER"
	settings.relativePoint = relativePoint or point or "CENTER"
	settings.x = x or 0
	settings.y = y or 0
end

--- Return whether the 3D frame is in positioning mode or shown as a preview.
--- @return boolean
local function Is3DPreviewActive()
	if positioningMode then
		return true
	end
	return containerFrame and containerFrame:IsShown()
		and dragFrame and dragFrame:IsShown()
end

--- Set placeholder name and timer text for the options positioning preview.
local function Refresh3DPreviewText()
	if not titleText or not timerText then
		return
	end

	titleText:SetText(UnitName("player") or L("PLAYER_DEFAULT"))
	timerText:SetTextColor(0, 1, 0, 1)
	timerText:SetText(L("PREVIEW_REMAINING"))
end

--- Resize the player model frame from settings or an optional scale override.
--- @param scaleOverride number|nil Model scale to apply instead of saved settings.
local function ApplyModelScale(scaleOverride)
	if not model then
		return
	end

	local settings = Afterlife:GetTargetFrameSettings()
	local scale = scaleOverride or settings.modelScale or DEFAULT_MODEL_SCALE
	local width = (settings.width or BASE_MODEL_WIDTH) * scale
	local height = (settings.height or BASE_MODEL_HEIGHT) * scale

	model:SetSize(width, height)
	if model.SetModelScale then
		model:SetModelScale(1)
	end
	if model.SetCamDistanceScale then
		model:SetCamDistanceScale(1)
	end

end

--- Position the info text frame below the model using width and text gap settings.
--- @param gapOverride number|nil Vertical gap override in pixels.
local function ApplyInfoFrameLayout(gapOverride)
	if not infoFrame or not model then
		return
	end

	local settings = Afterlife:GetTargetFrameSettings()
	local scale = settings.modelScale or DEFAULT_MODEL_SCALE
	local width = (settings.width or BASE_MODEL_WIDTH) * scale
	local gap = gapOverride or settings.textGap or DEFAULT_TEXT_GAP

	infoFrame:SetWidth(width)
	infoFrame:ClearAllPoints()
	infoFrame:SetPoint("TOP", model, "BOTTOM", 0, gap)
end

--- Apply target name and timer font family and size from settings or overrides.
--- @param appearanceOverrides table|nil Optional field overrides (targetFont, timerFont, targetSize, timerSize).
local function ApplyTargetFrameFonts(appearanceOverrides)
	CreateTargetFrameUI()

	local settings = Afterlife:GetTargetFrameSettings()
	local targetFont = (appearanceOverrides and appearanceOverrides.targetFont)
		or settings.targetFont
		or DEFAULT_TARGET_FONT
	local timerFont = (appearanceOverrides and appearanceOverrides.timerFont)
		or settings.timerFont
		or DEFAULT_TARGET_FONT
	local targetSize = (appearanceOverrides and appearanceOverrides.targetSize)
		or settings.targetSize
		or 16
	local timerSize = (appearanceOverrides and appearanceOverrides.timerSize)
		or settings.timerSize
		or 14

	if titleText then
		local title = titleText:GetText()
		titleText:SetFont(ResolveTargetFont(targetFont), targetSize, "")
		if title and title ~= "" then
			titleText:SetText(title)
		end
	end

	if timerText then
		local timer = timerText:GetText()
		timerText:SetFont(ResolveTargetFont(timerFont), timerSize, "")
		if timer and timer ~= "" then
			timerText:SetText(timer)
		end
	end
end

--- Apply saved position, scale, rotation, and fonts to all 3D frame UI elements.
local function ApplyTargetFrameSettings()
	CreateTargetFrameUI()

	local settings = Afterlife:GetTargetFrameSettings()
	local scale = settings.modelScale or DEFAULT_MODEL_SCALE
	local width = (settings.width or BASE_MODEL_WIDTH) * scale

	if containerFrame then
		containerFrame:ClearAllPoints()
		containerFrame:SetPoint(
			settings.point or "CENTER",
			UIParent,
			settings.relativePoint or settings.point or "CENTER",
			settings.x or 0,
			settings.y or 0
		)
	end

	if dragFrame then
		dragFrame:SetSize(width, ANCHOR_HEIGHT)
	end

	if model then
		model:SetRotation(settings.rotation or 0)
		ApplyModelScale()
		ApplyInfoFrameLayout()
	end

	ApplyTargetFrameFonts()
end

--- Public entry point to reapply all 3D target frame settings from saved data.
function Afterlife:ApplyTargetFrameSettings()
	ApplyTargetFrameSettings()
end

local TARGET_FRAME_APPEARANCE_FIELDS = {
	targetFont = true,
	timerFont = true,
	targetSize = true,
	timerSize = true,
	modelScale = true,
	textGap = true,
}

--- Refresh preview text, layout, and visibility while positioning mode is active.
local function Refresh3DPreviewVisibility()
	if not Is3DPreviewActive() then
		return
	end

	Refresh3DPreviewText()
	if dragText then
		dragText:SetText(L("MODEL_HELP"))
	end
	if containerFrame then
		containerFrame:Show()
	end
	if dragFrame then
		dragFrame:Show()
	end
	if infoFrame then
		infoFrame:Show()
	end
	if model then
		model:SetUnit("player")
		ApplyModelScale()
		ApplyInfoFrameLayout()
		model:Show()
	end
end

--- React to a single 3D target frame setting change from the options UI.
--- @param field string Setting key that changed.
--- @param value any New setting value.
function Afterlife:OnTargetFrameSettingChanged(field, value)
	if field == "active" then
		if not value then
			if IsOptionsFrameOpen() then
				self:Clear3DFrame()
				if containerFrame then
					containerFrame:Hide()
				end
				if dragFrame then
					dragFrame:Hide()
				end
			else
				if positioningMode then
					self:Close3DPositioningPreview()
				end
				self:Clear3DFrame()
				if containerFrame then
					containerFrame:Hide()
				end
			end
		elseif IsOptionsFrameOpen() or positioningMode then
			self:Show3DPositioningPreview()
		elseif self.RefreshOwnCC3DFrame then
			self:RefreshOwnCC3DFrame()
		end
		return
	end

	if not TARGET_FRAME_APPEARANCE_FIELDS[field] then
		return
	end

	if field == "modelScale" then
		CreateTargetFrameUI()
		ApplyModelScale(value)
		ApplyInfoFrameLayout()
		if dragFrame then
			local settings = self:GetTargetFrameSettings()
			local scale = value or settings.modelScale or DEFAULT_MODEL_SCALE
			dragFrame:SetSize((settings.width or BASE_MODEL_WIDTH) * scale, ANCHOR_HEIGHT)
		end
		Refresh3DPreviewVisibility()
		return
	end

	if field == "textGap" then
		CreateTargetFrameUI()
		ApplyInfoFrameLayout(value)
		Refresh3DPreviewVisibility()
		return
	end

	local overrides = {}
	overrides[field] = value
	ApplyTargetFrameFonts(overrides)
	Refresh3DPreviewVisibility()
end

--- Alias for OnTargetFrameSettingChanged kept for font-specific option callbacks.
--- @param field string Setting key that changed.
--- @param value any New setting value.
function Afterlife:OnTargetFrameFontChanged(field, value)
	self:OnTargetFrameSettingChanged(field, value)
end

--- Create the 3D target frame container, drag handle, model, and text elements once.
function CreateTargetFrameUI()
	if containerFrame then
		return
	end

	containerFrame = CreateFrame("Frame", "AfterlifeModelContainer", UIParent)
	containerFrame:SetSize(255, 1)
	containerFrame:SetFrameStrata("MEDIUM")
	containerFrame:SetMovable(true)
	containerFrame:EnableMouse(false)
	containerFrame:Hide()

	dragFrame = CreateFrame("Button", "AfterlifeModelDragFrame", containerFrame, "BackdropTemplate")
	dragFrame:SetSize(255, ANCHOR_HEIGHT)
	dragFrame:SetPoint("BOTTOM", containerFrame, "TOP", 0, ANCHOR_SPACING)
	dragFrame:SetMovable(true)
	dragFrame:EnableMouse(true)
	dragFrame:RegisterForDrag("LeftButton")
	dragFrame:Hide()
	ApplyAnchorStyle(dragFrame)

	dragFrame:SetScript("OnDragStart", function(self)
		self:GetParent():StartMoving()
	end)
	dragFrame:SetScript("OnDragStop", function(self)
		self:GetParent():StopMovingOrSizing()
		SaveDragPosition()
	end)

	dragText = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	dragText:SetPoint("LEFT", dragFrame, "LEFT", 4, 0)
	dragText:SetPoint("RIGHT", dragFrame, "RIGHT", -4, 0)
	dragText:SetJustifyH("CENTER")
	dragText:SetText(L("MODEL_HELP"))

	model = CreateFrame("PlayerModel", "AfterlifeTargetModel", containerFrame)
	model:SetSize(255, 355)
	model:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 0, 0)
	model:Hide()

	infoFrame = CreateFrame("Frame", "AfterlifeTargetInfoFrame", containerFrame)
	infoFrame:SetSize(255, 50)
	infoFrame:SetPoint("TOP", model, "BOTTOM", 0, DEFAULT_TEXT_GAP)
	infoFrame:Hide()

	titleText = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("TOP", infoFrame, "TOP", 0, -10)
	titleText:SetPoint("LEFT", infoFrame, "LEFT", 0, 0)
	titleText:SetPoint("RIGHT", infoFrame, "RIGHT", 0, 0)
	titleText:SetJustifyH("CENTER")

	timerText = infoFrame:CreateFontString(nil, "OVERLAY", "QuestFont_Huge")
	timerText:SetPoint("TOP", titleText, "BOTTOM", 0, -2)
	timerText:SetPoint("LEFT", infoFrame, "LEFT", 0, 0)
	timerText:SetPoint("RIGHT", infoFrame, "RIGHT", 0, 0)
	timerText:SetJustifyH("CENTER")

	ApplyTargetFrameSettings()
end

--- Hide the model and clear controlled-unit state and displayed text.
function Afterlife:Clear3DFrame()
	controlledState.active = false
	controlledState.unit = nil

	if model then
		model:ClearModel()
		model:Hide()
	end
	if titleText then
		titleText:SetText("")
	end
	if timerText then
		timerText:SetText("")
	end
	if infoFrame and not positioningMode then
		infoFrame:Hide()
	end
	if containerFrame and not positioningMode then
		containerFrame:Hide()
	end
end

--- Update the displayed mob name and CC remaining time on the 3D frame.
--- @param mobName string|nil Target display name.
--- @param remainingSeconds number|nil Seconds remaining on the crowd control.
function Afterlife:Update3DFrame(mobName, remainingSeconds)
	if not IsTargetFrameEnabled() or not controlledState.active then
		return
	end

	if mobName and titleText then
		titleText:SetText(mobName)
	end

	if timerText then
		local remaining = tonumber(remainingSeconds) or 0
		if remaining <= 0 then
			timerText:SetText("")
		else
			if remaining <= 15 then
				timerText:SetTextColor(1, 0, 0, 1)
			else
				timerText:SetTextColor(0, 1, 0, 1)
			end
			timerText:SetText(L("REMAINING_SECONDS", math.floor(remaining+1)))
		end
	end
end

--- Show the 3D frame for a controlled unit, binding the model and initial text.
--- @param unit string|nil WoW unit token to display (e.g. "target").
--- @param mobName string|nil Display name override.
--- @param remainingSeconds number|nil Initial CC time remaining.
function Afterlife:Show3DControlledUnit(unit, mobName, remainingSeconds)
	if not IsTargetFrameEnabled() then
		return
	end

	CreateTargetFrameUI()
	controlledState.active = true
	positioningMode = false

	if dragFrame then
		dragFrame:Hide()
	end
	if dragText then
		dragText:SetText("")
	end

	containerFrame:Show()
	infoFrame:Show()

	if unit and UnitExists(unit) then
		controlledState.unit = unit
		model:SetUnit(unit)
		ApplyModelScale()
		model:Show()
	elseif controlledState.unit and UnitExists(controlledState.unit) then
		model:Show()
	else
		controlledState.unit = nil
		model:ClearModel()
		model:Hide()
	end

	self:Update3DFrame(mobName or (unit and UnitName(unit)) or "", remainingSeconds)
end

--- Update name and timer during active CC without re-binding the model.
--- The PlayerModel is set once at cast start so polymorph does not replace it with the sheep.
--- @param mobName string|nil Target display name.
--- @param remainingSeconds number|nil Seconds remaining on the crowd control.
function Afterlife:Update3DCC(mobName, remainingSeconds)
	if not IsTargetFrameEnabled() then
		return
	end

	CreateTargetFrameUI()
	controlledState.active = true
	positioningMode = false

	if dragFrame then
		dragFrame:Hide()
	end

	containerFrame:Show()
	infoFrame:Show()

	if model and controlledState.unit then
		model:Show()
	end

	self:Update3DFrame(mobName, remainingSeconds)
end

--- Store the unit token used by the 3D model without changing visibility.
--- @param unit string|nil WoW unit token to bind.
function Afterlife:Bind3DUnit(unit)
	if unit and UnitExists(unit) then
		controlledState.unit = unit
	end
end

--- Show the draggable 3D frame preview used while the options window is open.
function Afterlife:Show3DPositioningPreview()
	if not IsTargetFrameEnabled() then
		return
	end

	CreateTargetFrameUI()
	positioningMode = true
	controlledState.active = false
	controlledState.unit = nil

	dragText:SetText(L("MODEL_HELP"))
	ApplyTargetFrameSettings()
	Refresh3DPreviewText()

	model:SetUnit("player")
	ApplyModelScale()
	model:Show()
	containerFrame:Show()
	dragFrame:Show()
	infoFrame:Show()
end

--- Exit positioning preview mode, save drag position, and hide preview UI.
function Afterlife:Close3DPositioningPreview()
	SaveDragPosition()
	positioningMode = false

	if containerFrame then
		containerFrame:Hide()
	end
	if dragFrame then
		dragFrame:Hide()
	end

	if not controlledState.active then
		self:Clear3DFrame()
	end
end

--- Hide the 3D frame containers without clearing active CC state when applicable.
function Afterlife:Hide3DFrame()
	positioningMode = false

	if containerFrame then
		containerFrame:Hide()
	end
	if dragFrame then
		dragFrame:Hide()
	end

	if not controlledState.active then
		self:Clear3DFrame()
	elseif infoFrame then
		infoFrame:Show()
	end
end

--- Close the 3D positioning preview when the options window is hidden.
local function OnOptionsClosed()
	if Afterlife and Afterlife.Close3DPositioningPreview then
		Afterlife:Close3DPositioningPreview()
	end
end

--- Wrap options open/create hooks to show and tear down the 3D positioning preview.
local function InstallOptionsHook()
	if not Afterlife or Afterlife._3DOptionsHookInstalled then
		return
	end
	if not Afterlife_Options_Open or not Afterlife_Options_CreateFrame then
		return
	end

	local originalCreate = Afterlife_Options_CreateFrame
	Afterlife_Options_CreateFrame = function()
		originalCreate()
		local frame = _G.AfterlifeOptionsFrame
		if frame and not frame._3dOnHideHooked then
			local previousOnHide = frame:GetScript("OnHide")
			frame:SetScript("OnHide", function(self)
				OnOptionsClosed()
				if previousOnHide then
					previousOnHide(self)
				end
			end)
			frame._3dOnHideHooked = true
		end
	end

	local originalOpen = Afterlife_Options_Open
	Afterlife_Options_Open = function()
		local frame = _G.AfterlifeOptionsFrame
		local wasShown = frame and frame:IsShown()

		originalOpen()

		if wasShown then
			return
		end

		if Afterlife.Show3DPositioningPreview then
			Afterlife:Show3DPositioningPreview()
		end
	end

	Afterlife._3DOptionsHookInstalled = true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Afterlife" then
		InstallOptionsHook()
	elseif event == "PLAYER_LOGIN" then
		CreateTargetFrameUI()
		ApplyTargetFrameSettings()
	end
end)
