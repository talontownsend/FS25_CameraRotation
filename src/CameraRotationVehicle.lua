-- Camera Rotation Vehicle Logic
-- Handles camera rotation based on steering angle and reverse direction

CameraRotationVehicle = {}

-- Returns the vehicle's steering node for rotation calculations
local function getSteeringNode(vehicle)
  local n
  if type(vehicle.getAIRootNode) == "function" then 
    n = vehicle:getAIRootNode()
    if n ~= nil then 
      return n
    end 
  end 
  if vehicle.steeringAxleNode ~= nil and vehicle.steeringAxleNode ~= 0 then 
    return vehicle.steeringAxleNode
  end 
  if vehicle.components ~= nil and vehicle.components[1] ~= nil and vehicle.components[1].node ~= nil then
    return vehicle.components[1].node
  end
  return nil
end

local function getRelativeYRotation(root, node)
  if root == nil or node == nil then
    return 0
  end
  local x, y, z = worldDirectionToLocal(node, localDirectionToWorld(root, 0, 0, 1))
  local dot = z
  local len = 0
  if math.abs(z) < 1e-6 then 
    len = math.abs(x)
  elseif math.abs(x) < 1e-6 then 
    len = math.abs(z) 
  else 
    len = math.sqrt(x*x + z*z)
  end 
  dot = dot / len
  local angle = math.acos(dot)
  if x < 0 then
    angle = -angle
  end
  return angle
end

-- Normalizes angle to -π to π range
local function normalizeAngle(angle)
  local normalizedAngle = angle
  while normalizedAngle > math.pi do
    normalizedAngle = normalizedAngle - math.pi - math.pi
  end 
  while normalizedAngle <= -math.pi do
    normalizedAngle = normalizedAngle + math.pi + math.pi
  end
  return normalizedAngle
end

-- Normalizes camera angle to 0 to 2π range
local function normalizeAngleCam(angle)
  local normalizedAngle = angle
  while normalizedAngle > math.pi + math.pi do
    normalizedAngle = normalizedAngle - math.pi - math.pi
  end 
  while normalizedAngle < 0 do
    normalizedAngle = normalizedAngle + math.pi + math.pi
  end
  return normalizedAngle
end

local function clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
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

-- Calculates absolute rotation Y relative to steering node
local function getAbsolutRotY(vehicle, camIndex)
  if not isValidCam(vehicle, camIndex) then
    return 0
  end
  local camera = vehicle.spec_enterable.cameras[camIndex]
  local steeringNode = getSteeringNode(vehicle)
  if steeringNode == nil then
    return 0
  end
  return getRelativeYRotation(camera.cameraNode, steeringNode)
end

local function isVehicleControlledByPlayer(vehicle)
  if vehicle.getIsVehicleControlledByPlayer == nil then
    return false
  end
  return vehicle:getIsVehicleControlledByPlayer()
end

-- Determines if vehicle is moving forward based on direction and motor state
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

