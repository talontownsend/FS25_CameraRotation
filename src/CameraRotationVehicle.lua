-- Camera Rotation Vehicle Logic (Heading-Trail model)
-- The third-person camera trails the vehicle's WORLD HEADING with spring
-- damping -- like the chase cameras in GTA V / Forza Horizon. It reacts to how
-- the chassis actually turns through the world, NOT to the steering-wheel angle,
-- so it never swings while stationary and settles smoothly behind you.

CameraRotationVehicle = {}

-- Sign of the trail injection. If the camera LEADS into turns instead of
-- trailing behind them, flip this to 1.
local TRAIL_SIGN = -1

-- Speed window (km/h) over which trailing fades in. Below MIN it is fully off
-- (so pivoting in place / parking never swings the view); at/above FULL it is
-- fully engaged.
local TRAIL_SPEED_MIN = 2.0
local TRAIL_SPEED_FULL = 12.0

local function clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- Normalizes angle to (-pi, pi]
local function normalizeAngle(angle)
  local a = angle
  while a > math.pi do a = a - 2 * math.pi end
  while a <= -math.pi do a = a + 2 * math.pi end
  return a
end

-- Normalizes angle to [0, 2pi)
local function normalizeAngleCam(angle)
  local a = angle
  while a >= 2 * math.pi do a = a - 2 * math.pi end
  while a < 0 do a = a + 2 * math.pi end
  return a
end

