CabCinematicCamera = {
  cameraNode = nil,
  isActive = false,
  cameraX = 0,
  cameraY = 0,
  cameraZ = 0,
  cameraPitch = 0,
  cameraYaw = 0,
  cameraRoll = 0,
  isLinked = false,
}

local CabCinematicCamera_mt = Class(CabCinematicCamera)

local function createCameraNode()
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  local cameraNode = createCamera("CabCinematicCamera", fovY, 0.1, 5000)
  setRotation(cameraNode, 0, 0, 0)
  setTranslation(cameraNode, 0, 0, 0)
  return cameraNode
end

function CabCinematicCamera.new()
  local self = setmetatable({}, CabCinematicCamera_mt)
  self.cameraNode = createCameraNode()
  g_cameraManager:addCamera(self.cameraNode, nil, false)
  return self
end

function CabCinematicCamera:delete()
  if self.isActive then
    self:deactivate()
  end

  self:unlink()

  g_cameraManager:removeCamera(self.cameraNode)

  self.cameraNode = nil

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
  self.isLinked = false
end

function CabCinematicCamera:activate()
  self:setCameraActiveIfNeeded()
  self.isActive = true
end

function CabCinematicCamera:deactivate()
  self.isActive = false
  self:reset()
end

function CabCinematicCamera:setCameraActiveIfNeeded()
  local activeCameraId = g_cameraManager:getActiveCamera()
  if activeCameraId ~= self.cameraNode then
    g_cameraManager:setActiveCamera(self.cameraNode)
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
  setRotation(self.cameraNode, self.cameraPitch, self.cameraYaw, self.cameraRoll)
end

function CabCinematicCamera:syncPosition()
  setTranslation(self.cameraNode, self.cameraX, self.cameraY, self.cameraZ)
end

function CabCinematicCamera:syncFovY()
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  setFovY(self.cameraNode, fovY)
end

function CabCinematicCamera:link(node)
  if self.isLinked then
    self:unlink()
  end

  link(node, self.cameraNode)
  self.isLinked = true

  Log:info("Successfully linked cinematic camera")
  return true
end

function CabCinematicCamera:unlink()
  if self.isLinked and self.cameraNode ~= nil then
    unlink(self.cameraNode)
    self.isLinked = false
    Log:info("Unlinked cinematic camera")
  end
end

function CabCinematicCamera:getIsLinked()
  return self.isLinked
end

function CabCinematicCamera:getParentNode()
  if not self:getIsLinked() then
    return nil
  end

  return getParent(self.cameraNode)
end

function CabCinematicCamera:update()
  if self.isActive then
    self:setCameraActiveIfNeeded()
    self:syncRotation()
    self:syncPosition()
  end
end
