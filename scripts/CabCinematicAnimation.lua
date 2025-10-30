CabCinematicAnimation = {
  timer = 0,
  isActive = false,
  isPaused = false,
  isEnded = false,
  type = nil,
  vehicle = nil,
  camera = nil,
  finishCallback = nil,
  keyframes = nil,

  playerSnapshot = nil,
  duration = 0.0,
  currentKeyFrameIndex = 1,
}

CabCinematicAnimation.TYPES = {
  ENTER = "enter",
  LEAVE = "leave",
}

-- Angles constants pour faciliter la configuration
local ANGLE_STRAIGHT = 0           -- 0° = tout droit vers la destination
local ANGLE_LEFT_90 = -math.pi / 2 -- -90° = complètement à gauche



CabCinematicAnimation.PRESETS = {
  combineDrivable = {
    harvesters = {
      { type = CabCinematicAnimationKeyframe.TYPES.CLIMB_LADDER },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK },
      { type = CabCinematicAnimationKeyframe.TYPES.SEAT },
    },
    forageharvesters = {
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,         angle = ANGLE_STRAIGHT },
      { type = CabCinematicAnimationKeyframe.TYPES.CLIMB_STAIRS, angle = ANGLE_LEFT_90 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,         angle = ANGLE_LEFT_90 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK },
      { type = CabCinematicAnimationKeyframe.TYPES.SEAT },
    },
  },
  tractor = {
    tractorsm = {
      { type = CabCinematicAnimationKeyframe.TYPES.CLIMB_LADDER },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK },
      { type = CabCinematicAnimationKeyframe.TYPES.SEAT },
    },
  },
}

CabCinematicAnimation.PRE_MOVEMENT_DISTANCE = 1.0
CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_PLAYER_SPEED = 6.9
CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_VEHICLE_SPEED = 8.0

local CabCinematicAnimation_mt = Class(CabCinematicAnimation)

function CabCinematicAnimation.new(type, vehicle, camera, finishCallback)
  Log:info(string.format("Created CabCinematicAnimation of type %s for vehicle %s", type, vehicle.typeName))

  local self = setmetatable({}, CabCinematicAnimation_mt)
  self.type = type
  self.vehicle = vehicle
  self.camera = camera
  self.finishCallback = finishCallback
  return self
end

function CabCinematicAnimation:delete()

end

function CabCinematicAnimation:getIsActive()
  return self.isActive
end

function CabCinematicAnimation:getIsEnded()
  return self.isEnded
end

function CabCinematicAnimation:getIsPaused()
  return self.isPaused
end

function CabCinematicAnimation:getVehicleCategory()
  local categoryName = "unknown"
  local storeItem = g_storeManager:getItemByXMLFilename(self.vehicle.configFileName)
  if storeItem ~= nil and storeItem.categoryName ~= nil then
    categoryName = string.lower(storeItem.categoryName)
  end
  return categoryName
end

function CabCinematicAnimation:getVehiclePreset()
  if CabCinematicAnimation.PRESETS[self.vehicle.typeName] ~= nil then
    local vehicleCategory = self:getVehicleCategory()
    if CabCinematicAnimation.PRESETS[self.vehicle.typeName][vehicleCategory] ~= nil then
      return CabCinematicAnimation.PRESETS[self.vehicle.typeName][vehicleCategory]
    else
      Log:warning(string.format("No preset found for vehicle type %s and category %s", self.vehicle.typeName,
        vehicleCategory))
      return nil
    end
  else
    Log:warning(string.format("No preset found for vehicle type %s", self.vehicle.typeName))
    return nil
  end
end

function CabCinematicAnimation:getVehicleExitNodeAdjustedPosition()
  local _, wpy, _ = getWorldTranslation(getParent(g_localPlayer.camera.firstPersonCamera))
  local wex, _, wez = getWorldTranslation(self.vehicle:getExitNode())
  local wty = getTerrainHeightAtWorldPos(g_terrainNode, wex, 0, wez) + 0.1
  return worldToLocal(self.vehicle.rootNode, wex, wty + (wpy - wty), wez)
end

