--[[

	Afterlife Crowd Control — Batman-style popups
	Graphics: assets/graphics/immune.tga, brokenfree.tga

    If you use any of this code you must credit me.

]]

local ASSETS = "Interface\\AddOns\\Afterlife\\assets\\graphics\\"

Afterlife_PopupGraphics = {
	IMMUNE = "immune",
	BROKEN_FREE = "brokenfree",
}

local PHASE_GROW   = 0.12
local PHASE_HOLD   = 0.45
local PHASE_SHAKE  = 1.0
local PHASE_SHRINK = 0.18
local SCALE_START  = 0.08
local SCALE_PEAK   = 1.35
local SHAKE_PIXELS = 5

local popupFrame
local popupTexture
local animStartTime
local animActive
local baseYOffset = 0

--- Return whether graphical popups are enabled in saved settings.
--- @return boolean
local function PopupsEnabled()
	if AfterlifeGlobalSettings.graphicalPopups == nil then
		AfterlifeGlobalSettings.graphicalPopups = true
	end
	return AfterlifeGlobalSettings.graphicalPopups ~= false
end

--- Resolve a short graphic name to a full addon texture path.
--- @param graphic string Filename (e.g. immune) or full path
--- @return string|nil Texture path, or nil if graphic is empty
local function ResolveGraphicPath(graphic)
	if not graphic or graphic == "" then
		return nil
	end

	local path = graphic
	if not path:find("\\") then
		path = path:gsub("%.tga$", ""):gsub("%.blp$", "")
		path = ASSETS .. path .. ".tga"
	end

	return path
end

--- Animate popup scale, alpha, and shake through grow/hold/shake/shrink phases.
--- @param _ table Popup frame (unused)
--- @param elapsed number Seconds since last frame
local function Popup_OnUpdate(_, elapsed)
	if not animActive or not popupFrame or not popupFrame:IsShown() then
		return
	end

	local t = GetTime() - animStartTime

	if t < PHASE_GROW then
		local u = t / PHASE_GROW
		u = u * u * (3 - 2 * u)
		popupFrame:SetScale(SCALE_START + (SCALE_PEAK - SCALE_START) * u)
		popupFrame:SetAlpha(u)
	elseif t < PHASE_GROW + PHASE_HOLD then
		popupFrame:SetScale(SCALE_PEAK)
		popupFrame:SetAlpha(1)
	elseif t < PHASE_GROW + PHASE_HOLD + PHASE_SHAKE then
		popupFrame:SetScale(SCALE_PEAK)
		popupFrame:SetAlpha(1)
		local jx = (math.random() - 0.5) * 2 * SHAKE_PIXELS
		local jy = (math.random() - 0.5) * 2 * SHAKE_PIXELS
		popupFrame:ClearAllPoints()
		popupFrame:SetPoint("CENTER", UIParent, "CENTER", jx, baseYOffset + jy)
	elseif t < PHASE_GROW + PHASE_HOLD + PHASE_SHAKE + PHASE_SHRINK then
		local shrinkStart = PHASE_GROW + PHASE_HOLD + PHASE_SHAKE
		if t - elapsed < shrinkStart then
			popupFrame:ClearAllPoints()
			popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, baseYOffset)
		end
		local u = (t - shrinkStart) / PHASE_SHRINK
		u = u * u * (3 - 2 * u)
		popupFrame:SetScale(SCALE_PEAK - (SCALE_PEAK - SCALE_START) * u)
		popupFrame:SetAlpha(1 - u)
	else
		popupFrame:SetScript("OnUpdate", nil)
		popupFrame:Hide()
		animActive = false
	end
end

--- Lazily create and return the shared popup frame and texture.
--- @return table Popup root frame
local function GetPopupFrame()
	if popupFrame then
		return popupFrame
	end

	popupFrame = CreateFrame("Frame", "AfterlifePopupFrame", UIParent)
	popupFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	popupFrame:SetFrameLevel(100)
	popupFrame:SetSize(256, 256)
	baseYOffset = UIParent:GetHeight() / 6
	popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, baseYOffset)
	popupFrame:SetScale(SCALE_START)
	popupFrame:SetAlpha(0)
	popupFrame:Hide()

	popupTexture = popupFrame:CreateTexture(nil, "ARTWORK")
	popupTexture:SetAllPoints(popupFrame)
	popupTexture:SetTexCoord(0, 1, 0, 1)

	return popupFrame
end

--- Show a Batman-style popup graphic (grows in, shakes, shrinks out).
--- @param graphic string Filename (e.g. "immune", "brokenfree") or full texture path.
function Afterlife_ShowPopup(graphic)
	if not PopupsEnabled() then
		return
	end

	local path = ResolveGraphicPath(graphic)
	if not path then
		return
	end

	local frame = GetPopupFrame()
	popupTexture:SetTexture(path)
	frame:SetScale(SCALE_START)
	frame:SetAlpha(0)
	frame:Show()

	baseYOffset = UIParent:GetHeight() / 6
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, baseYOffset)

	animStartTime = GetTime()
	animActive = true
	frame:SetScript("OnUpdate", Popup_OnUpdate)
end

--- Enable or disable graphical popups globally.
--- @param enabled boolean
function Afterlife:SetPopupEnabled(enabled)
	AfterlifeGlobalSettings.graphicalPopups = enabled and true or false
end

--- Return whether graphical popups are currently enabled.
--- @return boolean
function Afterlife:ArePopupsEnabled()
	return PopupsEnabled()
end

_G.Afterlife_ShowPopup = Afterlife_ShowPopup
