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
      { type = CabCinematicAnimationKeyframe.TYPES.CLIMB, weightXZ = 0.2, weightY = 1.0 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,  weightXZ = 0.8, weightY = 0.0 },
      { type = CabCinematicAnimationKeyframe.TYPES.SEAT,  weightXZ = 0.0, weightY = 0.0 },
    },
    forageharvesters = {
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,  weightXZ = 0.10, weightY = 0.0, angle = 0 },
      { type = CabCinematicAnimationKeyframe.TYPES.CLIMB, weightXZ = 0.35, weightY = 1.0, angle = -90 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,  weightXZ = 0.40, weightY = 0.0, angle = -90 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,  weightXZ = 0.10, weightY = 0.0, angle = -70 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,  weightXZ = 0.04, weightY = 0.0 },
      { type = CabCinematicAnimationKeyframe.TYPES.SEAT,  weightXZ = 0.01, weightY = 0.0 },
    },
  },
  tractor = {
    tractorsm = {
      { type = CabCinematicAnimationKeyframe.TYPES.CLIMB, weightXZ = 0.2, weightY = 1.0 },
      { type = CabCinematicAnimationKeyframe.TYPES.WALK,  weightXZ = 0.8, weightY = 0.0 },
      { type = CabCinematicAnimationKeyframe.TYPES.SEAT,  weightXZ = 0.0, weightY = 0.0 },
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

local function sign(v) return (v >= 0) and 1 or -1 end

function CabCinematicAnimation:buildKeyframes(startPosition, endPosition)
  local vehiclePreset = self:getVehiclePreset()
  if not vehiclePreset then return {} end

  Log:info(string.format("Building keyframes from start (%.2f, %.2f, %.2f) to end (%.2f, %.2f, %.2f)",
    startPosition[1], startPosition[2], startPosition[3],
    endPosition[1], endPosition[2], endPosition[3]))

  local preset = {}
  if self.type == CabCinematicAnimation.TYPES.LEAVE then
    for i = #vehiclePreset, 1, -1 do table.insert(preset, vehiclePreset[i]) end
  else
    preset = vehiclePreset
  end

  local keyframes = {}
  local cur = { startPosition[1], startPosition[2], startPosition[3] }

  local dxT = endPosition[1] - startPosition[1]
  local dyT = endPosition[2] - startPosition[2]
  local dzT = endPosition[3] - startPosition[3]
  local horizT = math.sqrt(dxT * dxT + dzT * dzT)

  local bases = {}
  local sumX, sumZ, sumY = 0, 0, 0
  for i, kf in ipairs(preset) do
    local wXZ = math.max(0, kf.weightXZ or 0)
    local wY  = math.max(0, kf.weightY or 0)
    local bx, bz

    if kf.angle == nil then
      if horizT > 0 then
        bx = math.abs(dxT) / horizT
        bz = math.abs(dzT) / horizT
      else
        bx, bz = 0, 0
      end
    else
      local a = math.rad(math.max(-90, math.min(90, kf.angle)))
      bx = math.abs(math.cos(a))
      bz = math.abs(math.sin(a))
    end

    bases[i] = { bx = bx, bz = bz, wXZ = wXZ, wY = wY, type = kf.type, angle = kf.angle }
    sumX = sumX + wXZ * bx
    sumZ = sumZ + wXZ * bz
    sumY = sumY + wY
  end

  for _, b in ipairs(bases) do
    local stepX = 0
    local stepZ = 0
    local stepY = 0

    if sumX > 0 then stepX = sign(dxT) * math.abs(dxT) * (b.wXZ * b.bx / sumX) end
    if sumZ > 0 then stepZ = sign(dzT) * math.abs(dzT) * (b.wXZ * b.bz / sumZ) end
    if sumY > 0 then stepY = sign(dyT) * math.abs(dyT) * (b.wY / sumY) end

    local nextPos = { cur[1] + stepX, cur[2] + stepY, cur[3] + stepZ }

    local keyframe = CabCinematicAnimationKeyframe.new(
      b.type,
      { cur[1], cur[2], cur[3] },
      { nextPos[1], nextPos[2], nextPos[3] },
      b.wXZ, b.wY, b.angle
    )

    keyframe:printDebug()

    table.insert(keyframes, keyframe)
    cur = nextPos
  end

  if #keyframes > 0 then
    keyframes[#keyframes].endPosition = { endPosition[1], endPosition[2], endPosition[3] }
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

  if self.timer >= self.duration or CabCinematic.flags.skipAnimation then
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
