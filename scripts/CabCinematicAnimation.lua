CabCinematicAnimation = {
  isActive = false,
  isPaused = false,
  isEnded = false,
  animationType = nil,
  player = nil,
  vehicle = nil,
  cinematicCamera = nil,
  cinematic = nil,
  originLocalPosition = { 0, 0, 0 },
  targetLocalPosition = { 0, 0, 0 },
  timer = 0,
  finishCallback = nil,
}

CabCinematicAnimation.ANIMATION_TYPE = {
  ENTER = "enter",
  LEAVE = "leave",
}

local CabCinematicAnimation_mt = Class(CabCinematicAnimation)

local function isVehicleCamera(camera)
  return camera ~= nil and camera.vehicle ~= nil
end

local function getCameraId(camera)
  if camera == nil then
    return nil
  end

  if isVehicleCamera(camera) then
    return camera.cameraPositionNode
  end

  return camera.cameraRootNode
end

function CabCinematicAnimation.new(animationType, player, vehicle, cinematicCamera, finishCallback)
  local self = setmetatable({}, CabCinematicAnimation_mt)
  self.animationType = animationType
  self.player = player
  self.vehicle = vehicle
  self.cinematicCamera = cinematicCamera
  self.finishCallback = finishCallback
  Log:info(string.format("Created CabCinematicAnimation of type %s for vehicle %s", animationType,
    vehicle.typeName))
  return self
end

function CabCinematicAnimation:delete()
  self:reset()
end

function CabCinematicAnimation:reset()
  self.isActive = false
  self.isPaused = false
  self.isEnded = false
  self.animationType = nil
  self.player = nil
  self.vehicle = nil
  self.cinematicCamera = nil
  self.cinematic = nil
  self.originLocalPosition = { 0, 0, 0 }
  self.targetLocalPosition = { 0, 0, 0 }
  self.timer = 0
  self.finishCallback = nil
end

function CabCinematicAnimation:start()
  local originCameraId = getCameraId(self:getOriginCamera())
  local targetCameraId = getCameraId(self:getTargetCamera())

  if originCameraId == nil or targetCameraId == nil then
    Log:error("Cannot start cab cinematic animation: missing camera")
    return
  end

  if not self.cinematicCamera:linkToVehicle(self.vehicle) then
    Log:error("Failed to link cinematic camera to vehicle")
    return
  end

  local vehicleParentNode = self.cinematicCamera:getParentNode()
  if vehicleParentNode == nil then
    Log:error("Cannot get vehicle parent node for local calculations")
    return
  end

  local sx, sy, sz = self:getOriginPosition()
  local tx, ty, tz = self:getTargetPosition()

  if sx == nil or sy == nil or sz == nil then
    Log:error("Cannot get world translation for origin position")
    return
  end

  if tx == nil or ty == nil or tz == nil then
    Log:error("Cannot get world translation for target position")
    return
  end

  local originLocalX, originLocalY, originLocalZ = worldToLocal(vehicleParentNode, sx, sy, sz)
  local targetLocalX, targetLocalY, targetLocalZ = worldToLocal(vehicleParentNode, tx, ty, tz)
  self.originLocalPosition = { originLocalX, originLocalY, originLocalZ }
  self.targetLocalPosition = { targetLocalX, targetLocalY, targetLocalZ }
  self.cinematic = Cinematics.getCinematic(self.vehicle.typeName, self:getIsLeaveAnimation())
  self.timer = 0
  self.isActive = true

  self:syncCamerasAtAnimationStart()
  self.cinematicCamera:activate()

  Log:info(string.format("Start cab cinematic animation from local (%.2f, %.2f, %.2f) to local (%.2f, %.2f, %.2f)",
    originLocalX, originLocalY, originLocalZ, targetLocalX, targetLocalY, targetLocalZ))
end

function CabCinematicAnimation:pause()
  if self.isActive then
    self.isPaused = true
    Log:info(string.format("Pause cab cinematic animation"))
  end
end

function CabCinematicAnimation:resume()
  if self.isActive and self.isPaused then
    self.isPaused = false
    Log:info(string.format("Resume cab cinematic animation"))
  end
end

function CabCinematicAnimation:stop()
  Log:info(string.format("Stop cab cinematic animation"))

  self:syncCamerasAtAnimationStop()
  self.cinematicCamera:deactivate()

  if self.finishCallback ~= nil then
    self.finishCallback()
  end

  self.originLocalPosition = { 0, 0, 0 }
  self.targetLocalPosition = { 0, 0, 0 }
  self.cinematic           = nil
  self.timer               = 0
  self.finishCallback      = nil
  self.isActive            = false
  self.isEnded             = true
end

function CabCinematicAnimation:getIsActive()
  return self.isActive
end

function CabCinematicAnimation:getIsEnded()
  return self.isEnded
end

function CabCinematicAnimation:getIsEnterAnimation()
  return self.animationType == CabCinematicAnimation.ANIMATION_TYPE.ENTER
end

function CabCinematicAnimation:getIsLeaveAnimation()
  return self.animationType == CabCinematicAnimation.ANIMATION_TYPE.LEAVE
end

function CabCinematicAnimation:getOriginCamera()
  return self:getIsEnterAnimation() and self.player.camera or self.vehicle:getVehicleInteriorCamera()
end

function CabCinematicAnimation:getTargetCamera()
  return self:getIsEnterAnimation() and self.vehicle:getVehicleInteriorCamera() or self.player.camera
end

