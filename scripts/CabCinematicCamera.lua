CabCinematicCamera = {
  cameraId = nil,
  isActive = false,
  cameraX = 0,
  cameraY = 0,
  cameraZ = 0,
  cameraPitch = 0,
  cameraYaw = 0,
  cameraRoll = 0,
  linkedVehicle = nil,
}

local CabCinematicCamera_mt = Class(CabCinematicCamera)

local function createCameraId()
  local cameraId = createCamera("CabCinematicCamera", math.rad(90), 0.1, 5000)
  setRotation(cameraId, 0, 0, 0)
  setTranslation(cameraId, 0, 0, 0)
  return cameraId
end

function CabCinematicCamera.new()
  local self = setmetatable({}, CabCinematicCamera_mt)
  self.cameraId = createCameraId()
  g_cameraManager:addCamera(self.cameraId, nil, false)
  return self
end

function CabCinematicCamera:delete()
  if self.isActive then
    self:deactivate()
  end

  self:unlinkFromVehicle()
  g_cameraManager:removeCamera(self.cameraId)
  delete(self.cameraId)
  self.cameraId = nil

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
  self.linkedVehicle = nil
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
  setRotation(self.cameraId, self.cameraPitch, self.cameraYaw, self.cameraRoll)
end

function CabCinematicCamera:syncPosition()
  setTranslation(self.cameraId, self.cameraX, self.cameraY, self.cameraZ)
end

function CabCinematicCamera:linkToVehicle(vehicle)
  if self.linkedVehicle ~= nil then
    self:unlinkFromVehicle()
  end

  local interiorCamera = vehicle:getVehicleInteriorCamera()
  if interiorCamera == nil then
    Log:error("Cannot find interior camera for vehicle")
    return false
  end

  local cameraNode = interiorCamera.cameraPositionNode or interiorCamera.cameraNode
  if cameraNode == nil then
    Log:error("Cannot find camera node for interior camera")
    return false
  end

  local vehicleParentNode = getParent(cameraNode)
  if vehicleParentNode == nil then
    Log:error("Cannot find parent node for interior camera")
    return false
  end

  link(vehicleParentNode, self.cameraId)
  self.linkedVehicle = vehicle

  Log:info("Successfully linked cinematic camera to vehicle")
  return true
end

function CabCinematicCamera:unlinkFromVehicle()
  if self.linkedVehicle ~= nil and self.cameraId ~= nil then
    unlink(self.cameraId)
    self.linkedVehicle = nil
    Log:info("Unlinked cinematic camera from vehicle")
  end
end

function CabCinematicCamera:getIsLinkedToVehicle()
  return self.linkedVehicle ~= nil
end

function CabCinematicCamera:getParentNode()
  if not self:getIsLinkedToVehicle() then
    return nil
  end

  return getParent(self.cameraId)
end

function CabCinematicCamera:update()
  if self.isActive then
    self:setCameraActiveIfNeeded()
    self:syncRotation()
    self:syncPosition()
  end
end
