-- Camera Rotation mod entry point
-- Initializes settings and registers vehicle update hooks

if not g_dedicatedServerInfo then

CameraRotation = {}

local modDirectory = g_currentModDirectory

source(modDirectory .. "src/CameraRotationSettings.lua")
source(modDirectory .. "src/CameraRotationVehicle.lua")

CameraRotationSettings:load()

-- Delayed initialization to ensure other mods load first
function CameraRotation:update(dt)
  self.delayCount = (self.delayCount or 0) + 1
  if self.delayCount == 10 then
    CameraRotationSettings:registerGameSettings()
    CameraRotationVehicle:registerVehicleUpdate()
    
    -- Register action events hook for keybind
    if Enterable ~= nil and Enterable.onRegisterActionEvents ~= nil then
      Enterable.onRegisterActionEvents = Utils.overwrittenFunction(Enterable.onRegisterActionEvents, function(self, superFunc, isActiveForInput, isActiveForInputIgnoreSelection, ...)
        superFunc(self, isActiveForInput, isActiveForInputIgnoreSelection, ...)
        CameraRotationVehicle.registerActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
      end)
    end
  end
end

addModEventListener(CameraRotation)

end

