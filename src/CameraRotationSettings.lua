-- Camera Rotation Settings
-- Manages mod settings, XML persistence, and vanilla settings menu integration

CameraRotationSettings = {}

CameraRotationSettings.isEnabled = true
CameraRotationSettings.thirdPersonRotation = true
CameraRotationSettings.rotationSpeed = 0.25
CameraRotationSettings.rotationDelay = 0.01
CameraRotationSettings.maxRotationAngle = 0.25
CameraRotationSettings.reverseFlip = true

CameraRotationSettings.settingsDone = false
CameraRotationSettings.cachedFrame = nil
CameraRotationSettings.isUpdatingFromKeybind = false

-- Returns path to settings XML file (per-savegame or user profile)
local function getSettingsFileName()
  if g_currentModSettingsDirectory ~= nil then
    return g_currentModSettingsDirectory .. "settings.xml"
  end
  local modName = g_currentModName or "FS25_CameraRotation"
  return getUserProfileAppPath() .. "modSettings/" .. modName .. "/settings.xml"
end

-- Loads settings from XML file (fallback if vanilla settings not available)
function CameraRotationSettings:load()
  local fileName = getSettingsFileName()
  
  if not fileExists(fileName) then
    return
  end

  local xmlFile = loadXMLFile("cameraRotationSettings", fileName, "cameraRotation")
  if xmlFile == nil then
    return
  end
  local enabled = getXMLBool(xmlFile, "cameraRotation.enabled#value")
  if enabled ~= nil then
    self.isEnabled = enabled
  end

  local thirdPerson = getXMLBool(xmlFile, "cameraRotation.thirdPersonRotation#value")
  if thirdPerson ~= nil then
    self.thirdPersonRotation = thirdPerson
  end

  local rotSpeed = getXMLFloat(xmlFile, "cameraRotation.rotationSpeed#value")
  if rotSpeed ~= nil then
    self.rotationSpeed = math.max(0.1, math.min(1.5, rotSpeed))
  end

  local rotDelay = getXMLFloat(xmlFile, "cameraRotation.rotationDelay#value")
  if rotDelay ~= nil then
    self.rotationDelay = math.max(0.001, math.min(0.1, rotDelay))
  end

  local maxRotAngle = getXMLFloat(xmlFile, "cameraRotation.maxRotationAngle#value")
  if maxRotAngle ~= nil then
    self.maxRotationAngle = math.max(0.15, math.min(0.6, maxRotAngle))
  end

  local revFlip = getXMLBool(xmlFile, "cameraRotation.reverseFlip#value")
  if revFlip ~= nil then
    self.reverseFlip = revFlip
  end



  delete(xmlFile)
end

-- Saves current settings to XML file
function CameraRotationSettings:save()
  local fileName = getSettingsFileName()
  
  local directory = string.match(fileName, "^(.*[/\\])")
  if directory ~= nil and not fileExists(directory) then
    createFolder(directory)
  end

  local xmlFile = createXMLFile("cameraRotationSettings", fileName, "cameraRotation")
  if xmlFile == nil then
    return false
  end
  setXMLBool(xmlFile, "cameraRotation.enabled#value", self.isEnabled)
  setXMLBool(xmlFile, "cameraRotation.thirdPersonRotation#value", self.thirdPersonRotation)
  setXMLFloat(xmlFile, "cameraRotation.rotationSpeed#value", self.rotationSpeed)
  setXMLFloat(xmlFile, "cameraRotation.rotationDelay#value", self.rotationDelay)
  setXMLFloat(xmlFile, "cameraRotation.maxRotationAngle#value", self.maxRotationAngle)
  setXMLBool(xmlFile, "cameraRotation.reverseFlip#value", self.reverseFlip)

  saveXMLFile(xmlFile)
  delete(xmlFile)

  return fileExists(fileName)
end

function CameraRotationSettings:setRotationSpeed(value)
  self.rotationSpeed = math.max(0.1, math.min(1.5, value))
  self:save()
end

function CameraRotationSettings:setRotationDelay(value)
  self.rotationDelay = math.max(0.001, math.min(0.1, value))
  self:save()
end

function CameraRotationSettings:setMaxRotationAngle(value)
  self.maxRotationAngle = math.max(0.15, math.min(0.6, value))
  self:save()
end

function CameraRotationSettings:setEnabled(value)
  self.isEnabled = value
  self:save()
end

function CameraRotationSettings:setThirdPersonRotation(value)
  self.thirdPersonRotation = value
  self:save()
end

