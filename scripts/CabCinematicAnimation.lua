CabCinematicAnimation = {
  isActive = false,
  isPaused = false,
  isEnded = false,
  animationType = nil,
  player = nil,
  vehicle = nil,
  cinematicCamera = nil,
  cinematic = nil,
  originPosition = { 0, 0, 0 },
  targetPosition = { 0, 0, 0 },
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
  self.originPosition = { 0, 0, 0 }
  self.targetPosition = { 0, 0, 0 }
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

  local sx, sy, sz = getWorldTranslation(originCameraId)
  local tx, ty, tz = getWorldTranslation(targetCameraId)

  self.originPosition = { sx, sy, sz }
  self.targetPosition = { tx, ty, tz }
  self.cinematic = Cinematics.getCinematic(self.vehicle.typeName, self:getIsLeaveAnimation())
  self.timer = 0
  self.isActive = true

  self:syncCamerasAtAnimationStart()
  self.cinematicCamera:activate()

  Log:info(string.format("Start cab cinematic animation from (%.2f, %.2f, %.2f) to (%.2f, %.2f, %.2f)", sx,
    sy, sz, tx, ty, tz))
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

  self.originPosition = { 0, 0, 0 }
  self.targetPosition = { 0, 0, 0 }
  self.cinematic      = nil
  self.timer          = 0
  self.finishCallback = nil
  self.isActive       = false
  self.isEnded        = true
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

function CabCinematicAnimation:getPlayerCamera()
  return self.player.camera
end

function CabCinematicAnimation:getVehicleInteriorCamera()
  if self.vehicle and self.vehicle.spec_enterable and self.vehicle.spec_enterable.cameras then
    for _, camera in ipairs(self.vehicle.spec_enterable.cameras) do
      if camera.isInside then return camera end
    end
  end

  return nil
end

function CabCinematicAnimation:getOriginCamera()
  return self:getIsEnterAnimation() and self:getPlayerCamera() or self:getVehicleInteriorCamera()
end

function CabCinematicAnimation:getTargetCamera()
  return self:getIsEnterAnimation() and self:getVehicleInteriorCamera() or self:getPlayerCamera()
end

function CabCinematicAnimation:syncCamerasAtAnimationStart()
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  setFovY(self.player:getCurrentCameraNode(), fovY)
  setFovY(self.cinematicCamera.cameraId, fovY)

  local originCamera = self:getOriginCamera()
  local targetCamera = self:getTargetCamera()

  if self:getIsLeaveAnimation() then
    if isVehicleCamera(originCamera) then
      local dx, dy, dz = localDirectionToWorld(getCameraId(originCamera), 0, 0, 1)

      local pitch = math.asin(dy)
      local yaw = math.atan2(dx, dz) + math.pi

      targetCamera:setRotation(pitch, yaw, 0)
    else
      Log:warning("syncCamerasAtAnimationStart: origin camera is not a vehicle camera during leave animation")
    end
  else
    setFovY(targetCamera.cameraNode, fovY)
  end
end

function CabCinematicAnimation:syncCamerasAtAnimationStop()
  if self:getIsEnterAnimation() then
    local originCamera = self:getOriginCamera()
    local targetCamera = self:getTargetCamera()

    if isVehicleCamera(targetCamera) then
      local dx, dy, dz = localDirectionToWorld(getCameraId(originCamera), 0, 0, 1)

      local rotateNodeParent = getParent(targetCamera.rotateNode)
      local localDx, localDy, localDz = worldDirectionToLocal(rotateNodeParent, dx, dy, dz)

      local rotX = -math.asin(localDy)
      local rotY = math.atan2(localDx, localDz)

      targetCamera.rotX = rotX
      targetCamera.rotY = rotY
      targetCamera.rotZ = 0

      targetCamera:updateRotateNodeRotation()
    else
      Log:warning("syncCamerasAtAnimationStop: target camera is not a vehicle camera during enter animation")
    end
  end
end

function CabCinematicAnimation:update(dt)
  if not self.isActive then
    return
  end

  if self.isPaused then
    return
  end

  self.timer = self.timer + dt
  local cinematicDuration = self.cinematic.totalDuration
  local t = math.min(1.0, self.timer / cinematicDuration)

  local sx, sy, sz = self.originPosition[1], self.originPosition[2], self.originPosition[3]
  local tx, ty, tz = self.targetPosition[1], self.targetPosition[2], self.targetPosition[3]

  local axisProgress = self.cinematic:getAxisProgressAtTime(t)
  local offset = self.cinematic:getOffsetAtTime(t)
  local bobbing = self.cinematic:getBobbingAtTime(t)

  local worldOffset = { x = 0, y = 0, z = 0 }
  local rightX, rightY, rightZ = localDirectionToWorld(self.vehicle.rootNode, 1, 0, 0)       -- Droite
  local upX, upY, upZ = localDirectionToWorld(self.vehicle.rootNode, 0, 1, 0)                -- Haut
  local forwardX, forwardY, forwardZ = localDirectionToWorld(self.vehicle.rootNode, 0, 0, 1) -- Avant

  worldOffset.x = offset.x * rightX + offset.y * upX + offset.z * forwardX
  worldOffset.y = offset.x * rightY + offset.y * upY + offset.z * forwardY
  worldOffset.z = offset.x * rightZ + offset.y * upZ + offset.z * forwardZ

  local cx = sx + (tx - sx) * axisProgress.x + worldOffset.x + bobbing.x
  local cy = sy + (ty - sy) * axisProgress.y + worldOffset.y + bobbing.y
  local cz = sz + (tz - sz) * axisProgress.z + worldOffset.z + bobbing.z

  -- Log:info(string.format("CabCinematicAnimation t=%.2f, pos=(%.2f, %.2f, %.2f)", t, cx, cy, cz))

  self.cinematicCamera:setPosition(cx, cy, cz)

  if t >= 1.0 or CabCinematic.debug.skipAnimation then
    self:stop()
  end
end