-- Main camera rotation update function
-- Applies steering-based rotation and reverse flip based on mod settings
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
      lastCamRotY = nil,
      lastCamFwd = nil,
      lastFactor = 0
    }
  end

  local spec = vehicle.spec_cameraRotation
  local isForwardDir = isForward(vehicle)

  if spec.lastCamIndex == nil or spec.lastCamIndex ~= i then
    if spec.lastCamIndex ~= nil and spec.zeroCamRotY ~= nil and spec.lastCamRotY ~= nil and isValidCam(vehicle, spec.lastCamIndex) then
      local oldCam = vehicle.spec_enterable.cameras[spec.lastCamIndex]
      oldCam.rotY = normalizeAngleCam(spec.zeroCamRotY + oldCam.rotY - spec.lastCamRotY)
    end
    spec.lastCamIndex = i
    spec.zeroCamRotY = camera.rotY
    spec.lastCamRotY = camera.rotY
    spec.lastCamFwd = nil
  end

  local pi2 = math.pi / 2
  local oldRotY = camera.rotY
  local diff = oldRotY - spec.lastCamRotY

  if diff ~= 0 then
    spec.zeroCamRotY = spec.zeroCamRotY + diff
  end

  local aRotY = normalizeAngle(getAbsolutRotY(vehicle, i) - camera.rotY + spec.zeroCamRotY)
  local isRev = false
  if -pi2 < aRotY and aRotY < pi2 then
    isRev = true
  end

  if CameraRotationSettings.reverseFlip then
    if spec.lastCamFwd == nil or spec.lastCamFwd ~= isForwardDir then
      if isRev == isForwardDir then
        if math.abs(spec.zeroCamRotY - math.pi) < 0.1 then 
          spec.zeroCamRotY = 0
        elseif spec.zeroCamRotY > math.pi + math.pi - 0.1 then 
          spec.zeroCamRotY = math.pi
        elseif spec.zeroCamRotY < 0.1 then 
          spec.zeroCamRotY = math.pi
        elseif spec.zeroCamRotY >= math.pi then 
          spec.zeroCamRotY = spec.zeroCamRotY - math.pi 
        else 
          spec.zeroCamRotY = spec.zeroCamRotY + math.pi 
        end
        spec.zeroCamRotY = normalizeAngleCam(spec.zeroCamRotY)
        isRev = not isRev
      end
    end
    spec.lastCamFwd = isForwardDir
  end

  local newRotY = spec.zeroCamRotY

  local rotIsOn = 2
  if rotIsOn > 0 and vehicle.rotatedTime ~= nil then
    -- Calculate steering factor from vehicle rotation time
    local f = 0
    if vehicle.rotatedTime > 0 and vehicle.maxRotTime ~= nil and vehicle.maxRotTime > 0 then
      f = vehicle.rotatedTime / vehicle.maxRotTime
    elseif vehicle.rotatedTime < 0 and vehicle.minRotTime ~= nil and vehicle.minRotTime < 0 then
      f = vehicle.rotatedTime / vehicle.minRotTime
    end

    -- Apply curve to steering input (dead zone below 0.1)
    if f < 0.1 then
      f = 0
    else
      f = 1.2345679 * (f - 0.1) * (f - 0.1) / 0.81
    end

    -- Normalize direction
    if vehicle.rotatedTime < 0 then
      f = -f
    end

    -- Apply spring arm delay (smoothing) - how long it takes to respond to steering
    local maxChange = CameraRotationSettings.rotationDelay * dt
    spec.lastFactor = spec.lastFactor + clamp(f - spec.lastFactor, -maxChange, maxChange)
    local smoothedF = spec.lastFactor

    -- Calculate target rotation offset based on steering input
    -- Target is always based on maxRotationAngle (independent of rotationSpeed)
    -- Invert rotation direction when reverse flip is active and we're in reverse
    local rotationDirection = 1
    if CameraRotationSettings.reverseFlip and isRev then
      rotationDirection = -1
    end
    local targetRotationOffset = smoothedF * CameraRotationSettings.maxRotationAngle * rotationDirection
    
    -- Get current rotation offset from zero position
    local currentRotationOffset = normalizeAngle(newRotY - spec.zeroCamRotY)
    
    -- Calculate difference to target
    local rotationDiff = normalizeAngle(targetRotationOffset - currentRotationOffset)
    
    -- Apply rotation speed as rate coefficient (how fast we move towards target)
    -- rotationSpeed is a linear coefficient: scales the rotation rate per unit of steering
    local rotationDelta = rotationDiff * CameraRotationSettings.rotationSpeed * dt * 10
    
    -- Clamp rotation delta to prevent overshooting
    if math.abs(rotationDelta) > math.abs(rotationDiff) then
      rotationDelta = rotationDiff
    end
    
    -- Apply rotation
    newRotY = newRotY + rotationDelta
    
    -- Apply rotation limit (max angle from forward vector, excluding reverse flip)
    -- This is the hard limit that should never be exceeded
    local maxAngle = CameraRotationSettings.maxRotationAngle
    local finalRotationOffset = normalizeAngle(newRotY - spec.zeroCamRotY)
    
    if math.abs(finalRotationOffset) > maxAngle then
      if finalRotationOffset > 0 then
        newRotY = spec.zeroCamRotY + maxAngle
      else
        newRotY = spec.zeroCamRotY - maxAngle
      end
      newRotY = normalizeAngleCam(newRotY)
    end
  else
    spec.lastFactor = 0
  end

  -- Apply rotation to camera
  camera.rotY = normalizeAngleCam(newRotY)

  spec.lastCamRotY = camera.rotY
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