function CameraRotationSettings:setReverseFlip(value)
  self.reverseFlip = value
  self:save()
end

-- Adds section title to settings frame
function CameraRotationSettings:addTitle(inGameMenuSettingsFrame)
  local textElement = TextElement.new()
  local textElementProfile = g_gui:getProfile("fs25_settingsSectionHeader")
  textElement.name = "sectionHeader"
  textElement:loadProfile(textElementProfile, true)
  textElement:setText(g_i18n:getText("ui_cameraRotationSettingsTitle"))
  inGameMenuSettingsFrame.gameSettingsLayout:addElement(textElement)
  textElement:onGuiSetupFinished()
  textElement.focusId = FocusManager:serveAutoFocusId()
end

-- Creates a checkbox option UI element by cloning existing settings element
function CameraRotationSettings:addCheckboxOption(inGameMenuSettingsFrame, onClickCallback, title, tooltip, checked)
  local cloneRef = inGameMenuSettingsFrame.checkActiveSuspensionCamera
  
  if cloneRef == nil then
    print("[CameraRotation] ERROR: checkActiveSuspensionCamera not found for cloning")
    return nil
  end
  local element = cloneRef.parent:clone()
  element.id = nil

  local settingElement = element.elements[1]
  local settingTitle = element.elements[2]
  local toolTip = settingElement.elements[1]

  settingTitle:setText(title)
  toolTip:setText(tooltip)
  settingElement.id = nil
  settingElement.target = CameraRotationSettings
  settingElement:setCallback("onClickCallback", onClickCallback)
  settingElement:setIsChecked(checked)
  settingElement:setDisabled(false)

  element:reloadFocusHandling(true)
  inGameMenuSettingsFrame.gameSettingsLayout:addElement(element)
  
  return settingElement
end

-- Creates a multi-text option UI element by cloning existing settings element
function CameraRotationSettings:addMultiTextOption(inGameMenuSettingsFrame, onClickCallback, texts, title, tooltip, initialState)
  local cloneRef = inGameMenuSettingsFrame.multiCameraSensitivity
  
  if cloneRef == nil then
    print("[CameraRotation] ERROR: multiCameraSensitivity not found for cloning")
    return nil
  end
  local element = cloneRef.parent:clone()
  element.id = nil

  local settingElement = element.elements[1]
  local settingTitle = element.elements[2]
  local toolTip = settingElement.elements[1]

  settingTitle:setText(title)
  toolTip:setText(tooltip)
  settingElement.id = nil
  settingElement.target = CameraRotationSettings
  settingElement:setCallback("onClickCallback", onClickCallback)
  settingElement:setTexts(texts)
  if initialState ~= nil then
    settingElement:setState(initialState, false)
  end
  settingElement:setDisabled(false)

  element:reloadFocusHandling(true)
  inGameMenuSettingsFrame.gameSettingsLayout:addElement(element)
  
  return settingElement
end

-- Preset values for rotation speed
CameraRotationSettings.rotationSpeedTexts = {
  "Super Slow",
  "Slower",
  "Normal",
  "Faster",
  "Super Fast",
  "Extreme",
  "Maximum"
}
CameraRotationSettings.rotationSpeedValues = {0.1, 0.15, 0.25, 0.4, 0.6, 1.0, 1.5}

CameraRotationSettings.rotationDelayTexts = {
  "Instant",
  "Fast",
  "Normal",
  "Smooth",
  "Very Smooth",
  "Maximum"
}
CameraRotationSettings.rotationDelayValues = {0.001, 0.003, 0.01, 0.02, 0.05, 0.1}

CameraRotationSettings.maxRotationAngleTexts = {
  "Small",
  "Normal",
  "Medium",
  "Large",
}
CameraRotationSettings.maxRotationAngleValues = {0.15, 0.25, 0.4, 0.6}

