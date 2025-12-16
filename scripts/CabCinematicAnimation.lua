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
  if self.camera then
    self.camera:deactivate()
    self.camera:unlink()
  end

  if self.keyframes then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:delete()
    end
  end

  self.timer = 0
  self.isActive = false
  self.isPaused = false
  self.isEnded = false
  self.type = nil
  self.vehicle = nil
  self.camera = nil
  self.finishCallback = nil
  self.keyframes = nil
  self.playerSnapshot = nil
  self.duration = 0.0
  self.currentKeyFrameIndex = 1
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

function CabCinematicAnimation:buildEnterAdjustmentKeyframe()
  -- if self.playerSnapshot == nil then
  --   return nil
  -- end

  -- local plx, ply, plz = self.playerSnapshot:getLocalPosition(self.vehicle.rootNode)
  -- local elx, ely, elz = unpack(self:getEnterAdjustmentKeyframeEndPosition())

  -- local playerDistance = MathUtil.vector3Length(elx - plx, ely - ply, elz - plz)

  -- if playerDistance > CabCinematicAnimation.PRE_MOVEMENT_DISTANCE then
  --   Log:info(string.format(
  --     "Calculating pre-movement keyframe - Player position (%.2f, %.2f, %.2f), ExitNode position (%.2f, %.2f, %.2f) - Distance: %.2f",
  --     plx, ply, plz, elx, ely, elz, playerDistance))

  --   return CabCinematicAnimationKeyframe.new(
  --     self:getEnterAdjustmentKeyframeType(),
  --     { plx, ply, plz },
  --     { elx, ely, elz }
  --   )
  -- else
  --   Log:info(string.format("No pre-movement keyframe needed - distance: %.2f", playerDistance))
  -- end

  return nil
end

function CabCinematicAnimation:buildLeaveAdjustmentKeyframe()
  -- if self:isVehicleRequiringExteriorPositionAdjustment() then
  --   return CabCinematicAnimationKeyframe.new(
  --     self:getEnterAdjustmentKeyframeType(),
  --     self.vehicle:getVehicleAdjustedExteriorPosition(),
  --     self.vehicle:getVehicleDefaultExteriorPosition()
  --   )
  -- end

  return nil
end

function CabCinematicAnimation:buildPresetKeyframes()
  local pathPositions = self.vehicle:getCabCinematicPathPositions()
  local keyframes = {}

  for i = 1, #pathPositions, 1 do
    local startPos = pathPositions[i]
    local stopPos = pathPositions[i + 1]

    if startPos ~= nil and stopPos ~= nil then
      local keyframe = CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        startPos,
        stopPos
      )
      table.insert(keyframes, keyframe)
    end
  end

  if self.type == CabCinematicAnimation.TYPES.LEAVE then
    local reversedKeyframes = {}
    for _, keyframe in ipairs(keyframes) do
      keyframe:reverse()
      table.insert(reversedKeyframes, 1, keyframe)
    end

    return reversedKeyframes
  end


  return keyframes
end

function CabCinematicAnimation:prepare()
  self.keyframes = self:buildPresetKeyframes()
  self.duration = 0
  for _, keyframe in ipairs(self.keyframes) do
    self.duration = self.duration + keyframe:getDuration()
    keyframe:printDebug()
  end
end

function CabCinematicAnimation:syncAnimationCamerasAtStart()
  local vehicleCamera = self.vehicle:getVehicleInteriorCamera();

  if self.type == CabCinematicAnimation.TYPES.ENTER then
    local cinematicCamera = self.camera

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

  local startPosition = self.keyframes[1].startPosition
  self.camera:setPosition(startPosition[1], startPosition[2], startPosition[3])
  self.camera:setRotation(vehicleCamera.rotX, vehicleCamera.rotY, vehicleCamera.rotZ)
  self.camera:syncPosition()
  self.camera:syncRotation()
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
  self:syncAnimationCamerasAtStart()

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

function CabCinematicAnimation:pause()
  Log:info("Pausing CabCinematicAnimation")
  self.isPaused = true
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

  if self.vehicle:getIsVehicleCabCinematicRequiredAnimationPlaying() then
    return
  end

  if not self.vehicle:getIsVehicleCabCinematicRequiredAnimationFinished() then
    return self.vehicle:playVehicleCabCinematicRequiredAnimations()
  end

  self.timer = self.timer + (dt / 1000.0)

  local accumulatedDuration = 0.0
  for i = 1, self.currentKeyFrameIndex - 1 do
    accumulatedDuration = accumulatedDuration + self.keyframes[i]:getDuration()
  end

  local currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  if currentKeyFrame == nil then
    Log:error("No current keyframe found during update")
    self.isEnded = true
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

  if self.timer >= self.duration then
    self.isEnded = true
  end
end

function CabCinematicAnimation:drawDebug()
  if self.keyframes ~= nil then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:drawDebug(self.vehicle.rootNode)
    end
  end
end
