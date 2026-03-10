---@class CabCinematicKeyframe
---Describes a single animation keyframe
CabCinematicKeyframe = {}
local CabCinematicKeyframe_mt = Class(CabCinematicKeyframe)

CabCinematicKeyframe.TYPES = {
  WALK = "walk",
  RUN = "run",
  CLIMB = "climb",
  SEAT = "seat",
  SHIFT = "shift",
  IN_CAB = "inCab",
}

CabCinematicKeyframe.SPEEDS = {
  [CabCinematicKeyframe.TYPES.WALK]   = 1.5,
  [CabCinematicKeyframe.TYPES.RUN]    = 2.25,
  [CabCinematicKeyframe.TYPES.CLIMB]  = 0.95,
  [CabCinematicKeyframe.TYPES.SEAT]   = 0.85,
  [CabCinematicKeyframe.TYPES.SHIFT]  = 0.75,
  [CabCinematicKeyframe.TYPES.IN_CAB] = 0.95,
}

CabCinematicKeyframe.VIEW_BOBBING = {
  [CabCinematicKeyframe.TYPES.WALK] = {
    verticalAmplitude = 0.01,
    horizontalAmplitude = 0.01,
    frequency = 1.5,
  },
  [CabCinematicKeyframe.TYPES.RUN] = {
    verticalAmplitude = 0.03,
    horizontalAmplitude = 0.03,
    frequency = 2.5,
  },
  [CabCinematicKeyframe.TYPES.CLIMB] = {
    verticalAmplitude = 0.045,
    horizontalAmplitude = 0.02,
    frequency = 2.25,
  },
  [CabCinematicKeyframe.TYPES.SEAT] = {
    verticalAmplitude = 0.035,
    horizontalAmplitude = 0.015,
    frequency = 2.0,
  },
  [CabCinematicKeyframe.TYPES.SHIFT] = {
    verticalAmplitude = 0.1,
    horizontalAmplitude = 0.0,
    frequency = 0.5,
  },
  [CabCinematicKeyframe.TYPES.IN_CAB] = {
    verticalAmplitude = 0.02,
    horizontalAmplitude = 0.01,
    frequency = 1.0,
  },
}

local KEYFRAME_OFFSETS = {
  LADDER_SLOPE = 0.8,
  STAIRS_SLOPE = 1.0,
  WHEEL_SIDEWALL_SAFE_DISTANCE = 1.0,
  WHEEL_TREAD_SAFE_DISTANCE = 0.75,
  DOOR_SAFE_DISTANCE = 0.35,
}

---Creates a new keyframe with the given type, start and end positions.
---@param type string The type of the keyframe (ex: walk, climb, etc).
---@param startPosition table The starting position of the keyframe.
---@param endPosition table The ending position of the keyframe.
---@return table CabCinematicKeyframe The created keyframe instance.
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

---Deletes the keyframe and its resources
function CabCinematicKeyframe:delete()
  self.type = nil
  self.startPosition = nil
  self.endPosition = nil
  self.speed = nil
  self.bobbingConfig = nil
  self.distance = nil
end

---Gets the duration of the keyframe based on its distance and speed.
---@return number duration The duration of the keyframe in seconds.
function CabCinematicKeyframe:getDuration()
  return self.distance / self.speed
end

---Calculates the view bobbing offset for the keyframe at time t.
---@param t number The time along the keyframe's duration to calculate the offset for.
---@return number horizontalOffset The horizontal offset to apply to the camera.
---@return number verticalOffset The vertical offset to apply to the camera.
---@return number depthOffset The depth offset to apply to the camera.
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

---Calculates the interpolated position along the keyframe's path at time t, including view bobbing offsets.
---@param t number The time along the keyframe's duration to calculate the position for.
---@return table The interpolated position at time t.
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

---Reverses the keyframe's start and end positions, effectively creating a keyframe that goes in the opposite direction.
---This is useful for generating exit animations from the same keyframes used for entering.
function CabCinematicKeyframe:reverse()
  local temp = self.startPosition
  self.startPosition = self.endPosition
  self.endPosition = temp
