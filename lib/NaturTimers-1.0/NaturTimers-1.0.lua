--[[

NaturTimers-1.0
---------------
Lightweight timer bar library for WoW Classic Era / TBC / Retail.
by Codermik: https://discord.gg/R6EkZ94TKK.
Dependencies: LibStub

Embed: add `lib\NaturTimers-1.0\embed.xml` (or `lib\embed.xml`) to your addon .toc before your scripts.

Features:
 - Movable groups of timer bars
 - Per-timer icons (left and right)
 - Customisable size, font, and texture
 - Normal (fill up) or reverse (cooldown-style) timers
 - Sorting: by remaining time or label, or custom comparator
 - Growth direction per group: UP, DOWN, LEFT, RIGHT
 - Auto-binding: target/focus buffs and debuffs, spell cooldowns

API:

 - local NT = LibStub:GetLibrary("NaturTimers-1.0")
 - local NT = NaturTimers  (global alias)

 - local group = NT:CreateGroup(groupName, options)
     options = {
       width           = number (default 200)
       height          = number (default 18)
       point, relativeTo, relativePoint, x, y
       growthDirection = "DOWN"|"UP"|"LEFT"|"RIGHT" (default "DOWN")
       sortOrder       = "none"|"remaining_asc"|"remaining_desc"|"label_asc"|"label_desc" (default "remaining_asc")
       sortFunc        = function(barA, barB) return barA < barB end (optional, overrides sortOrder)
       spacing         = number (default 2)
       texture, font, fontSize, fontFlags
     }

 - NT:SetGroupAnchorVisible(groupName, visible)
 - NT:SetGroupSortOrder(groupName, sortOrder)
 - NT:SetGroupSortFunc(groupName, sortFunc)
 - NT:SetGroupGrowthDirection(groupName, direction)

 - NT:StartTimer(groupName, timerId, duration, options)
 - NT:StopTimer(groupName, timerId)
 - NT:StopAllTimers(groupName)
 - NT:GetGroup(name)

 - NT:BindGroupToUnitAuras(groupName, unit, filter, options)
     unit = "target", "focus", "player", etc.
     filter = "HELPFUL", "HARMFUL", "HELPFUL|PLAYER", etc.
     options = { maxBars = number, showOnlyMine = boolean (use filter "PLAYER" instead) }

 - NT:UnbindGroupFromUnitAuras(groupName)

 - NT:BindGroupToCooldowns(groupName, spellList, options)
     spellList = { spellId or spellName, ... }
     options = { minDuration = number (seconds), maxBars = number }

 - NT:UnbindGroupFromCooldowns(groupName)

 If you use this library you must give credit such as:
    "Powered by NaturTimers, created by Codermik. Discord: https://discord.gg/R6EkZ94TKK"

]]

local MAJOR, MINOR = "NaturTimers-1.0", 1
local NaturTimers = LibStub:NewLibrary(MAJOR, MINOR)

if not NaturTimers then return end

-- Migrate state from a pre-LibStub global instance (same session reload).
local legacy = _G.NaturTimers
if type(legacy) == "table" and legacy ~= NaturTimers then
  NaturTimers._groups = NaturTimers._groups or legacy._groups
  NaturTimers._auraBindings = NaturTimers._auraBindings or legacy._auraBindings
  NaturTimers._cooldownBindings = NaturTimers._cooldownBindings or legacy._cooldownBindings
end

NaturTimers.minor = MINOR

local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local SORT_REMAINING_ASC   = "remaining_asc"
local SORT_REMAINING_DESC  = "remaining_desc"
local SORT_LABEL_ASC       = "label_asc"
local SORT_LABEL_DESC      = "label_desc"
local SORT_NONE            = "none"

local GROWTH_UP    = "UP"
local GROWTH_DOWN  = "DOWN"
local GROWTH_LEFT  = "LEFT"
local GROWTH_RIGHT = "RIGHT"

local groups = NaturTimers._groups or {}
NaturTimers._groups = groups

--- Clamp a number to the inclusive range [min, max].
--- @param v number Value to clamp
--- @param min number Lower bound
--- @param max number Upper bound
--- @return number Clamped value
local function Clamp(v, min, max)
  if v < min then return min end
  if v > max then return max end
  return v
end

--- Return seconds remaining on an active timer bar.
--- @param bar table NaturTimers status bar frame
--- @return number Remaining time in seconds (0 if inactive)
local function GetBarRemaining(bar)
  if not bar.active then return 0 end
  return Clamp(bar.duration - bar.elapsed, 0, bar.duration)
