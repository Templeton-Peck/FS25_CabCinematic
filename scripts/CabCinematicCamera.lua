---@class CabCinematicCamera
---Handle cinematic camera
CabCinematicCamera = {}
local CabCinematicCamera_mt = Class(CabCinematicCamera)

---Creates game engine camera node and links it to the vehicle
---@param vehicle table The vehicle the camera is associated with
---@return integer cameraNode The camera node created for the cinematic camera
local function createCameraNode(vehicle)
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  local cameraNode = createCamera("CabCinematicCamera", fovY, 0.1, 5000)
  link(vehicle.rootNode, cameraNode)
  setRotation(cameraNode, 0, 0, 0)
  setTranslation(cameraNode, 0, 0, 0)
  return cameraNode
end

---Creates a new cinematic camera for the given vehicle.
---@param vehicle table The vehicle the camera is associated with
---@return CabCinematicCamera
function CabCinematicCamera.new(vehicle)
  local self = setmetatable({}, CabCinematicCamera_mt)
  self.cameraNode = createCameraNode(vehicle)
  self.cameraX = 0;
  self.cameraY = 0;
  self.cameraZ = 0;
  self.cameraPitch = 0;
  self.cameraYaw = 0;
  self.cameraRoll = 0;

  g_cameraManager:addCamera(self.cameraNode, nil, false)
  return self
end

---Deletes the cinematic camera and its resources
function CabCinematicCamera:delete()
  unlink(self.cameraNode)

  g_cameraManager:removeCamera(self.cameraNode)

  self.cameraNode = nil
  self.cameraX = 0;
  self.cameraY = 0;
  self.cameraZ = 0;
  self.cameraPitch = 0;
  self.cameraYaw = 0;
  self.cameraRoll = 0;
end

---Activates the cinematic camera, making it the active camera in the gameplay
function CabCinematicCamera:activate()
  g_cameraManager:setActiveCamera(self.cameraNode)
end

---Tells whether the cinematic camera is currently the active camera in the gameplay
---@return boolean true if the cinematic camera is active, false otherwise.
function CabCinematicCamera:getIsActive()
  return g_cameraManager:getActiveCamera() == self.cameraNode
end

--- Sets the position of the cinematic camera relative to the vehicle.
---@param x number The X coordinate of the camera position
---@param y number The Y coordinate of the camera position
---@param z number The Z coordinate of the camera position
---@return CabCinematicCamera self for chaining
function CabCinematicCamera:setPosition(x, y, z)
  self.cameraX = x
  self.cameraY = y
  self.cameraZ = z
  return self
end

--- Sets the rotation of the cinematic camera relative to the vehicle.
---@param pitch number The pitch of the camera rotation
---@param yaw number The yaw of the camera rotation
---@param roll number The roll of the camera rotation
---@return CabCinematicCamera self for chaining
function CabCinematicCamera:setRotation(pitch, yaw, roll)
  self.cameraPitch = pitch
  self.cameraYaw = yaw
  self.cameraRoll = roll
  return self
end

---Applies the current rotation values to the camera node
---@return CabCinematicCamera self for chaining
function CabCinematicCamera:applyRotation()
  setRotation(self.cameraNode, self.cameraPitch, self.cameraYaw, self.cameraRoll)
  return self
end

---Applies the current position values to the camera node
---@return CabCinematicCamera self for chaining
function CabCinematicCamera:applyPosition()
  setTranslation(self.cameraNode, self.cameraX, self.cameraY, self.cameraZ)
  return self
end

---Syncs the cinematic camera's FOV Y value with the player's first person FOV Y setting
---@return CabCinematicCamera self for chaining
function CabCinematicCamera:syncFovY()
  local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
  setFovY(self.cameraNode, fovY)
  return self
end

---Updates the cinematic camera, applying its position and rotation to the camera node
---This should be called in the update loop of the vehicle to ensure the camera's position and rotation are updated every frame.
---@param dt number The delta time since the last update call
function CabCinematicCamera:update(dt)
  self:applyRotation()
  self:applyPosition()
end

---Draws debug information for the cinematic camera
function CabCinematicCamera:drawDebug()
  DebugUtil.drawDebugNode(self.cameraNode, "cameraNode")
end