end

---Draws a debug line in the world representing the keyframe's path.
---@param relativeNode number The relative node to convert local positions to world positions.
function CabCinematicKeyframe:drawDebug(relativeNode)
  local startWorldPos = { localToWorld(relativeNode, unpack(self.startPosition)) }
  local endWorldPos = { localToWorld(relativeNode, unpack(self.endPosition)) }
  DebugUtil.drawDebugLine(startWorldPos[1], startWorldPos[2], startWorldPos[3], endWorldPos[1], endWorldPos[2], endWorldPos[3], 1, 0, 0, 0.5)
end

---Prints the keyframe's details for debugging purposes.
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

---Builds the keyframes for harvesters.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorPosition table The position of the vehicle's door.
---@param storeCategory string The vehicle's storeCategory.
---@param vehicleFeatures table The vehicle's features.
---@return table keyframes The list of keyframes for the vehicle.
local function buildHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSideCenter then
    local keyframes = {}
    local enterWheel = vehicleFeatures.positions.enterWheel
    local isEnterFarFromWheel = enterWheel ~= nil and math.abs(enterPosition[1] - enterWheel[1]) > KEYFRAME_OFFSETS.WHEEL_SIDEWALL_SAFE_DISTANCE

    local ladderBottom = {}

    if isEnterFarFromWheel then
      ladderBottom = {
        enterWheel[1] + KEYFRAME_OFFSETS.WHEEL_SIDEWALL_SAFE_DISTANCE,
        enterPosition[2],
        enterPosition[3]
      }

      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    else
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterPosition[3]
      }
    end

    local ladderTop = {
      ladderBottom[1] - KEYFRAME_OFFSETS.LADDER_SLOPE,
      doorPosition[2],
      ladderBottom[3]
    }

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      ladderBottom,
      ladderTop
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.WALK,
      ladderTop,
      doorPosition
    ))

    return keyframes
  elseif vehicleFeatures.flags.isEntryFromCabSideRear then
    local keyframes = {}
    local enterWheel = vehicleFeatures.positions.enterWheel
    local isEnterFarFromWheel = enterWheel ~= nil and math.abs(enterPosition[3] - enterWheel[3]) > KEYFRAME_OFFSETS.WHEEL_TREAD_SAFE_DISTANCE

    local ladderBottom = {}

    if isEnterFarFromWheel then
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterWheel[3] - KEYFRAME_OFFSETS.WHEEL_TREAD_SAFE_DISTANCE,
      }

      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    else
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterPosition[3]
      }
    end

    local ladderTop = {
      ladderBottom[1],
      doorPosition[2],
      ladderBottom[3] + KEYFRAME_OFFSETS.LADDER_SLOPE
    }

    local doorCross = {
      ladderTop[1],
      doorPosition[2],
      doorPosition[3],
    }

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      ladderBottom,
      ladderTop
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.WALK,
      ladderTop,
      doorCross
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.WALK,
      doorCross,
      doorPosition
    ))

    return keyframes
  end

  return {}
end

---Builds the keyframes for beet harvesters.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorPosition table The position of the vehicle's door.
---@param storeCategory string The vehicle's storeCategory.
---@param vehicleFeatures table The vehicle's features.
---@return table keyframes The list of keyframes for the vehicle.
local function buildBeetHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSideRear then
    local doorCross = {
      doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      doorPosition[2],
      doorPosition[3]
    }

    local ladderTop = {
      doorCross[1] + 0.2,
      doorCross[2],
      enterPosition[3]
    }

    local ladderBottom = {
      math.min(ladderTop[1] + KEYFRAME_OFFSETS.LADDER_SLOPE, enterPosition[1]),
      enterPosition[2],
      ladderTop[3]
    }

    local keyframes = {
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.CLIMB,
        ladderBottom,
        ladderTop
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        ladderTop,
        doorCross
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        doorCross,
        doorPosition
      ),
    }

    if (math.abs(enterPosition[1] - ladderBottom[1]) > 0) then
      table.insert(keyframes, 1, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    end

    return keyframes
  elseif vehicleFeatures.flags.isEntryFromCabSideCenter then
    local ladderTop = {
      doorPosition[1] + 0.2,
      doorPosition[2],
      enterPosition[3]
    }

    local ladderBottom = {
      math.min(ladderTop[1] + KEYFRAME_OFFSETS.LADDER_SLOPE, enterPosition[1]),
      enterPosition[2],
      ladderTop[3]
    }

    local keyframes = {
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.CLIMB,
        ladderBottom,
        ladderTop
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        ladderTop,
        doorPosition
      ),
    }

    return keyframes
  end

  return {}
