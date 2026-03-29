--- @class CabCinematicConfiguration
--- A vehicle-specific configuration, containing named positions and keyframe waypoints.
CabCinematicConfiguration = {}
local CabCinematicConfiguration_mt = Class(CabCinematicConfiguration)

--- Creates a new vehicle-specific configuration.
--- @return CabCinematicConfiguration
function CabCinematicConfiguration.new()
  local self = setmetatable({}, CabCinematicConfiguration_mt)
  self.positions = {}
  self.keyframeWaypoints = {}
  return self
end

--- Deletes the configuration, clearing all positions and keyframe waypoints.
function CabCinematicConfiguration:delete()
  self.positions = nil
  self.keyframeWaypoints = nil
end

--- Adds a named position to the configuration.
--- @param position table A table containing the position including its name and coordinates.
--- @return CabCinematicConfiguration The configuration instance for chaining.
function CabCinematicConfiguration:addPosition(position)
  self.positions[position.name] = position
  return self
end

--- Adds a keyframe waypoint to the configuration.
--- @param keyframeWaypoint table The keyframe waypoint to add.
--- @return CabCinematicConfiguration The configuration instance for chaining.
function CabCinematicConfiguration:addKeyframeWaypoint(keyframeWaypoint)
  table.insert(self.keyframeWaypoints, keyframeWaypoint)
  return self
end

--- Overrides the named position's coordinates with the configuration position, overriding any non-nil values.
--- @param name string The name of the position to override.
--- @param position table The position table to override the coordinates to.
--- @return table The updated position table.
function CabCinematicConfiguration:overridePosition(name, position)
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

--- Overrides the coordinates of all named positions in the given table with the configuration positions, overriding any non-nil values.
--- @param positions table A table of named positions to override.
--- @return table The updated table of named positions.
function CabCinematicConfiguration:overridePositions(positions)
  for name, position in pairs(positions) do
    positions[name] = self:overridePosition(name, position)
  end
  return positions
end