---@class CabCinematicPlayerSnapshot
---Describes a player snapshot at the moment of entering a vehicle, used for cinematic animations.
CabCinematicPlayerSnapshot = {}
local CabCinematicPlayerSnapshot_mt = Class(CabCinematicPlayerSnapshot)

---Creates a new player snapshot.
---@param player table The player for which the snapshot is created.
---@param vehicle table The vehicle the player is interacting with.
---@return CabCinematicPlayerSnapshot
function CabCinematicPlayerSnapshot.new(player, vehicle)
  local self = setmetatable({}, CabCinematicPlayerSnapshot_mt)
  local playerCameraParent = getParent(g_localPlayer.camera.firstPersonCamera);
  self.position = { localToLocal(playerCameraParent, vehicle.rootNode, getTranslation(playerCameraParent)) }
  self.speed = player:getSpeed()
  self.isInFirstPerson = player.camera.isFirstPerson == true
  return self
end

--- Deletes the player snapshot and its resources.
function CabCinematicPlayerSnapshot:delete()
  self.position = nil
  self.speed = nil
  self.isInFirstPerson = nil
end