end

---Builds the keyframes for forage harvesters.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorPosition table The position of the vehicle's door.
---@param storeCategory string The vehicle's storeCategory.
---@param vehicleFeatures table The vehicle's features.
---@return table keyframes The list of keyframes for the vehicle.
local function buildForageHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSideRear then
    local doorCross = {
      doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      doorPosition[2],
      doorPosition[3]
    }

    local ladderStep = {
      doorCross[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      enterPosition[2],
      enterPosition[3] + 0.12
    }

    local ladderBottom = {
      doorCross[1],
      enterPosition[2] + 0.25,
      enterPosition[3] + 0.25
    }

    local ladderTop = {
      doorCross[1],
      doorCross[2],
      math.min(ladderBottom[3] + KEYFRAME_OFFSETS.STAIRS_SLOPE, doorCross[3])
    }

    local keyframes = {
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderStep
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.CLIMB,
        ladderStep,
        ladderBottom
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.CLIMB,
        ladderBottom,
        ladderTop
      ),
    }

    if (math.abs(doorCross[3] - ladderTop[3]) > 0) then
      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        ladderTop,
        doorCross
      ))
    end

    return keyframes
  end

  return {}
end

---Builds the keyframes for tractors
---@param enterPosition table The position where the player enters the vehicle.
---@param doorPosition table The position of the vehicle's door.
---@param storeCategory string The vehicle's storeCategory.
---@param vehicleFeatures table The vehicle's features.
---@return table keyframes The list of keyframes for the vehicle.
local function buildTractorKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  -- if storeCategory == 'tractorss' then
  --   return {}
  -- end

  -- if storeCategory == 'tractorsm' then
  --   return {}
  -- end

  -- if storeCategory == 'tractorsl' then
  --   return {}
  -- end

  if not vehicleFeatures.flags.isCabEquipped then
    return {
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.SHIFT,
        enterPosition,
        doorPosition
      )
    }
  elseif vehicleFeatures.flags.isBiTracks and vehicleFeatures.flags.isTracksOnly then
    local wheelNode = vehicleFeatures.positions.wheelLeftBack or vehicleFeatures.positions.wheelRightBack
    local wheel = wheelNode
    local ladderBottom = {
      wheel[1] or doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      enterPosition[2],
      enterPosition[3]
    }

    local ladderTop = {
      ladderBottom[1],
      doorPosition[2],
      ladderBottom[3] - KEYFRAME_OFFSETS.LADDER_SLOPE
    }

    local doorCross = {
      ladderBottom[1],
      doorPosition[2],
      doorPosition[3]
    }

    return {
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.CLIMB,
        ladderBottom,
        ladderTop
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        ladderTop,
        doorCross
      ),
      CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        doorCross,
        doorPosition
      )
    }
  end

  return {
    CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      enterPosition,
      doorPosition
    )
  }
end

---Builds the keyframes for teleloaders, frontloaders, wheelloaders and forklifts.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorPosition table The position of the vehicle's door.
---@param storeCategory string The vehicle's storeCategory.
---@param vehicleFeatures table The vehicle's features.
---@return table keyframes The list of keyframes for the vehicle.
local function buildTeleloadersKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  return {
    CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      enterPosition,
      doorPosition
    )
  }
