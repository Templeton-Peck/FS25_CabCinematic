--- @class CabCinematicConfiguration
--- Load and manage cinematic configurations for vehicles from XML files.
CabCinematicConfiguration = {}
local CabCinematicConfiguration_mt = Class(CabCinematicConfiguration)

function CabCinematicConfiguration.new()
  local self = setmetatable({}, CabCinematicConfiguration_mt)
  self.positions = {}
  self.keyframeWaypointsAfter = nil
  self.keyframeWaypoints = {}
  return self
end

function CabCinematicConfiguration:addPosition(name, position)
  self.positions[name] = position
end

function CabCinematicConfiguration:setKeyframeWaypoints(positionName, waypoints)
  self.keyframeWaypointsAfter = positionName
  self.keyframeWaypoints = waypoints
end

function CabCinematicConfiguration:applyPosition(name, position)
  local existingPosition = self.positions[name]
  if existingPosition == nil then
    return position
  end

  if existingPosition.x ~= nil then position[1] = existingPosition.x end
  if existingPosition.y ~= nil then position[2] = existingPosition.y end
  if existingPosition.z ~= nil then position[3] = existingPosition.z end
  if existingPosition.xOffset ~= nil then position[1] = position[1] + existingPosition.xOffset end
  if existingPosition.yOffset ~= nil then position[2] = position[2] + existingPosition.yOffset end
  if existingPosition.zOffset ~= nil then position[3] = position[3] + existingPosition.zOffset end

  return position
end