-- Called when vanilla settings frame opens
-- Dynamically adds mod settings UI elements to the frame
function CameraRotationSettings:onFrameOpen()
  if self.settingsDone then
    return
  end

  self.cachedFrame = self
  
  CameraRotationSettings:addTitle(self)
  CameraRotationSettings.enabledOption = CameraRotationSettings:addCheckboxOption(
    self,
    "onEnabledChanged",
    g_i18n:getText("settingTitle_cameraRotationEnabled"),
    g_i18n:getText("settingDescription_cameraRotationEnabled"),
    CameraRotationSettings.isEnabled
  )
  
  CameraRotationSettings.thirdPersonRotationOption = CameraRotationSettings:addCheckboxOption(
    self,
    "onThirdPersonRotationChanged",
    g_i18n:getText("settingTitle_thirdPersonRotation"),
    g_i18n:getText("settingDescription_thirdPersonRotation"),
    CameraRotationSettings.thirdPersonRotation
  )
  
  local speedInitialState = 1
  local closestIndex = 1
  local closestDiff = math.abs(CameraRotationSettings.rotationSpeed - CameraRotationSettings.rotationSpeedValues[1])
  for i, value in ipairs(CameraRotationSettings.rotationSpeedValues) do
    local diff = math.abs(CameraRotationSettings.rotationSpeed - value)
    if diff < closestDiff then
      closestDiff = diff
      closestIndex = i
    end
  end
  speedInitialState = closestIndex
  
  CameraRotationSettings.rotationSpeedOption = CameraRotationSettings:addMultiTextOption(
    self,
    "onRotationSpeedChanged",
    CameraRotationSettings.rotationSpeedTexts,
    g_i18n:getText("settingTitle_rotationSpeed"),
    g_i18n:getText("settingDescription_rotationSpeed"),
    speedInitialState
  )
  
  local delayInitialState = 1
  closestIndex = 1
  closestDiff = math.abs(CameraRotationSettings.rotationDelay - CameraRotationSettings.rotationDelayValues[1])
  for i, value in ipairs(CameraRotationSettings.rotationDelayValues) do
    local diff = math.abs(CameraRotationSettings.rotationDelay - value)
    if diff < closestDiff then
      closestDiff = diff
      closestIndex = i
    end
  end
  delayInitialState = closestIndex
  
  CameraRotationSettings.rotationDelayOption = CameraRotationSettings:addMultiTextOption(
    self,
    "onRotationDelayChanged",
    CameraRotationSettings.rotationDelayTexts,
    g_i18n:getText("settingTitle_rotationDelay"),
    g_i18n:getText("settingDescription_rotationDelay"),
    delayInitialState
  )
  
  local maxAngleInitialState = 1
  closestIndex = 1
  closestDiff = math.abs(CameraRotationSettings.maxRotationAngle - CameraRotationSettings.maxRotationAngleValues[1])
  for i, value in ipairs(CameraRotationSettings.maxRotationAngleValues) do
    local diff = math.abs(CameraRotationSettings.maxRotationAngle - value)
    if diff < closestDiff then
      closestDiff = diff
      closestIndex = i
    end
  end
  maxAngleInitialState = closestIndex
  
  CameraRotationSettings.maxRotationAngleOption = CameraRotationSettings:addMultiTextOption(
    self,
    "onMaxRotationAngleChanged",
    CameraRotationSettings.maxRotationAngleTexts,
    g_i18n:getText("settingTitle_maxRotationAngle"),
    g_i18n:getText("settingDescription_maxRotationAngle"),
    maxAngleInitialState
  )
  
  CameraRotationSettings.reverseFlipOption = CameraRotationSettings:addCheckboxOption(
    self,
    "onReverseFlipChanged",
    g_i18n:getText("settingTitle_reverseFlip"),
    g_i18n:getText("settingDescription_reverseFlip"),
    CameraRotationSettings.reverseFlip
  )

  self.gameSettingsLayout:invalidateLayout()
  self:updateAlternatingElements(self.gameSettingsLayout)
  self:updateGeneralSettings(self.gameSettingsLayout)

  self.settingsDone = true
  CameraRotationSettings:updateSettings()
end