end

local function buildSprayersKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  local keyframes = {}

  if vehicleFeatures.flags.isEntryFromCabSide then
    local enterWheel = vehicleFeatures.positions.enterWheel
    local isEnterFarFromWheel = enterWheel ~= nil and math.abs(enterPosition[1] - enterWheel[1]) > KEYFRAME_OFFSETS.WHEEL_SIDEWALL_SAFE_DISTANCE
    local ladderBottom = {}

    if isEnterFarFromWheel then
      ladderBottom = {
        enterWheel[1] + KEYFRAME_OFFSETS.WHEEL_SIDEWALL_SAFE_DISTANCE,
        enterPosition[2],
        enterPosition[3]
      }

      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    else
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterPosition[3]
      }
    end

    local ladderTop = {
      ladderBottom[1] - KEYFRAME_OFFSETS.LADDER_SLOPE,
      doorPosition[2],
      ladderBottom[3]
    }

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      ladderBottom,
      ladderTop
    ))

    if vehicleFeatures.flags.isEntryFromCabSideRear then
      local doorCross = {
        doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
        doorPosition[2],
        doorPosition[3]
      }

      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        ladderTop,
        doorCross
      ))

      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        doorCross,
        doorPosition
      ))
    elseif vehicleFeatures.flags.isEntryFromCabSideCenter then
      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        ladderTop,
        doorPosition
      ))
    end
  elseif vehicleFeatures.flags.isEntryFromCabFront then
    local enterWheel = vehicleFeatures.positions.enterWheel
    local isEnterFarFromWheel = enterWheel ~= nil and math.abs(enterPosition[3] - enterWheel[3]) > KEYFRAME_OFFSETS.WHEEL_TREAD_SAFE_DISTANCE
    local ladderBottom = {}

    if isEnterFarFromWheel then
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterWheel[3] + KEYFRAME_OFFSETS.WHEEL_TREAD_SAFE_DISTANCE,
      }

      table.insert(keyframes, CabCinematicKeyframe.new(
        CabCinematicKeyframe.TYPES.WALK,
        enterPosition,
        ladderBottom
      ))
    else
      ladderBottom = {
        enterPosition[1],
        enterPosition[2],
        enterPosition[3]
      }
    end

    local ladderTop = {
      ladderBottom[1],
      doorPosition[2],
      ladderBottom[3] - KEYFRAME_OFFSETS.LADDER_SLOPE
    }

    local doorCross = {
      ladderTop[1],
      doorPosition[2],
      doorPosition[3],
    }

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      ladderBottom,
      ladderTop
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.WALK,
      ladderTop,
      doorCross
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.WALK,
      doorCross,
      doorPosition
    ))
  end

  return keyframes
end

---Builds the keyframes for grape and olive harvesters.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorPosition table The position of the vehicle's door.
---@param storeCategory string The vehicle's storeCategory.
---@param vehicleFeatures table The vehicle's features.
local function buildGrapeAndOliveHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  local keyframes = {}

  if vehicleFeatures.flags.isEntryFromCabSideRear then
    local ladderBottom = {
      doorPosition[1] + KEYFRAME_OFFSETS.DOOR_SAFE_DISTANCE,
      enterPosition[2],
      enterPosition[3]
    }

    local ladderTop = {
      ladderBottom[1],
      doorPosition[2],
      ladderBottom[3]
    }

    local doorCross = {
      ladderTop[1],
      doorPosition[2],
      doorPosition[3],
    }

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      ladderBottom,
      ladderTop
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.SHIFT,
      ladderTop,
      doorCross
    ))

    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.SHIFT,
      doorCross,
      doorPosition
    ))
  end

  return keyframes
end