end

--- Sort active bars in place using the group's sortOrder or sortFunc.
--- @param group table Timer group frame
--- @param activeList table Array of active bar frames (modified in place)
local function SortBars(group, activeList)
  local order = group.sortOrder or SORT_REMAINING_ASC
  local custom = group.sortFunc

  if custom and type(custom) == "function" then
    table.sort(activeList, function(a, b) return custom(a, b) end)
    return
  end

  if order == SORT_NONE then return end

  if order == SORT_REMAINING_ASC then
    table.sort(activeList, function(a, b) return GetBarRemaining(a) < GetBarRemaining(b) end)
  elseif order == SORT_REMAINING_DESC then
    table.sort(activeList, function(a, b) return GetBarRemaining(a) > GetBarRemaining(b) end)
  elseif order == SORT_LABEL_ASC then
    table.sort(activeList, function(a, b) return (a.labelText or "") < (b.labelText or "") end)
  elseif order == SORT_LABEL_DESC then
    table.sort(activeList, function(a, b) return (a.labelText or "") > (b.labelText or "") end)
  end
end

--- Position visible bars within a group and resize the group frame.
--- @param group table Timer group frame
local function LayoutGroup(group)
  local timers = group.timers
  local activeList = {}

  for _, bar in pairs(timers) do
    if bar.active then
      activeList[#activeList + 1] = bar
    else
      bar:Hide()
    end
  end

  SortBars(group, activeList)

  local rawGrowth = group.growthDirection or GROWTH_DOWN
  local growth = rawGrowth and string.upper(tostring(rawGrowth)) or GROWTH_DOWN
  if growth ~= GROWTH_UP and growth ~= GROWTH_DOWN and growth ~= GROWTH_LEFT and growth ~= GROWTH_RIGHT then
    growth = GROWTH_DOWN
  end
  local count = #activeList
  local spacing = group.spacing
  local barW, barH = group.barWidth, group.barHeight

  -- Set group size first so bar positions are correct when parent is resized (important for UP)
  local showPlaceholder = count == 0 and group.anchorVisible
  if growth == GROWTH_UP or growth == GROWTH_DOWN then
    local totalH = count > 0 and (count * barH + (count - 1) * spacing) or (showPlaceholder and barH or 0)
    group:SetHeight(totalH)
    group:SetWidth((count > 0 or showPlaceholder) and barW or 0)
  else
    local totalW = count > 0 and (count * barW + (count - 1) * spacing) or (showPlaceholder and barW or 0)
    group:SetWidth(totalW)
    group:SetHeight((count > 0 or showPlaceholder) and barH or 0)
  end

  -- Vertical (UP/DOWN): slot 0 at top. Sort is remaining_asc so list is [least left, ..., most left]. First in list = top = least duration left.
  for i, bar in ipairs(activeList) do
    bar:ClearAllPoints()
    local idx = i - 1
    if growth == GROWTH_UP or growth == GROWTH_DOWN then
      bar:SetPoint("TOPLEFT", group, "TOPLEFT", 0, -idx * (barH + spacing))
      bar:SetPoint("TOPRIGHT", group, "TOPRIGHT", 0, -idx * (barH + spacing))
    elseif growth == GROWTH_LEFT then
      bar:SetPoint("TOPRIGHT", group, "TOPRIGHT", -idx * (barW + spacing), 0)
      bar:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", -idx * (barW + spacing), 0)
    else
      bar:SetPoint("TOPLEFT", group, "TOPLEFT", idx * (barW + spacing), 0)
      bar:SetPoint("BOTTOMLEFT", group, "BOTTOMLEFT", idx * (barW + spacing), 0)
    end
    bar:Show()
  end

  if count > 0 or showPlaceholder then
    group:Show()
    if group.SetBackdrop then
      group:SetBackdropColor(0, 0, 0, 0.4)
    end
  else
    group:Hide()
  end
end

--- Move the cast-bar-style spark texture to match the bar fill position.
--- @param bar table Timer status bar frame
local function UpdateBarSpark(bar)
  if not bar.spark then return end
  local minV, maxV = bar:GetMinMaxValues()
  local val = bar:GetValue()
  local w = bar:GetWidth()
  if maxV > minV and w > 0 then
    local ratio = (val - minV) / (maxV - minV)
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("LEFT", bar, "LEFT", w * ratio - 3, 0)
    bar.spark:Show()
  else
    bar.spark:Hide()
  end
end

--- Refresh label and optional right-justified time text for a bar.
--- @param bar table Timer status bar frame
local function UpdateBarLabels(bar)
  if not bar or not bar.active then
    return
  end

  local remaining = Clamp(bar.duration - bar.elapsed, 0, bar.duration)
  local group = bar.group

  if bar.timeText and bar.timeText:IsShown() then
    bar.text:SetText(bar.labelText or "")
    if remaining >= 60 then
      bar.timeText:SetFormattedText("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
    else
      bar.timeText:SetFormattedText("%.1f", remaining)
    end
  else
    if remaining >= 60 then
      bar.text:SetFormattedText("%s - %d:%02d", bar.labelText or "", math.floor(remaining / 60), math.floor(remaining % 60))
    else
      bar.text:SetFormattedText("%s - %.1f", bar.labelText or "", remaining)
    end
  end
end

--- OnUpdate handler: advance timer, update colour, labels, and spark; hide when finished.
--- @param self table Timer status bar frame
--- @param elapsed number Seconds since last frame
local function TimerOnUpdate(self, elapsed)
  if not self.active then
    self:SetScript("OnUpdate", nil)
    return
  end

  self.elapsed = self.elapsed + elapsed

  if self.reverse then
    local remaining = Clamp(self.duration - self.elapsed, 0, self.duration)
    self:SetValue(remaining)
    if remaining <= 0 then
      self.active = false
      self:Hide()
      LayoutGroup(self.group)
      return
    end
  else
    local value = Clamp(self.elapsed, 0, self.duration)
    self:SetValue(value)
    if value >= self.duration then
      self.active = false
      self:Hide()
      LayoutGroup(self.group)
      return
    end
  end

  UpdateBarLabels(self)

  local remaining = Clamp(self.duration - self.elapsed, 0, self.duration)
  -- Bar colour: reverse = green (full time left) -> red (expired); casts = red (just started) -> green (full)
  local ratio
  if self.reverse then
    ratio = (self.duration and self.duration > 0) and (remaining / self.duration) or 0
  else
    ratio = (self.duration and self.duration > 0) and (self.elapsed / self.duration) or 0
  end
  local r, g = 1 - ratio, ratio
  self:SetStatusBarColor(r, g, 0, 1)
  UpdateBarSpark(self)
end

--- Apply texture, font, size, and colour options to a timer bar.
--- @param bar table Timer status bar frame
--- @param opts table Per-timer style overrides
--- @param group table Parent timer group defaults
local function ApplyBarStyle(bar, opts, group)
  local texture = opts.texture or group.texture or DEFAULT_TEXTURE
  bar:SetStatusBarTexture(texture)

  local w = opts.width or group.barWidth
  local h = opts.height or group.barHeight
  bar:SetHeight(h)
  bar:SetWidth(w)

  local fontPath, fontSize, fontFlags
  if opts.font or opts.fontSize or opts.fontFlags then
    fontPath = opts.font or group.fontPath
    fontSize = opts.fontSize or group.fontSize
    fontFlags = opts.fontFlags or group.fontFlags
  else
    fontPath = group.fontPath
    fontSize = group.fontSize
    fontFlags = group.fontFlags
  end
  if fontPath and fontSize then
    bar.text:SetFont(fontPath, fontSize, fontFlags)
    if bar.timeText then
      bar.timeText:SetFont(fontPath, fontSize, fontFlags)
    end
  end

  bar.text:SetJustifyH("LEFT")
  if bar.timeText then
    if group.rightJustifyTime then
      bar.text:ClearAllPoints()
      bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
      bar.text:SetPoint("RIGHT", bar.timeText, "LEFT", -4, 0)
      bar.timeText:Show()
      bar.timeText:SetJustifyH("RIGHT")
    else
      bar.text:ClearAllPoints()
      bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
      bar.text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
      bar.timeText:Hide()
    end
  end

  if opts.color then
    local c = opts.color
    bar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
  elseif not bar.active then
    -- Initial: reverse = green (full time left), casts = red (just started); TimerOnUpdate will update each frame
    if bar.reverse then
      bar:SetStatusBarColor(0, 1, 0, 1)
    else
      bar:SetStatusBarColor(1, 0, 0, 1)
    end
  end
end

--- Create a new timer bar child frame for a group (not started until StartTimer).
--- @param group table Timer group frame
--- @param timerId string Unique timer id within the group
--- @return table New status bar frame
local function CreateTimerBar(group, timerId)
  local bar = CreateFrame("StatusBar", nil, group)
  bar.group = group
  bar.timerId = timerId
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetColorTexture(0, 0, 0, 0.5)

  bar.iconLeft = bar:CreateTexture(nil, "ARTWORK")
  bar.iconLeft:SetSize(group.barHeight, group.barHeight)
  bar.iconLeft:SetPoint("RIGHT", bar, "LEFT", -2, 0)

  bar.iconRight = bar:CreateTexture(nil, "ARTWORK")
  bar.iconRight:SetSize(group.barHeight, group.barHeight)
  bar.iconRight:SetPoint("LEFT", bar, "RIGHT", 2, 0)

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetJustifyH("LEFT")
  bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
  bar.text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

  bar.timeText = bar:CreateFontString(nil, "OVERLAY")
  bar.timeText:SetJustifyH("RIGHT")
  bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  bar.timeText:SetWidth(56)
  if group.rightJustifyTime then
    bar.text:ClearAllPoints()
    bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.text:SetPoint("RIGHT", bar.timeText, "LEFT", -4, 0)
  else
    bar.timeText:Hide()
  end

  bar.spark = bar:CreateTexture(nil, "OVERLAY")
  bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  bar.spark:SetSize(6, group.barHeight + 4)
  bar.spark:SetBlendMode("ADD")
  bar.spark:SetPoint("LEFT", bar, "LEFT", 0, 0)
  bar.spark:Hide()

  bar.active = false

  return bar
end

--- Create (or return existing) movable timer bar group with anchor and layout settings.
--- @param name string Unique group name
--- @param opts table|nil Group options (size, point, growth, sort, font, texture, title, ...)
--- @return table Group frame
function NaturTimers:CreateGroup(name, opts)
  if groups[name] then
    return groups[name]
  end

  opts = opts or {}
  local frameName = "NaturTimersGroup_" .. name
  local parent = opts.relativeTo or UIParent

  local group = CreateFrame("Frame", frameName, parent, "BackdropTemplate")
  group:SetSize(opts.width or 200, opts.height or 18)
  group:SetPoint(opts.point or "CENTER", parent, opts.relativePoint or (opts.point or "CENTER"), opts.x or 0, opts.y or 0)

  if group.SetBackdrop then
    group:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      tile = true, tileSize = 16,
    })
    group:SetBackdropColor(0, 0, 0, 0.4)
  end

  group.barWidth = opts.width or 200
  group.barHeight = opts.height or 18
  group.spacing = opts.spacing or 2
  group.growthDirection = opts.growthDirection or (opts.growUp and GROWTH_UP or GROWTH_DOWN)
  group.sortOrder = opts.sortOrder or SORT_REMAINING_ASC
  group.sortFunc = opts.sortFunc
  group.texture = opts.texture or DEFAULT_TEXTURE

  local refFont = GameFontHighlightSmall or GameFontNormal or SystemFont_Shadow_Small
  local fontPath, fontSize, fontFlags
  if refFont and refFont.GetFont then
    fontPath, fontSize, fontFlags = refFont:GetFont()
  else
    fontPath, fontSize, fontFlags = "Fonts\\FRIZQT__.TTF", 10, ""
  end

  group.fontPath = opts.font or fontPath
  group.fontSize = opts.fontSize or fontSize
  group.fontFlags = opts.fontFlags or fontFlags
  if opts.rightJustifyTime ~= nil then
    group.rightJustifyTime = opts.rightJustifyTime and true or false
  else
    group.rightJustifyTime = true
  end
  group.showRightIcon = (opts.showRightIcon == nil) or opts.showRightIcon

  group.timers = {}
  group.name = name

  local anchor = CreateFrame("Button", frameName .. "_Anchor", group, "BackdropTemplate")
  anchor:SetSize(group.barWidth, 18)
  local growth0 = (opts.growthDirection and string.upper(tostring(opts.growthDirection))) or GROWTH_DOWN
  if growth0 == GROWTH_UP then
    anchor:SetPoint("TOP", group, "BOTTOM", 0, -4)
  else
    anchor:SetPoint("BOTTOM", group, "TOP", 0, 4)
  end
  anchor:SetMovable(true)
  anchor:EnableMouse(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", function(self)
    self:GetParent():StartMoving()
  end)
  anchor:SetScript("OnDragStop", function(self)
    local parent = self:GetParent()
    parent:StopMovingOrSizing()
  end)

  if anchor.SetBackdrop then
    anchor:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    anchor:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
  end

  local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", anchor, "LEFT", 4, 0)
  label:SetPoint("RIGHT", anchor, "RIGHT", -4, 0)
  label:SetJustifyH("CENTER")
  label:SetText(opts.title or name)

  group.anchor = anchor
  group.anchorLabel = label
  group.anchorVisible = false
  group.anchor:Hide()

  --- Show or hide this group's drag anchor (method on the group frame).
  --- @param visible boolean
  function group:SetAnchorVisible(visible)
    self.anchorVisible = visible and true or false
    if visible then
      self:SetMovable(true)
      self:EnableMouse(true)
      self.anchor:Show()
    else
      self:SetMovable(false)
      self:EnableMouse(false)
      self.anchor:Hide()
    end
    LayoutGroup(self)
  end

  groups[name] = group
  LayoutGroup(group)
  return group
