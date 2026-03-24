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

--- Applies the named position's coordinates to the given position, overriding any non-nil values.
--- @param name string The name of the position to apply.
--- @param position table The position table to apply the coordinates to.
--- @return table The updated position table.
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
