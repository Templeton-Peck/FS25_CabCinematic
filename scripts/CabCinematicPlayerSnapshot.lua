CabCinematicPlayerSnapshot = {
  position = { 0, 0, 0 },
  rotation = { 0, 0, 0 },
}

local CabCinematicPlayerSnapshot_mt = Class(CabCinematicPlayerSnapshot)
function CabCinematicPlayerSnapshot.new(player)
  local self = setmetatable({}, CabCinematicPlayerSnapshot_mt)
  self.position = { getWorldTranslation(getParent(player.camera.firstPersonCamera)) }
  self.rotation = { 0, 0, 0 }
  Log:info(string.format("Created CabCinematicPlayerSnapshot at position (%.2f, %.2f, %.2f)", self.position[1],
    self.position[2], self.position[3]))
  return self
end

function CabCinematicPlayerSnapshot:delete()
  self.position = nil
  self.rotation = nil
end

function CabCinematicPlayerSnapshot:getLocalPosition(referenceNode)
  return worldToLocal(referenceNode, self.position[1], self.position[2], self.position[3])
end
