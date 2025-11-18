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

CabCinematicAnimation.PRESETS = {
  combineDrivable = {
    harvesters = {
      {
        type = CabCinematicAnimationKeyframe.TYPES.CLIMB,
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_TOTAL, value = 100 },
        x = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -1 },
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 }
      },
    },
    forageharvesters = {
      {
        type = CabCinematicAnimationKeyframe.TYPES.CLIMB,
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = 1 },
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 115 },
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
      },
    },
    beetharvesters = {
      {
        type = CabCinematicAnimationKeyframe.TYPES.CLIMB,
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_TOTAL, value = 100 },
        x = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -1 },
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -0.5 },
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 115 },
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
      },
    },
  },
  tractor = {
    tractorss = {
      {
        type = CabCinematicAnimationKeyframe.TYPES.CLIMB,
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_TOTAL, value = 65 }
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 }
      },
    },
    tractorsm = {
      {
        type = CabCinematicAnimationKeyframe.TYPES.CLIMB,
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_TOTAL, value = 80 },
        x = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -0.5 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -0.3 }
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 }
      }
    },
    tractorsl = {
      {
        type = CabCinematicAnimationKeyframe.TYPES.CLIMB,
        y = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_TOTAL, value = 80 },
        x = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -0.6 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.ABSOLUTE, value = -0.4 }
      },
      {
        type = CabCinematicAnimationKeyframe.TYPES.WALK,
        x = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 },
        z = { mode = CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING, value = 100 }
      }
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

function CabCinematicAnimation:getVehiclePreset()
  if CabCinematicAnimation.PRESETS[self.vehicle.typeName] ~= nil then
    local vehicleCategory = self.vehicle:getVehicleCategory()
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

function CabCinematicAnimation:isVehicleRequiringExteriorPositionAdjustment()
  return self.vehicle.typeName == "combineDrivable" and self.vehicle:getVehicleCategory() == "forageharvesters"
end

function CabCinematicAnimation:getPresetStartPosition()
  if self:isVehicleRequiringExteriorPositionAdjustment() then
    return self.vehicle:getVehicleAdjustedExteriorPosition()
  else
    return self.vehicle:getVehicleDefaultExteriorPosition()
  end
end

function CabCinematicAnimation:getPresetEndPosition()
  return self.vehicle:getVehicleInteriorCameraPosition()
end

function CabCinematicAnimation:getEnterAdjustmentKeyframeType()
  if self.playerSnapshot == nil then
    return CabCinematicAnimationKeyframe.TYPES.WALK
  end

  if self.vehicle:getLastSpeed() >= CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_VEHICLE_SPEED then
    return CabCinematicAnimationKeyframe.TYPES.RUN
  elseif self.playerSnapshot.speed >= CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_PLAYER_SPEED then
    return CabCinematicAnimationKeyframe.TYPES.RUN
  else
    return CabCinematicAnimationKeyframe.TYPES.WALK
  end
end

function CabCinematicAnimation:getEnterAdjustmentKeyframeEndPosition()
  if self:isVehicleRequiringExteriorPositionAdjustment() then
    return self.vehicle:getVehicleAdjustedExteriorPosition()
  end

  return self.vehicle:getVehicleDefaultExteriorPosition()
end

function CabCinematicAnimation:buildEnterAdjustmentKeyframe()
  if self.playerSnapshot == nil then
    return nil
  end

  local plx, ply, plz = self.playerSnapshot:getLocalPosition(self.vehicle.rootNode)
  local elx, ely, elz = unpack(self:getEnterAdjustmentKeyframeEndPosition())

  local playerDistance = MathUtil.vector3Length(elx - plx, ely - ply, elz - plz)

  if playerDistance > CabCinematicAnimation.PRE_MOVEMENT_DISTANCE then
    Log:info(string.format(
      "Calculating pre-movement keyframe - Player position (%.2f, %.2f, %.2f), ExitNode position (%.2f, %.2f, %.2f) - Distance: %.2f",
      plx, ply, plz, elx, ely, elz, playerDistance))

    return CabCinematicAnimationKeyframe.new(
      self:getEnterAdjustmentKeyframeType(),
      { plx, ply, plz },
      { elx, ely, elz }
    )
  else
    Log:info(string.format("No pre-movement keyframe needed - distance: %.2f", playerDistance))
  end

  return nil
end

