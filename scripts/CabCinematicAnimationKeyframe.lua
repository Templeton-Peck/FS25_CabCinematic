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

CabCinematicAnimationKeyframe.SPEEDS = {
  [CabCinematicAnimationKeyframe.TYPES.WALK]  = 1.0,
  [CabCinematicAnimationKeyframe.TYPES.RUN]   = 2.0,
  [CabCinematicAnimationKeyframe.TYPES.CLIMB] = 0.5,
  [CabCinematicAnimationKeyframe.TYPES.SEAT]  = 0.7,
}

local CabCinematicAnimationKeyframe_mt = Class(CabCinematicAnimationKeyframe)
function CabCinematicAnimationKeyframe.new(type, startPosition, endPosition)
  local self = setmetatable({}, CabCinematicAnimationKeyframe_mt)
  self.type = type
  self.startPosition = startPosition
  self.endPosition = endPosition
  self.speed = CabCinematicAnimationKeyframe.SPEEDS[type]
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
  self.distance = nil
end

function CabCinematicAnimationKeyframe:getDuration()
  return self.distance / self.speed
end

function CabCinematicAnimationKeyframe:getInterpolatedPositionAtTime(t)
  if self.distance == 0 then
    return 0, 0, 0
  end

  return (self.endPosition[1] - self.startPosition[1]) / self.distance * t,
      (self.endPosition[2] - self.startPosition[2]) / self.distance * t,
      (self.endPosition[3] - self.startPosition[3]) / self.distance * t
end

function CabCinematicAnimationKeyframe:drawDebug(rootNode)
  local startWorldPos = { localToWorld(rootNode, unpack(self.startPosition)) }
  local endWorldPos = { localToWorld(rootNode, unpack(self.endPosition)) }
  DebugUtil.drawDebugLine(startWorldPos[1], startWorldPos[2], startWorldPos[3],
    endWorldPos[1], endWorldPos[2], endWorldPos[3],
    1, 0, 0, 0.5)
end