end

--- Show or hide a group's drag anchor and enable/disable group dragging.
--- @param name string Group name
--- @param visible boolean True to show anchor and allow drag
function NaturTimers:SetGroupAnchorVisible(name, visible)
  local group = groups[name]
  if group and group.SetAnchorVisible then
    group:SetAnchorVisible(visible)
  end
end

--- Set how active bars in a group are sorted, then relayout.
--- @param name string Group name
--- @param sortOrder string One of remaining_asc/desc, label_asc/desc, or none
function NaturTimers:SetGroupSortOrder(name, sortOrder)
  local group = groups[name]
  if group then
    group.sortOrder = sortOrder
    LayoutGroup(group)
  end
end

--- Set a custom bar comparator for a group, then relayout.
--- @param name string Group name
--- @param sortFunc function|nil function(barA, barB) returning boolean
function NaturTimers:SetGroupSortFunc(name, sortFunc)
  local group = groups[name]
  if group then
    group.sortFunc = sortFunc
    LayoutGroup(group)
  end
end

--- Set bar stack direction (UP/DOWN/LEFT/RIGHT) for a group, then relayout.
--- @param name string Group name
--- @param direction string UP, DOWN, LEFT, or RIGHT
function NaturTimers:SetGroupGrowthDirection(name, direction)
  local group = groups[name]
  if group and (direction == GROWTH_UP or direction == GROWTH_DOWN or direction == GROWTH_LEFT or direction == GROWTH_RIGHT) then
    group.growthDirection = direction
    LayoutGroup(group)
  end