function CabCinematicAnimation:getPreMovementKeyframe()
  if self.playerSnapshot == nil then
    return nil
  end

  local plx, ply, plz = self.playerSnapshot:getLocalPosition(self.vehicle.rootNode)
  local elx, ely, elz = self:getVehicleExitNodeAdjustedPosition()

  local playerDistance = MathUtil.vector3Length(elx - plx, ely - ply, elz - plz)

  if playerDistance > CabCinematicAnimation.PRE_MOVEMENT_DISTANCE then
    Log:info(string.format(
      "Calculating pre-movement keyframe - Player position (%.2f, %.2f, %.2f), ExitNode position (%.2f, %.2f, %.2f) - Distance: %.2f",
      plx, ply, plz, elx, ely, elz, playerDistance))

    if self.vehicle:getLastSpeed() >= CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_VEHICLE_SPEED then
      return CabCinematicAnimationKeyframe.new(CabCinematicAnimationKeyframe.TYPES.RUN, { plx, ply, plz },
        { elx, ely, elz })
    else
      if self.playerSnapshot ~= nil and self.playerSnapshot.speed >= CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_PLAYER_SPEED then
        return CabCinematicAnimationKeyframe.new(CabCinematicAnimationKeyframe.TYPES.RUN, { plx, ply, plz },
          { elx, ely, elz })
      else
        return CabCinematicAnimationKeyframe.new(CabCinematicAnimationKeyframe.TYPES.WALK, { plx, ply, plz },
          { elx, ely, elz })
      end
    end
  else
    Log:info(string.format("No pre-movement keyframe needed - distance: %.2f", playerDistance))
  end

  return nil
end

function CabCinematicAnimation:getStartPosition()
  if (self.type == CabCinematicAnimation.TYPES.ENTER) then
    return { self:getVehicleExitNodeAdjustedPosition() }
  else
    return { getTranslation(self.vehicle:getVehicleInteriorCamera().cameraPositionNode) }
  end
end

function CabCinematicAnimation:getEndPosition()
  if (self.type == CabCinematicAnimation.TYPES.ENTER) then
    return { getTranslation(self.vehicle:getVehicleInteriorCamera().cameraPositionNode) }
  else
    return { self:getVehicleExitNodeAdjustedPosition() }
  end
end

