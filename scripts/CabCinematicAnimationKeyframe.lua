CabCinematicAnimationKeyframe = {
  type = nil,
  startPosition = { 0, 0, 0 },
  endPosition = { 0, 0, 0 },
  speed = 1.0,
  distance = 0.0
}

CabCinematicAnimationKeyframe.TYPES = {
  WALK = "walk",
  RUN = "run",
  CLIMB = "climb",
  SEAT = "seat",
}

CabCinematicAnimationKeyframe.MODES = {
  PERCENT_TOTAL = "PERCENT_TOTAL",
  PERCENT_REMAINING = "PERCENT_REMAINING",
  ABSOLUTE = "ABSOLUTE",
}

CabCinematicAnimationKeyframe.SPEEDS = {
  [CabCinematicAnimationKeyframe.TYPES.WALK]  = 1.6,
  [CabCinematicAnimationKeyframe.TYPES.RUN]   = 2.25,
  [CabCinematicAnimationKeyframe.TYPES.CLIMB] = 0.95,
  [CabCinematicAnimationKeyframe.TYPES.SEAT]  = 0.85,
}

CabCinematicAnimationKeyframe.VIEW_BOBBING = {
  [CabCinematicAnimationKeyframe.TYPES.WALK] = {
    verticalAmplitude = 0.02,
    horizontalAmplitude = 0.015,
    frequency = 1.7,
  },
  [CabCinematicAnimationKeyframe.TYPES.RUN] = {
    verticalAmplitude = 0.04,
    horizontalAmplitude = 0.03,
    frequency = 2.5,
  },
  [CabCinematicAnimationKeyframe.TYPES.CLIMB] = {
    verticalAmplitude = 0.045,
    horizontalAmplitude = 0.02,
    frequency = 2.25,
  },
  [CabCinematicAnimationKeyframe.TYPES.SEAT] = {
    verticalAmplitude = 0.0,
    horizontalAmplitude = 0.0,
    frequency = 0.0,
  },
}

local CabCinematicAnimationKeyframe_mt = Class(CabCinematicAnimationKeyframe)
function CabCinematicAnimationKeyframe.new(type, startPosition, endPosition)
  local self = setmetatable({}, CabCinematicAnimationKeyframe_mt)
  self.type = type
  self.startPosition = startPosition
  self.endPosition = endPosition
  self.speed = CabCinematicAnimationKeyframe.SPEEDS[type]
  self.bobbingConfig = CabCinematicAnimationKeyframe.VIEW_BOBBING[type]
  self.distance = MathUtil.vector3Length(endPosition[1] - startPosition[1],
    endPosition[2] - startPosition[2],
    endPosition[3] - startPosition[3])
  return self
end

function CabCinematicAnimationKeyframe:delete()
  self.type = nil
  self.startPosition = nil
  self.endPosition = nil
  self.speed = nil
  self.bobbingConfig = nil
  self.distance = nil
end

function CabCinematicAnimationKeyframe:getDuration()
  return self.distance / self.speed
end

function CabCinematicAnimationKeyframe:getViewBobbingOffset(t)
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

function CabCinematicAnimationKeyframe:getInterpolatedPositionAtTime(t)
  if self.distance == 0 then
    return 0, 0, 0
  end

  local duration = self:getDuration()
  local factor = t / duration

  local baseX = self.startPosition[1] + (self.endPosition[1] - self.startPosition[1]) * factor
  local baseY = self.startPosition[2] + (self.endPosition[2] - self.startPosition[2]) * factor
  local baseZ = self.startPosition[3] + (self.endPosition[3] - self.startPosition[3]) * factor

  local bobX, bobY, bobZ = self:getViewBobbingOffset(t)

  return baseX + bobX, baseY + bobY, baseZ + bobZ
end

function CabCinematicAnimationKeyframe:reverse()
  local temp = self.startPosition
  self.startPosition = self.endPosition
  self.endPosition = temp
end

function CabCinematicAnimationKeyframe:drawDebug(rootNode)
  local startWorldPos = { localToWorld(rootNode, unpack(self.startPosition)) }
  local endWorldPos = { localToWorld(rootNode, unpack(self.endPosition)) }
  DebugUtil.drawDebugLine(startWorldPos[1], startWorldPos[2], startWorldPos[3],
    endWorldPos[1], endWorldPos[2], endWorldPos[3],
    1, 0, 0, 0.5)
end

function CabCinematicAnimationKeyframe:printDebug()
  Log:info(string.format(
    "  Keyframe: type=%s, start=(%.2f, %.2f, %.2f), end=(%.2f, %.2f, %.2f), speed=%.2f, distance=%.2f, duration=%.2f",
    self.type,
    self.startPosition[1], self.startPosition[2], self.startPosition[3],
    self.endPosition[1], self.endPosition[2], self.endPosition[3],
    self.speed,
    self.distance,
    self:getDuration()))
end