end

--- Start or refresh a timer bar in a group.
--- @param groupName string Group name (created if missing)
--- @param timerId string Unique timer id within the group
--- @param duration number Total duration in seconds
--- @param opts table|nil label, icons, reverse, startRemaining, colour, font overrides, ...
function NaturTimers:StartTimer(groupName, timerId, duration, opts)
  if not groupName or not timerId or not duration then return end
  local group = groups[groupName]
  if not group then
    group = self:CreateGroup(groupName, {})
  end

  opts = opts or {}

  local timers = group.timers
  local bar = timers[timerId]
  if not bar then
    bar = CreateTimerBar(group, timerId)
    timers[timerId] = bar
  end

  bar.duration = duration
  bar.reverse = not not opts.reverse
  bar.labelText = opts.label or tostring(timerId)
  bar.active = true

  -- Support starting a timer already part-way through its life.
  -- If opts.startRemaining is provided (and reverse=true), the bar will start at that remaining value.
  -- Alternatively, opts.startElapsed can be used to start a non-reverse bar part-way through.
  local elapsed = 0
  if opts.startElapsed and type(opts.startElapsed) == "number" then
    elapsed = Clamp(opts.startElapsed, 0, duration)
  elseif opts.startRemaining and type(opts.startRemaining) == "number" then
    local rem = Clamp(opts.startRemaining, 0, duration)
    elapsed = duration - rem
  end
  bar.elapsed = elapsed

  if bar.reverse then
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(Clamp(duration - elapsed, 0, duration))
  else
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(Clamp(elapsed, 0, duration))
  end

  if opts.iconLeft then
    bar.iconLeft:SetTexture(opts.iconLeft)
    bar.iconLeft:Show()
  else
    bar.iconLeft:Hide()
  end

  if opts.iconRight and (group.showRightIcon ~= false) then
    bar.iconRight:SetTexture(opts.iconRight)
    bar.iconRight:Show()
  else
    bar.iconRight:Hide()
  end

  ApplyBarStyle(bar, opts, group)

  if group.rightJustifyTime and bar.timeText and bar.timeText:IsShown() then
    bar.text:SetText(bar.labelText or "")
    local remaining = Clamp(bar.duration - bar.elapsed, 0, bar.duration)
    if remaining >= 60 then
      bar.timeText:SetFormattedText("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
    else
      bar.timeText:SetFormattedText("%.1f", remaining)
    end
  else
    local remaining = Clamp(bar.duration - bar.elapsed, 0, bar.duration)
    if remaining >= 60 then
      bar.text:SetFormattedText("%s - %d:%02d", bar.labelText or "", math.floor(remaining / 60), math.floor(remaining % 60))
    else
      bar.text:SetFormattedText("%s - %.1f", bar.labelText or "", remaining)
    end
  end

  bar:SetScript("OnUpdate", TimerOnUpdate)
  bar:Show()
  UpdateBarSpark(bar)

  LayoutGroup(group)
end

--- Stop and hide a single timer bar in a group.
--- @param groupName string Group name
--- @param timerId string Timer id to stop
function NaturTimers:StopTimer(groupName, timerId)
  local group = groups[groupName]
  if not group then return end
  local bar = group.timers[timerId]
  if not bar then return end

  bar.active = false
  bar:SetScript("OnUpdate", nil)
  bar:Hide()

  LayoutGroup(group)
end

--- Stop and hide every active timer in a group.
--- @param groupName string Group name
function NaturTimers:StopAllTimers(groupName)
  local group = groups[groupName]
  if not group then return end
  for _, bar in pairs(group.timers) do
    bar.active = false
    bar:SetScript("OnUpdate", nil)
    bar:Hide()
  end
  LayoutGroup(group)
end

--- Return the group frame for a name, or nil if not created.
--- @param name string Group name
--- @return table|nil Group frame
function NaturTimers:GetGroup(name)
  return groups[name]
end

--- Set the anchor label text for a group.
--- @param name string Group name
--- @param title string|nil Text shown on the drag anchor
function NaturTimers:SetGroupTitle(name, title)
  local group = groups[name]
  if group and group.anchorLabel then
    group.anchorLabel:SetText(title or name)
  end
end

--- Update group layout, style, and position; reapplies to active bars.
--- @param name string Group name
--- @param opts table|nil Fields to update (title, point, size, growth, sort, font, ...)
function NaturTimers:UpdateGroupOptions(name, opts)
  local group = groups[name]
  if not group or not opts then return end
  if opts.title and group.anchorLabel then
    group.anchorLabel:SetText(opts.title)
  end
  if opts.point or opts.x or opts.y then
    local parent = group:GetParent()
    group:ClearAllPoints()
    group:SetPoint(opts.point or "CENTER", parent, opts.relativePoint or (opts.point or "CENTER"), opts.x or 0, opts.y or 0)
  end
  if opts.width then
    group.barWidth = opts.width
    if group.anchor then group.anchor:SetWidth(opts.width) end
  end
  if opts.height then group.barHeight = opts.height end
  if opts.spacing then group.spacing = opts.spacing end
  if opts.texture then group.texture = opts.texture end
  if opts.font then group.fontPath = opts.font end
  if opts.fontSize then group.fontSize = opts.fontSize end
  if opts.fontFlags ~= nil then group.fontFlags = opts.fontFlags end
  if opts.growthDirection ~= nil and opts.growthDirection ~= "" then
    group.growthDirection = string.upper(tostring(opts.growthDirection))
    -- Anchor above group for DOWN/LEFT/RIGHT, below group for UP so bars stack above the title
    if group.anchor then
      group.anchor:ClearAllPoints()
      if group.growthDirection == GROWTH_UP then
        group.anchor:SetPoint("TOP", group, "BOTTOM", 0, -4)
      else
        group.anchor:SetPoint("BOTTOM", group, "TOP", 0, 4)
      end
    end
  end
  if opts.sortOrder ~= nil then group.sortOrder = opts.sortOrder end
  if opts.sortFunc ~= nil then group.sortFunc = opts.sortFunc end
  if opts.rightJustifyTime ~= nil then
    group.rightJustifyTime = opts.rightJustifyTime and true or false
  end
  if opts.showRightIcon ~= nil then
    group.showRightIcon = opts.showRightIcon and true or false
  end
  local styleOpts = {
    texture = group.texture,
    font = group.fontPath,
    fontSize = group.fontSize,
    fontFlags = group.fontFlags,
    width = group.barWidth,
    height = group.barHeight,
  }
  for _, bar in pairs(group.timers) do
    if bar.active then
      ApplyBarStyle(bar, styleOpts, group)
      bar:SetWidth(group.barWidth)
      bar:SetHeight(group.barHeight)
      if bar.iconLeft then
        bar.iconLeft:SetSize(group.barHeight, group.barHeight)
      end
      if bar.iconRight then
        bar.iconRight:SetSize(group.barHeight, group.barHeight)
      end
      if bar.spark then
        bar.spark:SetSize(6, group.barHeight + 4)
      end
      if group.showRightIcon == false then
        bar.iconRight:Hide()
      elseif bar.iconRight:GetTexture() then
        bar.iconRight:Show()
      end
      UpdateBarLabels(bar)
      UpdateBarSpark(bar)
    end
  end
  LayoutGroup(group)
end

-- ---------------------------------------------------------------------------
-- Unit aura binding (target/focus buffs and debuffs)
-- ---------------------------------------------------------------------------

local auraBindings = NaturTimers._auraBindings or {}
NaturTimers._auraBindings = auraBindings

--- Sync aura timers for a unit into a group from UnitAura scan.
--- @param nt table NaturTimers library instance
--- @param groupName string Target group name
--- @param unit string Unit token (e.g. target, focus)
--- @param filter string UnitAura filter (HELPFUL, HARMFUL, ...)
--- @param options table|nil maxBars, showPlayerNames, iconRight, ...
local function SyncUnitAuras(nt, groupName, unit, filter, options)
  local group = groups[groupName]
  if not group or not UnitExists(unit) then
    return
  end

  options = options or {}
  local maxBars = options.maxBars or 20
  local seen = {}

  for i = 1, maxBars do
    local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId = UnitAura(unit, i, filter)
    if not name then break end

    -- Determine full duration and remaining time.
    local fullDuration = duration

    local remaining = 0
    if expirationTime and fullDuration and fullDuration > 0 then
      remaining = (expirationTime - GetTime())
    elseif expirationTime and duration and duration > 0 then
      remaining = (expirationTime - GetTime())
    elseif fullDuration and fullDuration > 0 then
      remaining = fullDuration
    end

    if remaining <= 0 and fullDuration and fullDuration > 0 then
      remaining = fullDuration
    end
    if remaining <= 0 then
      remaining = 0.1
    end

    local timerDuration = fullDuration or remaining

    local timerId = (spellId and spellId > 0) and ("aura_" .. tostring(spellId) .. "_" .. i) or ("aura_" .. i)
    seen[timerId] = true
    -- When showPlayerNames is enabled: show the unit's name (who has the buff) in brackets, not the caster
    local labelText
    if options.showPlayerNames ~= false then
      local unitName = (unit and UnitName(unit)) or (source and source ~= "" and UnitName(source)) or nil
      labelText = name .. (unitName and (" (" .. unitName .. ")") or "") .. (count and count > 1 and (" x" .. count) or "")
    else
      labelText = name .. (count and count > 1 and (" x" .. count) or "")
    end
    local timerOpts = {
      label = labelText,
      iconLeft = icon,
      reverse = true,
      startRemaining = (fullDuration and fullDuration > 0) and remaining or nil,
      color = (filter == "HARMFUL" or filter:find("HARMFUL")) and { 0.8, 0.2, 0.2, 1 } or { 0.2, 0.6, 1, 1 },
    }
    if options.iconRight then
      timerOpts.iconRight = options.iconRight
    end
    nt:StartTimer(groupName, timerId, timerDuration, timerOpts)
  end

  for timerId, bar in pairs(group.timers) do
    if bar.active and timerId:match("^aura_") and not seen[timerId] then
      nt:StopTimer(groupName, timerId)
    end
  end
end

--- Bind a group to UNIT_AURA updates for a unit; auto-manages aura timer bars.
--- @param groupName string Group name
--- @param unit string Unit token to watch
--- @param filter string UnitAura filter
--- @param options table|nil Binding options and optional groupOptions for CreateGroup
function NaturTimers:BindGroupToUnitAuras(groupName, unit, filter, options)
  self:UnbindGroupFromUnitAuras(groupName)

  local group = self:CreateGroup(groupName, options and options.groupOptions or {})
  options = options or {}

  local frame = CreateFrame("Frame", "NaturTimersAura_" .. groupName)
  frame.groupName = groupName
  frame.unit = unit
  frame.filter = filter
  frame.options = options
  frame:RegisterUnitEvent("UNIT_AURA", unit)
  frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_AURA" and arg1 == unit then
      SyncUnitAuras(self, groupName, unit, filter, options)
    end
  end)

  auraBindings[groupName] = { unit = unit, filter = filter, options = options, frame = frame }
  SyncUnitAuras(self, groupName, unit, filter, options)