function CabCinematicAnimation:buildLeaveAdjustmentKeyframe()
  if self:isVehicleRequiringExteriorPositionAdjustment() then
    return CabCinematicAnimationKeyframe.new(
      self:getEnterAdjustmentKeyframeType(),
      self.vehicle:getVehicleAdjustedExteriorPosition(),
      self.vehicle:getVehicleDefaultExteriorPosition()
    )
  end

  return nil
end

function CabCinematicAnimation:buildPresetKeyframes(startPosition, endPosition)
  local vehiclePreset = self:getVehiclePreset()
  if not vehiclePreset then return {} end

  Log:info(string.format("Building keyframes from start (%.2f, %.2f, %.2f) to end (%.2f, %.2f, %.2f)",
    startPosition[1], startPosition[2], startPosition[3],
    endPosition[1], endPosition[2], endPosition[3]))

  local keyframes = {}
  local cur = { startPosition[1], startPosition[2], startPosition[3] }

  local totalDelta = {
    x = endPosition[1] - startPosition[1],
    y = endPosition[2] - startPosition[2],
    z = endPosition[3] - startPosition[3]
  }

  local remaining = {
    x = totalDelta.x,
    y = totalDelta.y,
    z = totalDelta.z
  }

  for _, kf in ipairs(vehiclePreset) do
    local delta = { x = 0, y = 0, z = 0 }

    for _, axis in ipairs({ 'x', 'y', 'z' }) do
      if kf[axis] then
        local axisConfig = kf[axis]
        local mode = axisConfig.mode
        local value = axisConfig.value

        if mode == CabCinematicAnimationKeyframe.MODES.ABSOLUTE then
          delta[axis] = value
        elseif mode == CabCinematicAnimationKeyframe.MODES.PERCENT_TOTAL then
          delta[axis] = totalDelta[axis] * (value / 100)
        elseif mode == CabCinematicAnimationKeyframe.MODES.PERCENT_REMAINING then
          delta[axis] = remaining[axis] * (value / 100)
        end
      end
    end

    remaining.x = remaining.x - delta.x
    remaining.y = remaining.y - delta.y
    remaining.z = remaining.z - delta.z

    local nextPos = {
      cur[1] + delta.x,
      cur[2] + delta.y,
      cur[3] + delta.z
    }

    local keyframe = CabCinematicAnimationKeyframe.new(
      kf.type,
      { cur[1], cur[2], cur[3] },
      { nextPos[1], nextPos[2], nextPos[3] }
    )

    table.insert(keyframes, keyframe)
    cur = nextPos
  end

  if #keyframes > 0 then
    keyframes[#keyframes].endPosition = { endPosition[1], endPosition[2], endPosition[3] }
  end

  if self.type == CabCinematicAnimation.TYPES.LEAVE then
    local reversedKeyframes = {}
    for i, keyframe in ipairs(keyframes) do
      keyframe:reverse()
      table.insert(reversedKeyframes, 1, keyframe)
    end

    return reversedKeyframes
  end

  return keyframes
end

function CabCinematicAnimation:prepare()
  local keyframes = self:buildPresetKeyframes(self:getPresetStartPosition(), self:getPresetEndPosition())

  if self.type == CabCinematicAnimation.TYPES.ENTER then
    local adjustmentKeyframe = self:buildEnterAdjustmentKeyframe()
    if adjustmentKeyframe ~= nil then
      table.insert(keyframes, 1, adjustmentKeyframe)
    end
  else
    local adjustmentKeyframe = self:buildLeaveAdjustmentKeyframe()
    if adjustmentKeyframe ~= nil then
      table.insert(keyframes, adjustmentKeyframe)
    end
  end

  self.keyframes = keyframes
  self.duration = 0
  for _, keyframe in ipairs(self.keyframes) do
    self.duration = self.duration + keyframe:getDuration()
    keyframe:printDebug()
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

  self.timer = 0
  self.currentKeyFrameIndex = 1
  self.isActive = true

  for i, camera in pairs(self.vehicle.spec_enterable.cameras) do
    if camera.isInside then
      self.vehicle:setActiveCameraIndex(i)
      break
    end
  end

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

  if self.timer >= self.duration or CabCinematic.flags.skipAnimation then
    self:stop()
  end
end

function CabCinematicAnimation:drawDebug()
  if self.keyframes ~= nil then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:drawDebug(self.vehicle.rootNode)
    end
  end
end