function CabCinematicAnimation:buildKeyframes(startPosition, endPosition)
  Log:info(string.format(
    "Building keyframes from start position (%.2f, %.2f, %.2f) to end position (%.2f, %.2f, %.2f)",
    startPosition[1], startPosition[2], startPosition[3],
    endPosition[1], endPosition[2], endPosition[3]))

  local vehiclePreset = self:getVehiclePreset()
  if vehiclePreset == nil then
    Log:error("No vehicle preset found, cannot build keyframes")
    return {}
  end

  local preset = {}

  if (self.type == CabCinematicAnimation.TYPES.LEAVE) then
    for i = #vehiclePreset, 1, -1 do
      table.insert(preset, vehiclePreset[i])
    end
  else
    preset = vehiclePreset
  end


  local keyframes = {}

  local keyframeTypesCounts = {}
  for _, keyframeData in ipairs(preset) do
    local keyframeType = keyframeData.type or keyframeData
    keyframeTypesCounts[keyframeType] = (keyframeTypesCounts[keyframeType] or 0) + 1
  end

  local keyframeTypesProgress = {}
  local previousProgress = {}
  for keyframeType, _ in pairs(keyframeTypesCounts) do
    keyframeTypesProgress[keyframeType] = 0
    previousProgress[keyframeType] = 0
  end

  local deltaX = endPosition[1] - startPosition[1]
  local deltaY = endPosition[2] - startPosition[2]
  local deltaZ = endPosition[3] - startPosition[3]

  local totalContributionX = 0
  local totalContributionZ = 0

  for _, keyframeData in ipairs(preset) do
    local keyframeType = keyframeData.type or keyframeData
    if keyframeType ~= CabCinematicAnimationKeyframe.TYPES.SEAT then
      if keyframeData.angle == nil then
        totalContributionX = totalContributionX + 0.5
        totalContributionZ = totalContributionZ + 0.5
      else
        local clampedAngle = math.max(-math.pi / 2, math.min(math.pi / 2, keyframeData.angle))
        local factorX, factorZ = 0, 0
        if clampedAngle == 0 then
          factorX, factorZ = 1.0, 0.0
        elseif clampedAngle == -math.pi / 2 then
          factorX, factorZ = 0.0, 1.0
        elseif clampedAngle == math.pi / 2 then
          factorX, factorZ = 0.0, -1.0
        else
          local normalizedAngle = clampedAngle / (math.pi / 2)
          factorX = 1.0 - math.abs(normalizedAngle)
          factorZ = normalizedAngle
        end
        totalContributionX = totalContributionX + math.abs(factorX)
        totalContributionZ = totalContributionZ + math.abs(factorZ)
      end
    end
  end

  local currentPosition = { startPosition[1], startPosition[2], startPosition[3] }
  for _, keyframeData in ipairs(preset) do
    local keyframeType = keyframeData.type

    keyframeTypesProgress[keyframeType] = keyframeTypesProgress[keyframeType] + 1
    local currentProgress = keyframeTypesProgress[keyframeType] / keyframeTypesCounts[keyframeType]
    local incrementalProgress = currentProgress - previousProgress[keyframeType]
    previousProgress[keyframeType] = currentProgress

    local progressY = 0
    if keyframeType == CabCinematicAnimationKeyframe.TYPES.CLIMB_LADDER_VERTICAL then
      progressY = incrementalProgress
    elseif keyframeType == CabCinematicAnimationKeyframe.TYPES.CLIMB_LADDER then
      progressY = incrementalProgress
    elseif keyframeType == CabCinematicAnimationKeyframe.TYPES.CLIMB_STAIRS then
      progressY = incrementalProgress
    end

    local baseDeltaY = deltaY * progressY

    local nextPosition
    Log:info(string.format("Processing keyframe %s, angle = %s", keyframeType, tostring(keyframeData.angle)))

    if keyframeType == CabCinematicAnimationKeyframe.TYPES.SEAT then
      nextPosition = { currentPosition[1], currentPosition[2], currentPosition[3] }
    else
      local factorX, factorZ = 0.5, 0.5

      if keyframeData.angle ~= nil then
        Log:info(string.format("Using angle %.1f°", math.deg(keyframeData.angle)))
        local clampedAngle = math.max(-math.pi / 2, math.min(math.pi / 2, keyframeData.angle))

        if clampedAngle == 0 then
          factorX = 1.0
          factorZ = 0.0
        elseif clampedAngle == -math.pi / 2 then
          factorX = 0.0
          factorZ = 1.0
        elseif clampedAngle == math.pi / 2 then
          factorX = 0.0
          factorZ = -1.0
        else
          local normalizedAngle = clampedAngle / (math.pi / 2)
          factorX = 1.0 - math.abs(normalizedAngle)
          factorZ = normalizedAngle
        end
      end

      local contributionX = math.abs(factorX) / totalContributionX
      local contributionZ = math.abs(factorZ) / totalContributionZ

      local movementX = deltaX * contributionX * (factorX >= 0 and 1 or -1)
      local movementZ = deltaZ * contributionZ * (factorZ >= 0 and 1 or -1)

      nextPosition = {
        currentPosition[1] + movementX,
        currentPosition[2] + baseDeltaY,
        currentPosition[3] + movementZ,
      }

      Log:info(string.format("  Factors: X=%.2f, Z=%.2f, Contributions: X=%.2f, Z=%.2f",
        factorX, factorZ, contributionX, contributionZ))
    end
    table.insert(keyframes, CabCinematicAnimationKeyframe.new(keyframeType, currentPosition, nextPosition))
    currentPosition = nextPosition
  end

  return keyframes
end

function CabCinematicAnimation:prepare()
  local startPosition = self:getStartPosition()
  local endPosition = self:getEndPosition()
  self.keyframes = self:buildKeyframes(startPosition, endPosition)

  if (self.type == CabCinematicAnimation.TYPES.ENTER) then
    local preMovementKeyframe = self:getPreMovementKeyframe()
    if (preMovementKeyframe ~= nil) then
      table.insert(self.keyframes, 1, preMovementKeyframe)
    end
  end

  self.duration = 0
  for _, keyframe in ipairs(self.keyframes) do
    self.duration = self.duration + keyframe:getDuration()
  end
end

function CabCinematicAnimation:syncAnimationCamerasAtStart()
  if self.type ~= CabCinematicAnimation.TYPES.ENTER then
    return
  end

  local cinematicCamera = self.camera
  local vehicleCamera = self.vehicle:getVehicleInteriorCamera();

  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  setFovY(g_localPlayer.getCurrentCameraNode(), fovY)
  setFovY(cinematicCamera.cameraNode, fovY)
  setFovY(vehicleCamera.cameraNode, fovY)

  local dx, dy, dz = localDirectionToWorld(g_localPlayer.camera.cameraRootNode, 0, 0, 1)

  local rotateNodeParent = getParent(vehicleCamera.rotateNode)
  local localDx, localDy, localDz = worldDirectionToLocal(rotateNodeParent, dx, dy, dz)

  local rotX = -math.asin(localDy)
  local rotY = math.atan2(localDx, localDz)

  vehicleCamera.rotX = rotX
  vehicleCamera.rotY = rotY
  vehicleCamera.rotZ = 0

  Log:info(string.format("syncCamerasAtAnimationStart: setting target camera rotation to (%.2f, %.2f, %.2f)",
    rotX, rotY, 0))

  vehicleCamera:updateRotateNodeRotation()
