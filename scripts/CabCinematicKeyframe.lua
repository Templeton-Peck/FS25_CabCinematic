--- @class CabCinematicKeyframe
--- Describes a single animation keyframe
CabCinematicKeyframe = {}
local CabCinematicKeyframe_mt = Class(CabCinematicKeyframe)

CabCinematicKeyframe.TYPES = {
  WALK = "walk",
  CLIMB = "climb",
  SIT = "sit",
  SHIFT = "shift",
  MOVE_IN_CAB = "moveInCab",
}

CabCinematicKeyframe.SPEEDS = {
  [CabCinematicKeyframe.TYPES.WALK]        = 1.4,
  [CabCinematicKeyframe.TYPES.CLIMB]       = 0.95,
  [CabCinematicKeyframe.TYPES.SIT]         = 0.85,
  [CabCinematicKeyframe.TYPES.SHIFT]       = 0.75,
  [CabCinematicKeyframe.TYPES.MOVE_IN_CAB] = 0.95,
}

CabCinematicKeyframe.VIEW_BOBBING = {
  [CabCinematicKeyframe.TYPES.WALK] = {
    verticalAmplitude = 0.01,
    horizontalAmplitude = 0.01,
    frequency = 1.5,
  },
  [CabCinematicKeyframe.TYPES.CLIMB] = {
    verticalAmplitude = 0.045,
    horizontalAmplitude = 0.02,
    frequency = 2.25,
  },
  [CabCinematicKeyframe.TYPES.SIT] = {
    verticalAmplitude = 0.035,
    horizontalAmplitude = 0.015,
    frequency = 2.0,
  },
  [CabCinematicKeyframe.TYPES.SHIFT] = {
    verticalAmplitude = 0.1,
    horizontalAmplitude = 0.0,
    frequency = 0.5,
  },
  [CabCinematicKeyframe.TYPES.MOVE_IN_CAB] = {
    verticalAmplitude = 0.02,
    horizontalAmplitude = 0.01,
    frequency = 1.0,
  },
}

--- Creates a new keyframe with the given type, start and end positions.
--- @param type string The type of the keyframe (ex: walk, climb, etc).
--- @param startPosition table The starting position of the keyframe.
--- @param endPosition table The ending position of the keyframe.
--- @return table CabCinematicKeyframe The created keyframe instance.
function CabCinematicKeyframe.new(type, startPosition, endPosition)
  local self = setmetatable({}, CabCinematicKeyframe_mt)
  self.type = type
  self.startPosition = startPosition
  self.endPosition = endPosition
  self.speed = CabCinematicKeyframe.SPEEDS[type]
  self.bobbingConfig = CabCinematicKeyframe.VIEW_BOBBING[type]
  self.distance = MathUtil.vector3Length(endPosition[1] - startPosition[1], endPosition[2] - startPosition[2], endPosition[3] - startPosition[3])
  return self
end

--- Deletes the keyframe and its resources
function CabCinematicKeyframe:delete()
  self.type = nil
  self.startPosition = nil
  self.endPosition = nil
  self.speed = nil
  self.bobbingConfig = nil
  self.distance = nil
end

--- Gets the duration of the keyframe based on its distance and speed.
--- @return number duration The duration of the keyframe in seconds.
function CabCinematicKeyframe:getDuration()
  return self.distance / self.speed
end

--- Calculates the view bobbing offset for the keyframe at time t.
--- @param t number The time along the keyframe's duration to calculate the offset for.
--- @return number horizontalOffset The horizontal offset to apply to the camera.
--- @return number verticalOffset The vertical offset to apply to the camera.
--- @return number depthOffset The depth offset to apply to the camera.
function CabCinematicKeyframe:getViewBobbingOffset(t)
  if self.distance == 0 then
    return 0, 0, 0
  end

  local duration = self:getDuration()
  local progress = t / duration
  local phase = t * self.bobbingConfig.frequency * 2 * math.pi

  local verticalOffset = math.sin(phase) * self.bobbingConfig.verticalAmplitude
  local horizontalOffset = math.sin(phase * 0.5) * self.bobbingConfig.horizontalAmplitude

  local fadeIn = math.min(progress * 4, 1.0)
  local fadeOut = math.min((1 - progress) * 4, 1.0)
  local fadeFactor = math.min(fadeIn, fadeOut)

  return horizontalOffset * fadeFactor, verticalOffset * fadeFactor, 0
end

--- Calculates the interpolated position along the keyframe's path at time t, including view bobbing offsets.
--- @param t number The time along the keyframe's duration to calculate the position for.
--- @return table The interpolated position at time t.
function CabCinematicKeyframe:getInterpolatedPositionAtTime(t)
  if self.distance == 0 then
    return { 0, 0, 0 }
  end

  local duration = self:getDuration()
  local factor = t / duration

  local baseX = self.startPosition[1] + (self.endPosition[1] - self.startPosition[1]) * factor
  local baseY = self.startPosition[2] + (self.endPosition[2] - self.startPosition[2]) * factor
  local baseZ = self.startPosition[3] + (self.endPosition[3] - self.startPosition[3]) * factor

  local bobX, bobY, bobZ = self:getViewBobbingOffset(t)

  return { baseX + bobX, baseY + bobY, baseZ + bobZ }
end

--- Reverses the keyframe's start and end positions, effectively creating a keyframe that goes in the opposite direction.
--- This is useful for generating exit animations from the same keyframes used for entering.
function CabCinematicKeyframe:reverse()
  local temp = self.startPosition
  self.startPosition = self.endPosition
  self.endPosition = temp
end

--- Draws a debug line in the world representing the keyframe's path.
--- @param relativeNode number The relative node to convert local positions to world positions.
function CabCinematicKeyframe:drawDebug(relativeNode)
  local startWorldPos = { localToWorld(relativeNode, unpack(self.startPosition)) }
  local endWorldPos = { localToWorld(relativeNode, unpack(self.endPosition)) }
  DebugUtil.drawDebugLine(startWorldPos[1], startWorldPos[2], startWorldPos[3], endWorldPos[1], endWorldPos[2], endWorldPos[3], 1, 0, 0, 0.05)
end

--- Prints the keyframe's details for debugging purposes.
function CabCinematicKeyframe:printDebug()
  Log:info(
    "  Keyframe: type=%s, start=(%.2f, %.2f, %.2f), end=(%.2f, %.2f, %.2f), speed=%.2f, distance=%.2f, duration=%.2f",
    self.type,
    self.startPosition[1], self.startPosition[2], self.startPosition[3],
    self.endPosition[1], self.endPosition[2], self.endPosition[3],
    self.speed,
    self.distance,
    self:getDuration())
end