end

--- Remove aura binding for a group and stop all its timers.
--- @param groupName string Group name
function NaturTimers:UnbindGroupFromUnitAuras(groupName)
  local binding = auraBindings[groupName]
  if binding and binding.frame then
    binding.frame:UnregisterAllEvents()
    auraBindings[groupName] = nil
  end
  self:StopAllTimers(groupName)
end

-- ---------------------------------------------------------------------------
-- Spell cooldown binding
-- ---------------------------------------------------------------------------

local cooldownBindings = NaturTimers._cooldownBindings or {}
NaturTimers._cooldownBindings = cooldownBindings

local COOLDOWN_POLL_INTERVAL = 0.25

--- Resolve a spell name or id to a numeric spell id.
--- @param spell number|string Spell id or name
--- @return number|nil Spell id, or nil if not found
local function ResolveSpellId(spell)
  if type(spell) == "number" then
    return spell
  end
  local name, _, _, _, _, _, spellId = GetSpellInfo(spell)
  return name and spellId or nil
end

--- Sync spell cooldown timers for a spell list into a group.
--- @param nt table NaturTimers library instance
--- @param groupName string Target group name
--- @param spellList table Array of spell ids or names
--- @param options table|nil minDuration, maxBars, ...
local function SyncCooldowns(nt, groupName, spellList, options)
  local group = groups[groupName]
  if not group then return end

  options = options or {}
  local minDuration = options.minDuration or 1
  local maxBars = options.maxBars or 12
  local now = GetTime()
  local seen = {}

  for i = 1, math.min(#spellList, maxBars) do
    local spellId = ResolveSpellId(spellList[i])
    if not spellId then
      spellId = spellList[i]
    end
    local start, duration = GetSpellCooldown(spellId)
    if start and duration and duration >= minDuration then
      local remaining = (start + duration) - now
      if remaining > 0 then
        local name = GetSpellInfo(spellId) or tostring(spellId)
        local timerId = "cd_" .. tostring(spellId)
        seen[timerId] = true
        nt:StartTimer(groupName, timerId, remaining, {
          label = name,
          iconLeft = select(3, GetSpellInfo(spellId)),
          reverse = true,
          color = { 0.5, 0.5, 0.5, 1 },
        })
      end
    end
  end

  for timerId, bar in pairs(group.timers) do
    if bar.active and timerId:match("^cd_") and not seen[timerId] then
      nt:StopTimer(groupName, timerId)
    end
  end
end

--- Poll spell cooldowns and mirror them as timer bars in a group.
--- @param groupName string Group name
--- @param spellList table Array of spell ids or names
--- @param options table|nil minDuration, maxBars, groupOptions, ...
function NaturTimers:BindGroupToCooldowns(groupName, spellList, options)
  self:UnbindGroupFromCooldowns(groupName)

  if not spellList or type(spellList) ~= "table" or #spellList == 0 then
    return
  end

  local group = self:CreateGroup(groupName, options and options.groupOptions or {})
  options = options or {}

  local frame = CreateFrame("Frame", "NaturTimersCD_" .. groupName)
  frame.groupName = groupName
  frame.spellList = spellList
  frame.options = options
  frame.elapsed = 0
  frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= COOLDOWN_POLL_INTERVAL then
      self.elapsed = 0
      SyncCooldowns(NaturTimers, self.groupName, self.spellList, self.options)
    end
  end)

  cooldownBindings[groupName] = { spellList = spellList, options = options, frame = frame }
  SyncCooldowns(self, groupName, spellList, options)
end

--- Remove cooldown polling for a group and stop all its timers.
--- @param groupName string Group name
function NaturTimers:UnbindGroupFromCooldowns(groupName)
  local binding = cooldownBindings[groupName]
  if binding and binding.frame then
    binding.frame:SetScript("OnUpdate", nil)
    cooldownBindings[groupName] = nil
  end
  self:StopAllTimers(groupName)
end

_G.NaturTimers = NaturTimers