function CabCinematicAnimation:getOriginPosition()
  if self:getIsEnterAnimation() then
    local exitNode = self.vehicle:getExitNode()
    local originCamera = self:getOriginCamera()
    local cameraNode = getCameraId(originCamera)

    if exitNode == nil or cameraNode == nil then
      Log:warning("getOriginPosition: exitNode ou cameraNode est nil pour animation d'entrée")
      return nil, nil, nil
    end

    local exitX, _, exitZ = getWorldTranslation(exitNode)
    local _, camY, _ = getWorldTranslation(cameraNode)

    if exitX == nil or exitZ == nil or camY == nil then
      Log:warning("getOriginPosition: impossible de récupérer les coordonnées")
      return nil, nil, nil
    end

    Log:info(string.format("Position hybride origine: exitNode XZ(%.2f, %.2f) + camera Y(%.2f)", exitX, exitZ, camY))
    return exitX, camY, exitZ
  else
    local originCamera = self:getOriginCamera()
    return getWorldTranslation(getCameraId(originCamera))
  end
end

function CabCinematicAnimation:getTargetPosition()
  if self:getIsEnterAnimation() then
    local targetCamera = self:getTargetCamera()
    return getWorldTranslation(getCameraId(targetCamera))
  else
    local exitNode = self.vehicle:getExitNode()
    local targetCamera = self:getTargetCamera()
    local cameraNode = getCameraId(targetCamera)

    if exitNode == nil or cameraNode == nil then
      Log:warning("getTargetPosition: exitNode ou cameraNode est nil pour animation de sortie")
      return nil, nil, nil
    end

    local exitX, _, exitZ = getWorldTranslation(exitNode)
    local _, camY, _ = getWorldTranslation(cameraNode)

    if exitX == nil or exitZ == nil or camY == nil then
      Log:warning("getTargetPosition: impossible de récupérer les coordonnées")
      return nil, nil, nil
    end

    Log:info(string.format("Position hybride cible: exitNode XZ(%.2f, %.2f) + camera Y(%.2f)", exitX, exitZ, camY))
    return exitX, camY, exitZ
  end
end

function CabCinematicAnimation:syncCamerasAtAnimationStart()
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  setFovY(self.player:getCurrentCameraNode(), fovY)
  setFovY(self.cinematicCamera.cameraId, fovY)

  local originCamera = self:getOriginCamera()
  local targetCamera = self:getTargetCamera()

  if self:getIsEnterAnimation() then
    setFovY(targetCamera.cameraNode, fovY)

    if isVehicleCamera(targetCamera) then
      local dx, dy, dz = localDirectionToWorld(getCameraId(originCamera), 0, 0, 1)

      local rotateNodeParent = getParent(targetCamera.rotateNode)
      local localDx, localDy, localDz = worldDirectionToLocal(rotateNodeParent, dx, dy, dz)

      local rotX = -math.asin(localDy)
      local rotY = math.atan2(localDx, localDz)

      targetCamera.rotX = rotX
      targetCamera.rotY = rotY
      targetCamera.rotZ = 0

      Log:info(string.format("syncCamerasAtAnimationStart: setting target camera rotation to (%.2f, %.2f, %.2f)",
        rotX, rotY, 0))

      targetCamera:updateRotateNodeRotation()
    else
      Log:warning("syncCamerasAtAnimationStop: target camera is not a vehicle camera during enter animation")
    end
  end
end

function CabCinematicAnimation:syncCamerasAtAnimationStop()
  if self:getIsLeaveAnimation() then
    local originCamera = self:getOriginCamera()
    local targetCamera = self:getTargetCamera()

    if isVehicleCamera(originCamera) then
      local dx, dy, dz = localDirectionToWorld(getCameraId(originCamera), 0, 0, 1)

      local pitch = math.asin(dy)
      local yaw = math.atan2(dx, dz) + math.pi

      targetCamera:setRotation(pitch, yaw, 0)
    else
      Log:warning("syncCamerasAtAnimationStart: origin camera is not a vehicle camera during leave animation")
    end
  end
end

function CabCinematicAnimation:update(dt)
  if not self.isActive then
    return
  end

  local vehicleCamera = self.vehicle:getVehicleInteriorCamera()
  self.cinematicCamera:setRotation(vehicleCamera.rotX, vehicleCamera.rotY, vehicleCamera.rotZ)

  if self.isPaused then
    return
  end

  self.timer = self.timer + dt
  local cinematicDuration = self.cinematic.totalDuration
  local t = math.min(1.0, self.timer / cinematicDuration)

  local sx, sy, sz = self.originLocalPosition[1], self.originLocalPosition[2], self.originLocalPosition[3]
  local tx, ty, tz = self.targetLocalPosition[1], self.targetLocalPosition[2], self.targetLocalPosition[3]

  local axisProgress = self.cinematic:getAxisProgressAtTime(t)
  local offset = self.cinematic:getOffsetAtTime(t)
  local bobbing = self.cinematic:getBobbingAtTime(t)

  local cx = sx + (tx - sx) * axisProgress.x + offset.x + bobbing.x
  local cy = sy + (ty - sy) * axisProgress.y + offset.y + bobbing.y
  local cz = sz + (tz - sz) * axisProgress.z + offset.z + bobbing.z

  -- Log:info(string.format("CabCinematicAnimation t=%.2f, pos=(%.2f, %.2f, %.2f)", t, cx, cy, cz))

  self.cinematicCamera:setPosition(cx, cy, cz)

  if t >= 1.0 or CabCinematic.debug.skipAnimation then
    self:stop()
  end
end