-- Updates settings UI elements to reflect current values
function CameraRotationSettings:updateSettings()
  if self.enabledOption ~= nil then
    if self.enabledOption.setIsChecked ~= nil then
      local currentState = self.enabledOption:getIsChecked()
      if currentState ~= self.isEnabled then
        self.isUpdatingFromKeybind = true
        self.enabledOption:setIsChecked(self.isEnabled)
        self.isUpdatingFromKeybind = false
      end
    end
  end
  
  if self.thirdPersonRotationOption ~= nil then
    if self.thirdPersonRotationOption.setIsChecked ~= nil then
      self.thirdPersonRotationOption:setIsChecked(self.thirdPersonRotation)
    end
  end
  
  if self.rotationSpeedOption ~= nil then
    local closestIndex = 1
    local closestDiff = math.abs(self.rotationSpeed - self.rotationSpeedValues[1])
    for i, value in ipairs(self.rotationSpeedValues) do
      local diff = math.abs(self.rotationSpeed - value)
      if diff < closestDiff then
        closestDiff = diff
        closestIndex = i
      end
    end
    self.rotationSpeedOption:setState(closestIndex)
  end
  
  if self.rotationDelayOption ~= nil then
    local closestIndex = 1
    local closestDiff = math.abs(self.rotationDelay - self.rotationDelayValues[1])
    for i, value in ipairs(self.rotationDelayValues) do
      local diff = math.abs(self.rotationDelay - value)
      if diff < closestDiff then
        closestDiff = diff
        closestIndex = i
      end
    end
    self.rotationDelayOption:setState(closestIndex)
  end
  
  if self.maxRotationAngleOption ~= nil then
    local closestIndex = 1
    local closestDiff = math.abs(self.maxRotationAngle - self.maxRotationAngleValues[1])
    for i, value in ipairs(self.maxRotationAngleValues) do
      local diff = math.abs(self.maxRotationAngle - value)
      if diff < closestDiff then
        closestDiff = diff
        closestIndex = i
      end
    end
    self.maxRotationAngleOption:setState(closestIndex)
  end
  
  if self.reverseFlipOption ~= nil then
    if self.reverseFlipOption.setIsChecked ~= nil then
      self.reverseFlipOption:setIsChecked(self.reverseFlip)
    end
  end
end

function CameraRotationSettings:onEnabledChanged(state, element)
  -- Ignore callback if we're programmatically updating from keybind
  if self.isUpdatingFromKeybind then
    return
  end
  
  if element ~= nil and element.getIsChecked ~= nil then
    self.isEnabled = element:getIsChecked()
  else
    self.isEnabled = (state == 2)
  end
  self:save()
  if self.cachedFrame ~= nil then
    self.cachedFrame:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
  end
end

function CameraRotationSettings:onThirdPersonRotationChanged(state, element)
  if element ~= nil and element.getIsChecked ~= nil then
    self.thirdPersonRotation = element:getIsChecked()
  else
    self.thirdPersonRotation = (state == 2)
  end
  self:save()
  if self.cachedFrame ~= nil then
    self.cachedFrame:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
  end
end

function CameraRotationSettings:onRotationSpeedChanged(state)
  if state >= 1 and state <= #self.rotationSpeedValues then
    self:setRotationSpeed(self.rotationSpeedValues[state])
    if self.cachedFrame ~= nil then
      self.cachedFrame:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
    end
  end
end

function CameraRotationSettings:onRotationDelayChanged(state)
  if state >= 1 and state <= #self.rotationDelayValues then
    self:setRotationDelay(self.rotationDelayValues[state])
    if self.cachedFrame ~= nil then
      self.cachedFrame:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
    end
  end
end

function CameraRotationSettings:onMaxRotationAngleChanged(state)
  if state >= 1 and state <= #self.maxRotationAngleValues then
    self:setMaxRotationAngle(self.maxRotationAngleValues[state])
    if self.cachedFrame ~= nil then
      self.cachedFrame:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
    end
  end
end

function CameraRotationSettings:onReverseFlipChanged(state, element)
  if element ~= nil and element.getIsChecked ~= nil then
    self.reverseFlip = element:getIsChecked()
  else
    self.reverseFlip = (state == 2)
  end
  self:save()
  if self.cachedFrame ~= nil then
    self.cachedFrame:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
  end
end

-- Registers hook into vanilla settings menu to add mod settings
function CameraRotationSettings:registerGameSettings()
  if InGameMenuSettingsFrame ~= nil and InGameMenuSettingsFrame.onFrameOpen ~= nil then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, CameraRotationSettings.onFrameOpen)
  end
end

function CameraRotationSettings:consoleCommandSetRotationSpeed(value)
  value = tonumber(value)
  if value ~= nil then
    self:setRotationSpeed(value)
  end
end

function CameraRotationSettings:consoleCommandSetRotationDelay(value)
  value = tonumber(value)
  if value ~= nil then
    self:setRotationDelay(value)
  end
end

function CameraRotationSettings:consoleCommandSetEnabled(value)
  if value == "true" or value == "1" then
    self:setEnabled(true)
  elseif value == "false" or value == "0" then
    self:setEnabled(false)
  end
end

if addConsoleCommand ~= nil then
  addConsoleCommand("modCameraRotationSpeed", "", "consoleCommandSetRotationSpeed", CameraRotationSettings)
  addConsoleCommand("modCameraRotationDelay", "", "consoleCommandSetRotationDelay", CameraRotationSettings)
  addConsoleCommand("modCameraRotationEnabled", "", "consoleCommandSetEnabled", CameraRotationSettings)
end
