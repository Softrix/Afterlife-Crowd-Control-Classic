--[[
	Afterlife Crowd Control — screen border flash on CC break
]]

local BORDER_WIDTH = 48
local FLASH_PEAK_ALPHA = 0.75
local FLASH_COUNT = 3
local FLASH_RISE = 0.1
local FLASH_HOLD = 0.04
local FLASH_FADE = 0.14
local FLASH_GAP = 0.18
local FLASH_CYCLE = FLASH_RISE + FLASH_HOLD + FLASH_FADE + FLASH_GAP
local GRADIENT_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"

local borderFrame
local edges = {}
local animStart
local animActive
local lastIntensity = -1

--- Return whether the CC-break border flash is enabled in saved settings.
--- @return boolean
local function BorderFlashEnabled()
	if AfterlifeGlobalSettings.flashBorderOnCCBreak == nil then
		AfterlifeGlobalSettings.flashBorderOnCCBreak = false
	end
	return AfterlifeGlobalSettings.flashBorderOnCCBreak and true or false
end

--- Apply a red gradient to one screen-edge texture.
--- @param edge table Texture frame
--- @param orientation string Gradient orientation (VERTICAL or HORIZONTAL)
--- @param startAlpha number Alpha at gradient start
--- @param endAlpha number Alpha at gradient end
local function ApplyEdgeGradient(edge, orientation, startAlpha, endAlpha)
	edge:SetTexture(GRADIENT_TEXTURE)
	edge:SetBlendMode("BLEND")

	if edge.SetGradientAlpha then
		edge:SetGradientAlpha(orientation, 1, 0.08, 0.08, startAlpha, 1, 0.08, 0.08, endAlpha)
	elseif edge.SetGradient then
		local startColor = CreateColor(1, 0.08, 0.08, startAlpha)
		local endColor = CreateColor(1, 0.08, 0.08, endAlpha)
		edge:SetGradient(orientation, startColor, endColor)
	else
		edge:SetColorTexture(1, 0.08, 0.08, (startAlpha + endAlpha) * 0.5)
	end
end

--- Show or hide edge textures at the given flash intensity (0–1).
--- @param intensity number Flash strength multiplier
local function SetFlashIntensity(intensity)
	if intensity == lastIntensity then
		return
	end
	lastIntensity = intensity

	if intensity <= 0 then
		for _, edge in ipairs(edges) do
			edge.texture:Hide()
		end
		return
	end

	local scale = intensity * FLASH_PEAK_ALPHA
	for _, edge in ipairs(edges) do
		edge.texture:Show()
		ApplyEdgeGradient(
			edge.texture,
			edge.orientation,
			edge.startAlpha * scale,
			edge.endAlpha * scale
		)
	end
end

--- Register a screen-edge texture for pulsing during border flash.
--- @param texture table Edge texture frame
--- @param orientation string Gradient orientation
--- @param startAlpha number Alpha at inner edge
--- @param endAlpha number Alpha at outer edge
local function RegisterEdge(texture, orientation, startAlpha, endAlpha)
	edges[#edges + 1] = {
		texture = texture,
		orientation = orientation,
		startAlpha = startAlpha,
		endAlpha = endAlpha,
	}
end

--- Create the fullscreen border flash frame and four edge textures if needed.
local function EnsureBorderFlash()
	if borderFrame then
		return
	end

	borderFrame = CreateFrame("Frame", "AfterlifeBorderFlash", UIParent)
	borderFrame:SetFrameStrata("FULLSCREEN")
	borderFrame:SetFrameLevel(90)
	borderFrame:SetAllPoints(UIParent)
	borderFrame:EnableMouse(false)
	borderFrame:Hide()

	local top = borderFrame:CreateTexture(nil, "ARTWORK")
	top:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	top:SetHeight(BORDER_WIDTH)
	top:Hide()
	RegisterEdge(top, "VERTICAL", 1, 0)

	local bottom = borderFrame:CreateTexture(nil, "ARTWORK")
	bottom:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(BORDER_WIDTH)
	bottom:Hide()
	RegisterEdge(bottom, "VERTICAL", 0, 1)

	local left = borderFrame:CreateTexture(nil, "ARTWORK")
	left:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	left:SetWidth(BORDER_WIDTH)
	left:Hide()
	RegisterEdge(left, "HORIZONTAL", 1, 0)

	local right = borderFrame:CreateTexture(nil, "ARTWORK")
	right:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(BORDER_WIDTH)
	right:Hide()
	RegisterEdge(right, "HORIZONTAL", 0, 1)
end

--- Compute flash intensity for elapsed time within the triple-pulse cycle.
--- @param elapsed number Seconds since flash started
--- @return number|nil Intensity 0–1, or nil when animation is complete
local function GetFlashIntensity(elapsed)
	local flashIndex = math.floor(elapsed / FLASH_CYCLE)
	if flashIndex >= FLASH_COUNT then
		return nil
	end

	local t = elapsed - (flashIndex * FLASH_CYCLE)
	if t < FLASH_RISE then
		local u = t / FLASH_RISE
		return u * u
	elseif t < FLASH_RISE + FLASH_HOLD then
		return 1
	elseif t < FLASH_RISE + FLASH_HOLD + FLASH_FADE then
		local u = (t - FLASH_RISE - FLASH_HOLD) / FLASH_FADE
		return (1 - u) * (1 - u)
	end

	return 0
end

--- OnUpdate handler: advance border flash pulses until complete, then hide.
local function BorderFlash_OnUpdate()
	if not animActive then
		return
	end

	local intensity = GetFlashIntensity(GetTime() - animStart)
	if intensity == nil then
		SetFlashIntensity(0)
		borderFrame:Hide()
		borderFrame:SetScript("OnUpdate", nil)
		animActive = false
		lastIntensity = -1
		return
	end

	SetFlashIntensity(intensity)
end

--- Play the red screen-border flash animation (when enabled).
function Afterlife:FlashBorderOnCCBreak()
	if not BorderFlashEnabled() then
		return
	end

	EnsureBorderFlash()
	animStart = GetTime()
	animActive = true
	lastIntensity = -1

	SetFlashIntensity(0)
	borderFrame:Show()
	borderFrame:SetScript("OnUpdate", BorderFlash_OnUpdate)
end

--- Enable or disable the CC-break border flash globally.
--- @param enabled boolean
function Afterlife:SetBorderFlashEnabled(enabled)
	AfterlifeGlobalSettings.flashBorderOnCCBreak = enabled and true or false
end

--- Return whether the CC-break border flash is currently enabled.
--- @return boolean
function Afterlife:AreBorderFlashesEnabled()
	return BorderFlashEnabled()
end

--- Global wrapper so other files can trigger the border flash without method syntax.
_G.Afterlife_FlashBorderOnCCBreak = function()
	if Afterlife and Afterlife.FlashBorderOnCCBreak then
		Afterlife:FlashBorderOnCCBreak()
	end
end
