---@class CabCinematicKeyframeBuilder
---Builds a sequence of keyframes by chaining positions and movement types.
CabCinematicKeyframeBuilder = {}
local CabCinematicKeyframeBuilder_mt = Class(CabCinematicKeyframeBuilder)

---Creates a new builder starting from the given position.
---@param startPosition table The starting position {x, y, z}
---@return CabCinematicKeyframeBuilder
function CabCinematicKeyframeBuilder.new(startPosition)
  local self = setmetatable({}, CabCinematicKeyframeBuilder_mt)
  self.waypoints = { startPosition }
  self.types = {}
  return self
end

---Adds a waypoint to the sequence.
---@param type string The movement type to reach this position (e.g., WALK, CLIMB)
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeBuilder self for method chaining
function CabCinematicKeyframeBuilder:add(type, position)
  table.insert(self.types, type)
  table.insert(self.waypoints, position)
  return self
end

---Builds and returns the array of keyframes.
---@return table keyframes The list of CabCinematicKeyframe instances
function CabCinematicKeyframeBuilder:build()
  local keyframes = {}
  for i = 1, #self.types do
    table.insert(keyframes, CabCinematicKeyframe.new(self.types[i], self.waypoints[i], self.waypoints[i + 1]))
  end
  return keyframes
end