end

function CabCinematicAnimation:syncAnimationCamerasAtStop()
  if self.type ~= CabCinematicAnimation.TYPES.LEAVE then
    return
  end

  local cinematicCamera = self.camera
  local playerCamera = g_localPlayer.camera

  local dx, dy, dz = localDirectionToWorld(cinematicCamera.cameraNode, 0, 0, 1)

  local pitch = math.asin(dy)
  local yaw = math.atan2(dx, dz) + math.pi

  Log:info(string.format("syncCamerasAtAnimationStop: setting player camera rotation to (%.2f, %.2f, %.2f)",
    pitch, yaw, 0))

  playerCamera:setRotation(pitch, yaw, 0)
end

function CabCinematicAnimation:start()
  Log:info("Starting CabCinematicAnimation")

  if not self.camera:link(self.vehicle.rootNode) then
    Log:error("Failed to link cinematic camera to vehicle")
    return
  end

  self:prepare()

  Log:info(string.format("CabCinematicAnimation total duration: %.2f seconds", self.duration))

  for _, keyframe in ipairs(self.keyframes) do
    Log:info(string.format(
      "  Keyframe: type=%s, start=(%.2f, %.2f, %.2f), end=(%.2f, %.2f, %.2f), speed=%.2f, distance=%.2f, duration=%.2f",
      keyframe.type,
      keyframe.startPosition[1], keyframe.startPosition[2], keyframe.startPosition[3],
      keyframe.endPosition[1], keyframe.endPosition[2], keyframe.endPosition[3],
      keyframe.speed,
      keyframe.distance,
      keyframe:getDuration()))
  end

  self.timer = 0
  self.currentKeyFrameIndex = 1
  self.isActive = true

  self:syncAnimationCamerasAtStart()
  self.camera:activate()
end

function CabCinematicAnimation:stop()
  Log:info("Stopping CabCinematicAnimation")

  if self.finishCallback ~= nil then
    self.finishCallback()
  end

  self:syncAnimationCamerasAtStop()
  self.camera:deactivate()
  self.camera:unlink()

  self.timer          = 0
  self.finishCallback = nil
  self.isActive       = false
  self.isEnded        = true
end

function CabCinematicAnimation:update(dt)
  if not self.isActive then
    return
  end

  local vehicleCamera = self.vehicle:getVehicleInteriorCamera()
  self.camera:setRotation(vehicleCamera.rotX, vehicleCamera.rotY, vehicleCamera.rotZ)

  if self.isPaused then
    return
  end

  self.timer = self.timer + (dt / 1000.0)

  local accumulatedDuration = 0.0
  for i = 1, self.currentKeyFrameIndex - 1 do
    accumulatedDuration = accumulatedDuration + self.keyframes[i]:getDuration()
  end

  local currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  if currentKeyFrame == nil then
    Log:error("No current keyframe found during update")
    self:stop()
    return
  end

  local keyframeEndTime = accumulatedDuration + currentKeyFrame:getDuration()
  if self.timer > keyframeEndTime and self.currentKeyFrameIndex < #self.keyframes then
    self.currentKeyFrameIndex = self.currentKeyFrameIndex + 1
    accumulatedDuration = keyframeEndTime
    currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  end

  local keyframeTime = self.timer - accumulatedDuration
  local cx, cy, cz = currentKeyFrame:getInterpolatedPositionAtTime(keyframeTime)

  -- Log:info(string.format("CabCinematicAnimation progress=%.2f, timer=%.2f, keyframeTime=%.2f, pos=(%.2f, %.2f, %.2f)",
  --   progress, self.timer, keyframeTime, cx, cy, cz))

  self.camera:setPosition(cx, cy, cz)

  if self.timer >= self.duration or CabCinematic.debug.skipAnimation then
    self:stop()
  end
end

function CabCinematicAnimation:drawDebug()
  DebugUtil.drawDebugNode(self.vehicle:getExitNode())
  DebugUtil.drawDebugNode(self.vehicle:getVehicleInteriorCamera().cameraPositionNode)
  if self.keyframes ~= nil then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:drawDebug(self.vehicle.rootNode)
    end
  end
end
