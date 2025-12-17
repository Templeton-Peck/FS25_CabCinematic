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
  [CabCinematicAnimationKeyframe.TYPES.WALK]  = 1.5,
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

local KEYFRAME_OFFSETS = {
  LADDER_SLOPE = 0.8,
  STAIRS_SLOPE = 1.0,
  WHEEL_SAFE_DISTANCE = 1.0,
  DOOR_SAFE_DISTANCE = 0.35,
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

local function buildHarvesterKeyframes(enterPosition, doorPosition, vehicleCategory, vehicleFeatures)
  if vehicleFeatures.isExitNodeCenter then
    local keyframes = {}
    local isEnterFarFromWheel = math.abs(enterPosition[1] - vehicleFeatures.positions.exitWheel[1]) >
    KEYFRAME_OFFSETS.WHEEL_SAFE_DISTANCE

    local ladderBottom = {}

    if isEnterFarFromWheel then
      ladderBottom = {
        vehicleFeatures.positions.exitWheel[1] + KEYFRAME_OFFSETS.WHEEL_SAFE_DISTANCE,
        enterPosition[2],
        vehicleFeatures.positions.exit[3]
      };

      table.insert(keyframes, CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    else
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterPosition[3]
      };
    end

    local ladderTop = {
      ladderBottom[1] - KEYFRAME_OFFSETS.LADDER_SLOPE,
      vehicleFeatures.positions.leftDoor[2],
      ladderBottom[3]
    };

    table.insert(keyframes, CabCinematicAnimationKeyframe.new(
      CabCinematicAnimationKeyframe.TYPES.CLIMB,
      ladderBottom,
      ladderTop
    ))

    table.insert(keyframes, CabCinematicAnimationKeyframe.new(
      CabCinematicAnimationKeyframe.TYPES.WALK,
      ladderTop,
      doorPosition
    ))

    return keyframes
  end

  return {}
end

local function buildBeetHarvesterKeyframes(enterPosition, doorPosition, category, vehicleFeatures)
  if vehicleFeatures.isExitNodeBackSide then
    local doorCross = {
      doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      doorPosition[2],
      doorPosition[3]
    };

    local ladderTop = {
      doorCross[1] + 0.2,
      doorCross[2],
      enterPosition[3]
    };

    local ladderBottom = {
      math.min(ladderTop[1] + KEYFRAME_OFFSETS.LADDER_SLOPE, enterPosition[1]),
      enterPosition[2],
      ladderTop[3]
    };

    local keyframes = {
      CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.CLIMB,
        ladderBottom,
        ladderTop
      ),
      CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        ladderTop,
        doorCross
      ),
      CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        doorCross,
        doorPosition
      ),
    }

    if (math.abs(enterPosition[1] - ladderBottom[1]) > 0) then
      table.insert(keyframes, 1, CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    end

    return keyframes
  end
end

local function buildForageHarvesterKeyframes(enterPosition, doorPosition, category, vehicleFeatures)
  if vehicleFeatures.isExitNodeBackSide then
    local doorCross = {
      doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      doorPosition[2],
      doorPosition[3]
    };

    local ladderBottom = {
      doorCross[1],
      enterPosition[2] + 0.15,
      enterPosition[3] + 0.25
    };

    local ladderTop = {
      doorCross[1],
      doorCross[2],
      math.min(ladderBottom[3] + KEYFRAME_OFFSETS.STAIRS_SLOPE, doorCross[3])
    };

    local keyframes = {
      CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ),
      CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.CLIMB,
        ladderBottom,
        ladderTop
      ),
    }

    if (math.abs(doorCross[3] - ladderTop[3]) > 0) then
      table.insert(keyframes, CabCinematicAnimationKeyframe.new(
        CabCinematicAnimationKeyframe.TYPES.WALK,
        ladderTop,
        doorCross
      ))
    end

    return keyframes
  end

  return {}
end

local function buildTractorKeyframes(startPosition, endPosition, category, vehicleFeatures)
  -- if category == 'tractorss' then
  --   return {}
  -- end

  -- if category == 'tractorsm' then
  --   return {}
  -- end

  -- if category == 'tractorsl' then
  --   return {}
  -- end

  return {
    CabCinematicAnimationKeyframe.new(
      CabCinematicAnimationKeyframe.TYPES.CLIMB,
      startPosition,
      endPosition
    )
  }
end

function CabCinematicAnimationKeyframe.build(player, vehicle)
  local vehicleFeatures = vehicle:getCabCinematicFeatures()
  local category = vehicle:getVehicleCategory()

  local _, cy, _ = getTranslation(getParent(player.camera.firstPersonCamera))
  local _, vcy, _ = localToLocal(getParent(player.camera.firstPersonCamera), vehicle.rootNode, 0, cy, 0)

  local enterPosition = {
    vehicleFeatures.positions.exit[1],
    vcy,
    vehicleFeatures.positions.exit[3]
  }

  local doorPosition = {
    vehicleFeatures.positions.leftDoor[1],
    vehicleFeatures.positions.leftDoor[2],
    vehicleFeatures.positions.leftDoor[3]
  }

  local keyframes = {}

  if vehicle.typeName == "tractor" then
    keyframes = buildTractorKeyframes(enterPosition, doorPosition, category, vehicleFeatures)
  elseif category == 'harvesters' then
    keyframes = buildHarvesterKeyframes(enterPosition, doorPosition, category, vehicleFeatures)
  elseif category == 'forageharvesters' then
    keyframes = buildForageHarvesterKeyframes(enterPosition, doorPosition, category, vehicleFeatures)
  elseif category == 'beetharvesters' then
    keyframes = buildBeetHarvesterKeyframes(enterPosition, doorPosition, category, vehicleFeatures)
  end

  table.insert(keyframes, CabCinematicAnimationKeyframe.new(
    CabCinematicAnimationKeyframe.TYPES.WALK,
    doorPosition,
    vehicleFeatures.positions.standup
  ))

  table.insert(keyframes, CabCinematicAnimationKeyframe.new(
    CabCinematicAnimationKeyframe.TYPES.WALK,
    vehicleFeatures.positions.standup,
    vehicleFeatures.positions.seat
  ))

  return keyframes
end