-- Chassis body node (NOT the steering axle -- we want the body's heading).
local function getBodyNode(vehicle)
  if vehicle.components ~= nil and vehicle.components[1] ~= nil and vehicle.components[1].node ~= nil then
    return vehicle.components[1].node
  end
  if vehicle.rootNode ~= nil and vehicle.rootNode ~= 0 then
    return vehicle.rootNode
  end
  return nil
end

-- World heading (yaw, radians) of the vehicle body from its forward vector.
local function getVehicleHeading(node)
  if node == nil then
    return nil
  end
  local dx, _, dz = localDirectionToWorld(node, 0, 0, 1)
  if MathUtil ~= nil and MathUtil.getYRotationFromDirection ~= nil then
    return MathUtil.getYRotationFromDirection(dx, dz)
  end
  return math.atan2(dx, dz)
end

-- Checks if camera exists and is rotatable
local function isValidCam(vehicle, camIndex)
  if vehicle.spec_enterable == nil or vehicle.spec_enterable.cameras == nil then
    return false
  end
  if camIndex == nil then
    camIndex = vehicle.spec_enterable.camIndex
  end
  if camIndex == nil or vehicle.spec_enterable.cameras[camIndex] == nil then
    return false
  end
  local camera = vehicle.spec_enterable.cameras[camIndex]
  return camera.vehicle == vehicle and camera.isRotatable
end

local function isVehicleControlledByPlayer(vehicle)
  if vehicle.getIsVehicleControlledByPlayer == nil then
    return false
  end
  return vehicle:getIsVehicleControlledByPlayer()
end

-- Determines if the vehicle is travelling forward (for the optional reverse flip)
local function isForward(vehicle)
  if vehicle.movingDirection == nil then
    return true
  end
  if math.abs(vehicle:getLastSpeed()) < 5 then
    if vehicle.spec_motorized ~= nil and vehicle.spec_motorized.motor ~= nil then
      local motor = vehicle.spec_motorized.motor
      if motor.currentDirection < 0 then
        return false
      elseif motor.currentDirection > 0 then
        return true
      end
    end
  elseif vehicle.movingDirection < 0 then
    return false
  elseif vehicle.movingDirection > 0 then
    return true
  end
  return true
end

-- Main per-frame update: trail the camera behind the vehicle's heading.
local function updateCameraRotation(vehicle, dt)
  if not CameraRotationSettings.isEnabled then
    return
  end

  if not vehicle:getIsActive() or not vehicle.isClient then
    return
  end

  if not isVehicleControlledByPlayer(vehicle) then
    return
  end

  if vehicle.spec_enterable == nil or vehicle.spec_enterable.cameras == nil then
    return
  end

  local i = vehicle.spec_enterable.camIndex
  if i == nil or vehicle.spec_enterable.cameras[i] == nil then
    return
  end

  local camera = vehicle.spec_enterable.cameras[i]
  if not camera.isRotatable or camera.vehicle ~= vehicle then
    return
  end

  local isInside = camera.isInside
  if not isInside and not CameraRotationSettings.thirdPersonRotation then
    return
  end

  if vehicle.spec_cameraRotation == nil then
    vehicle.spec_cameraRotation = {
      lastCamIndex = nil,
      zeroCamRotY = nil,
      lastAppliedRotY = nil,
      lastHeading = nil,
      lastCamFwd = nil,
      trail = 0
    }
  end

  local spec = vehicle.spec_cameraRotation

  -- Reset the baseline whenever the active camera changes.
  if spec.lastCamIndex ~= i then
    spec.lastCamIndex = i
    spec.zeroCamRotY = camera.rotY
    spec.lastAppliedRotY = camera.rotY
    spec.lastHeading = nil
    spec.lastCamFwd = nil
    spec.trail = 0
  end

  -- Absorb the player's manual look (mouse pan) since last frame into the
  -- neutral, so trailing rides on top of wherever the player aimed the view.
  local manualDiff = normalizeAngle(camera.rotY - spec.lastAppliedRotY)
  if manualDiff ~= 0 then
    spec.zeroCamRotY = spec.zeroCamRotY + manualDiff
  end

  -- Optional 180-degree flip of the neutral when switching forward <-> reverse.
  local isForwardDir = isForward(vehicle)
  if CameraRotationSettings.reverseFlip then
    if spec.lastCamFwd ~= nil and spec.lastCamFwd ~= isForwardDir then
      spec.zeroCamRotY = spec.zeroCamRotY + math.pi
    end
    spec.lastCamFwd = isForwardDir
  end

  -- Heading delta of the chassis this frame.
  local heading = getVehicleHeading(getBodyNode(vehicle))
  local deltaHeading = 0
  if heading ~= nil and spec.lastHeading ~= nil then
    deltaHeading = normalizeAngle(heading - spec.lastHeading)
  end
  spec.lastHeading = heading

  -- Fade trailing in with speed so parking / pivoting doesn't swing the view.
  local speed = math.abs(vehicle:getLastSpeed())
  local speedFactor = clamp((speed - TRAIL_SPEED_MIN) / (TRAIL_SPEED_FULL - TRAIL_SPEED_MIN), 0, 1)

  local strength = CameraRotationSettings.rotationSpeed    -- reused: trail intensity (0..~1.2)
  local tau = CameraRotationSettings.rotationDelay         -- reused: catch-up time constant (seconds)
  local maxAngle = CameraRotationSettings.maxRotationAngle

  -- Inject lag: the camera briefly holds its world direction as the body turns.
  spec.trail = spec.trail + TRAIL_SIGN * deltaHeading * strength * speedFactor

  -- Spring the trail back toward centered (catch up to the vehicle heading).
  -- Frame-rate independent exponential decay with time constant tau.
  if tau > 0.0001 then
    local relax = 1 - math.exp(-(dt / 1000) / tau)
    spec.trail = spec.trail - spec.trail * relax
  else
    spec.trail = 0
  end

  -- When effectively stopped, actively re-center so the view settles behind you.
  if speedFactor <= 0 and math.abs(spec.trail) < 0.0005 then
    spec.trail = 0
  end

  -- Clamp so the camera never swings past the limit.
  spec.trail = clamp(spec.trail, -maxAngle, maxAngle)

  local newRotY = normalizeAngleCam(spec.zeroCamRotY + spec.trail)
  camera.rotY = newRotY
  spec.lastAppliedRotY = newRotY
end

-- Registers hook into Vehicle.update to apply camera rotation each frame
function CameraRotationVehicle:registerVehicleUpdate()
  if Vehicle ~= nil and Vehicle.update ~= nil then
    Vehicle.update = Utils.appendedFunction(Vehicle.update, function(self, dt)
      if self.spec_enterable ~= nil and self.spec_enterable.cameras ~= nil then
        updateCameraRotation(self, dt)
      end
    end)
  end
end

-- Handles keybind toggle action
local function onToggleCameraRotation(vehicle, actionName, inputValue, callbackState, isAnalog)
  if inputValue == 1 then
    CameraRotationSettings.isEnabled = not CameraRotationSettings.isEnabled
    CameraRotationSettings:save()

    -- Update UI if settings frame is open
    if CameraRotationSettings.enabledOption ~= nil then
      CameraRotationSettings:updateSettings()
    end
  end
end

-- Registers action event for toggle keybind
local function registerActionEvents(vehicle, isActiveForInput, isActiveForInputIgnoreSelection)
  if vehicle == nil or not vehicle.isClient then
    return
  end

  if vehicle.spec_enterable == nil or not vehicle:getIsEntered() or not vehicle:getIsActiveForInput(true, true) then
    return
  end

  local spec = vehicle.spec_enterable

  if spec.actionEvents == nil then
    spec.actionEvents = {}
  end

  if isActiveForInputIgnoreSelection then
    local inputAction = InputAction["CAMERA_ROTATION_TOGGLE"] or InputAction.CAMERA_ROTATION_TOGGLE
    if inputAction ~= nil then
      local success, actionEventId = vehicle:addActionEvent(spec.actionEvents, inputAction, vehicle, onToggleCameraRotation, false, true, false, true, nil, nil, nil, true)
      if success and actionEventId ~= nil then
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(actionEventId, false)
      end
    end
  end
end

CameraRotationVehicle.registerActionEvents = registerActionEvents
