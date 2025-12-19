CabCinematicPlayerSnapshot = {
  position = { 0, 0, 0 },
  speed = 0.0
}

local CabCinematicPlayerSnapshot_mt = Class(CabCinematicPlayerSnapshot)
function CabCinematicPlayerSnapshot.new(player)
  local self = setmetatable({}, CabCinematicPlayerSnapshot_mt)
  self.position = { getWorldTranslation(getParent(player.camera.firstPersonCamera)) }
  self.speed = player:getSpeed()
  return self
end

function CabCinematicPlayerSnapshot:delete()
  self.position = nil
  self.speed = nil
end

function CabCinematicPlayerSnapshot:getLocalPosition(referenceNode)
  return { worldToLocal(referenceNode, self.position[1], self.position[2], self.position[3]) }
end
