CabCinematicCamera = {
  cameraId = nil,
  cameraBaseNodeId = nil,
  isActive = false,
  cameraX = 0,
  cameraY = 0,
  cameraZ = 0,
  cameraPitch = 0,
  cameraYaw = 0,
  cameraRoll = 0,
}

local CabCinematicCamera_mt = Class(CabCinematicCamera)

local function createCameraNodeIds()
  local cameraId = createCamera("CabCinematicCamera", math.rad(90), 0.1, 5000)
  local cameraBaseNodeId = createTransformGroup("cabCinematicCameraBaseNode")

  link(cameraBaseNodeId, cameraId)
  setRotation(cameraId, 0, 0, 0)
  setTranslation(cameraId, 0, 0, 0)
  setRotation(cameraBaseNodeId, 0, 0, 0)
  setTranslation(cameraBaseNodeId, 0, 0, 0)

  return cameraId, cameraBaseNodeId
end

function CabCinematicCamera.new()
  local self = setmetatable({}, CabCinematicCamera_mt)
  self.cameraId, self.cameraBaseNodeId = createCameraNodeIds()
  g_cameraManager:addCamera(self.cameraId, nil, false)
  return self
end

function CabCinematicCamera:delete()
  if self.isActive then
    self:deactivate()
  end

  g_cameraManager:removeCamera(self.cameraId)
  delete(self.cameraBaseNodeId)
  self.cameraId = nil
  self.cameraBaseNodeId = nil

  self:reset()
end

function CabCinematicCamera:reset()
  self.isActive = false
  self.cameraY = 0
  self.cameraX = 0
  self.cameraZ = 0
  self.cameraPitch = 0
  self.cameraYaw = 0
  self.cameraRoll = 0
end

function CabCinematicCamera:activate()
  Log:info(string.format("Activating CabCinematicCamera %d", self.cameraId))
  self:setCameraActiveIfNeeded()
  self.isActive = true
end

function CabCinematicCamera:deactivate()
  Log:info(string.format("Deactivating CabCinematicCamera %d", self.cameraId))
  self.isActive = false
  self:reset()
end

function CabCinematicCamera:setCameraActiveIfNeeded()
  local activeCameraId = g_cameraManager:getActiveCamera()
  if activeCameraId ~= self.cameraId then
    g_cameraManager:setActiveCamera(self.cameraId)
  end
end

function CabCinematicCamera:getIsActive()
  return self.isActive
end

function CabCinematicCamera:setPosition(x, y, z)
  self.cameraX = x
  self.cameraY = y
  self.cameraZ = z
end

function CabCinematicCamera:setRotation(pitch, yaw, roll)
  self.cameraPitch = pitch
  self.cameraYaw = yaw
  self.cameraRoll = roll
end

function CabCinematicCamera:syncRotation()
  setRotation(self.cameraBaseNodeId, self.cameraPitch, self.cameraYaw, self.cameraRoll)
end

function CabCinematicCamera:syncPosition()
  setTranslation(self.cameraBaseNodeId, self.cameraX, self.cameraY, self.cameraZ)
end

function CabCinematicCamera:update()
  if self.isActive then
    self:setCameraActiveIfNeeded()
    self:syncRotation()
    self:syncPosition()
  end
end
