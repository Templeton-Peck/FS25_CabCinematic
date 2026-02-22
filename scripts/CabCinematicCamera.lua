CabCinematicCamera = {
  cameraNode = nil,
  cameraX = 0,
  cameraY = 0,
  cameraZ = 0,
  cameraPitch = 0,
  cameraYaw = 0,
  cameraRoll = 0,
  isActive = false
}

local CabCinematicCamera_mt = Class(CabCinematicCamera)

local function createCameraNode(vehicle)
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  local cameraNode = createCamera("CabCinematicCamera", fovY, 0.1, 5000)
  link(vehicle.rootNode, cameraNode)
  setRotation(cameraNode, 0, 0, 0)
  setTranslation(cameraNode, 0, 0, 0)
  return cameraNode
end

function CabCinematicCamera.new(vehicle)
  local self = setmetatable({}, CabCinematicCamera_mt)
  self.cameraNode = createCameraNode(vehicle)
  g_cameraManager:addCamera(self.cameraNode, nil, false)
  return self
end

function CabCinematicCamera:delete()
  if self.isActive then
    self:deactivate()
  end

  unlink(self.cameraNode)

  g_cameraManager:removeCamera(self.cameraNode)

  self.cameraNode = nil
end

function CabCinematicCamera:activate()
  g_cameraManager:setActiveCamera(self.cameraNode)
  self.isActive = true
end

function CabCinematicCamera:deactivate()
  self.isActive = false
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
  setRotation(self.cameraNode, self.cameraPitch, self.cameraYaw, self.cameraRoll)
end

function CabCinematicCamera:syncPosition()
  setTranslation(self.cameraNode, self.cameraX, self.cameraY, self.cameraZ)
end

function CabCinematicCamera:syncFovY()
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  setFovY(self.cameraNode, fovY)
end

function CabCinematicCamera:update()
  if self.isActive then
    self:syncRotation()
    self:syncPosition()
  end
end