---Builds the keyframes for the given vehicle based on its storeCategory and features.
---@param vehicle table The vehicle to build the keyframes for.
---@param reverse boolean Whether to reverse the keyframes (ex: for exiting the vehicle).
---@return table keyframes The list of keyframes for the vehicle.
function CabCinematicKeyframe.build(vehicle, reverse)
  local vehicleFeatures = vehicle:getCabCinematicFeatures()
  if vehicleFeatures == nil then
    return {}
  end

  local storeCategory = vehicle:getStoreCategory()

  local enterPosition = vehicleFeatures.positions.enter
  local doorPosition = vehicleFeatures.positions.leftDoor
  local standupPosition = vehicleFeatures.positions.standup
  local seatPosition = vehicleFeatures.positions.seat
  local keyframes = {}

  if CabCinematicUtil.isVehicleTractor(vehicle) then
    keyframes = buildTractorKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TELELOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FRONTLOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.WHEELLOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FORKLIFTS then
    keyframes = buildTeleloadersKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.HARVESTERS then
    keyframes = buildHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FORAGE_HARVESTERS then
    keyframes = buildForageHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.BEET_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SPINACH_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.POTATO_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GREEN_BEAN_HARVESTERS then
    keyframes = buildBeetHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SPRAYERS then
    keyframes = buildSprayersKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GRAPE_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.OLIVE_HARVESTERS then
    keyframes = buildGrapeAndOliveHarvesterKeyframes(enterPosition, doorPosition, storeCategory, vehicleFeatures)
  else
    table.insert(keyframes, CabCinematicKeyframe.new(
      CabCinematicKeyframe.TYPES.CLIMB,
      enterPosition,
      doorPosition
    ))
  end

  table.insert(keyframes, CabCinematicKeyframe.new(
    CabCinematicKeyframe.TYPES.IN_CAB,
    doorPosition,
    standupPosition
  ))

  table.insert(keyframes, CabCinematicKeyframe.new(
    CabCinematicKeyframe.TYPES.SEAT,
    standupPosition,
    seatPosition
  ))

  if reverse then
    local reversedKeyframes = {}
    for _, keyframe in ipairs(keyframes) do
      keyframe:reverse()
      table.insert(reversedKeyframes, 1, keyframe)
    end

    return reversedKeyframes
  end

  return keyframes
end

---Adapt keyframes to start from the given position and lead to the closest keyframe's start position,
---then appends the rest of the keyframes after it.
---@param keyframes table The list of keyframes to generate the shortcut from.
---@param position table The starting position for the adapted keyframe.
---@param type string | nil The type of the adapted keyframe.
---@return table adaptedKeyframes The updated list of keyframes with the adapted keyframe.
function CabCinematicKeyframe.adaptKeyframesFromPosition(keyframes, position, type)
  local shortestDistance = math.huge
  local shortestDistanceIndex = 1

  for index, keyframe in ipairs(keyframes) do
    local keyframeDistance = MathUtil.vector3Length(
      position[1] - keyframe.startPosition[1],
      position[2] - keyframe.startPosition[2],
      position[3] - keyframe.startPosition[3]
    )
    if keyframeDistance ~= nil and keyframeDistance < shortestDistance then
      shortestDistance = keyframeDistance
      shortestDistanceIndex = index
    end
  end

  if shortestDistanceIndex > 1 then
    local shortcutKeyframe = CabCinematicKeyframe.new(
      keyframes[shortestDistanceIndex - 1].type,
      position,
      keyframes[shortestDistanceIndex].startPosition)

    local adaptedKeyframes = { shortcutKeyframe }

    for i = shortestDistanceIndex, #keyframes do
      table.insert(adaptedKeyframes, keyframes[i])
    end

    return adaptedKeyframes
  end

  local shortcutKeyframe = CabCinematicKeyframe.new(
    type or CabCinematicKeyframe.TYPES.WALK,
    position,
    keyframes[shortestDistanceIndex].startPosition)

  local adaptedKeyframes = { shortcutKeyframe }
  for _, keyframe in ipairs(keyframes) do
    table.insert(adaptedKeyframes, keyframe)
  end

  return adaptedKeyframes
end
