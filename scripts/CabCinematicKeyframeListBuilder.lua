---@class CabCinematicKeyframeListBuilder
---Builds a sequence of keyframes by chaining positions and movement types.
---@field waypoints table List of positions (tables with x, y, z) for each keyframe.
---@field types table List of movement types (strings) corresponding to each keyframe.
CabCinematicKeyframeListBuilder = {}
local CabCinematicKeyframeListBuilder_mt = Class(CabCinematicKeyframeListBuilder)

---Creates a new builder starting from the given position.
---@param startPosition table The starting position {x, y, z}
---@return CabCinematicKeyframeListBuilder
function CabCinematicKeyframeListBuilder.new(startPosition)
  local self = setmetatable({}, CabCinematicKeyframeListBuilder_mt)
  self.waypoints = { startPosition }
  self.types = {}
  return self
end

---Adds a waypoint to the sequence.
---@param type string The movement type to reach this position (e.g., WALK, CLIMB)
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:add(type, position)
  if #self.waypoints > 0 then
    local lastPosition = self.waypoints[#self.waypoints]
    local distance = MathUtil.vector3Length(position[1] - lastPosition[1], position[2] - lastPosition[2], position[3] - lastPosition[3])
    if distance <= 0.01 then
      return self
    end
  end

  table.insert(self.types, type)
  table.insert(self.waypoints, position)

  return self
end

---Adds a walk waypoint to the sequence.
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:walkTo(position)
  return self:add(CabCinematicKeyframe.TYPES.WALK, position)
end

---Adds a climb waypoint to the sequence.
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:climbTo(position)
  return self:add(CabCinematicKeyframe.TYPES.CLIMB, position)
end

---Adds a shift waypoint to the sequence.
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:shiftTo(position)
  return self:add(CabCinematicKeyframe.TYPES.SHIFT, position)
end

---Adds a sit waypoint to the sequence.
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:sitIn(position)
  return self:add(CabCinematicKeyframe.TYPES.SIT, position)
end

---Adds a move in cab waypoint to the sequence.
---@param position table The target position {x, y, z}
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:moveInCabTo(type, position)
  return self:add(type, position)
end

---Builds and returns the array of keyframes.
---@return table keyframes The list of CabCinematicKeyframe instances
function CabCinematicKeyframeListBuilder:build()
  local keyframes = {}
  for i = 1, #self.types do
    table.insert(keyframes, CabCinematicKeyframe.new(self.types[i], self.waypoints[i], self.waypoints[i + 1]))
  end
  return keyframes
end

---Reverses the order of the waypoints and movement types in the builder.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:reverse()
  local reversedWaypoints = {}
  for i = #self.waypoints, 1, -1 do
    table.insert(reversedWaypoints, self.waypoints[i])
  end
  self.waypoints = reversedWaypoints

  local reversedTypes = {}
  for i = #self.types, 1, -1 do
    table.insert(reversedTypes, self.types[i])
  end
  self.types = reversedTypes

  return self
end

---Adapts builder to start from the given position and lead to the closest waypoint
---@param position table The starting position for the adapted keyframe.
---@param type string | nil The type of the adapted keyframe.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:adaptFromPosition(position, type)
  local shortestDistance = math.huge
  local shortestIndex = 1

  for i, waypoint in ipairs(self.waypoints) do
    local dx = position[1] - waypoint[1]
    local dy = position[2] - waypoint[2]
    local dz = position[3] - waypoint[3]
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist < shortestDistance then
      shortestDistance = dist
      shortestIndex = i
    end
  end

  table.insert(self.waypoints, 1, position)
  table.insert(self.types, 1, type or CabCinematicKeyframe.TYPES.WALK)

  if shortestIndex == 1 then
    return self
  end

  for i = 2, shortestIndex do
    table.remove(self.waypoints, 2)
    table.remove(self.types, 2)
  end

  return self
end

---Builds a keyframe sequence for a tractor based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildTractorKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  if not vehicleFeatures.flags.isCabEquipped then
    return self:shiftTo(doorSafePosition)
  elseif vehicleFeatures.flags.isBiTracks and vehicleFeatures.flags.isTracksOnly then
    local wheelNode = vehicleFeatures.flags.isEntryLeft and vehicleFeatures.positions.wheelLeftBack or vehicleFeatures.positions.wheelRightBack
    local wheel = wheelNode

    local ladderBottom = vehicleFeatures.positions.ladderBottom or {
      wheel[1] or doorSafePosition[1],
      enterPosition[2],
      enterPosition[3]
    }

    local ladderTop = vehicleFeatures.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabSideFront)
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  else
    return self:climbTo(doorSafePosition)
  end
end

---Builds a keyframe sequence for a teleloader based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildTeleloaderKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  return self:climbTo(doorSafePosition)
end

---Builds a keyframe sequence for a grain harvester based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildGrainHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  CabCinematicUtil.printTableRecursively(vehicleFeatures)

  local ladderBottom = vehicleFeatures.positions.ladderBottom or enterPosition
  local ladderTop = {}

  if vehicleFeatures.flags.isEntryFromCabSide then
    ladderTop = vehicleFeatures.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }
  else
    ladderTop = vehicleFeatures.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabFront),
    }
  end

  return self
      :walkTo(ladderBottom)
      :climbTo(ladderTop)
      :walkTo(doorSafePosition)
end

---Builds a keyframe sequence for a forage harvester based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildForageHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSideRear then
    local ladderBottom = {
      doorSafePosition[1],
      enterPosition[2] + 0.25,
      enterPosition[3] + 0.25
    }

    local ladderTop = {
      doorSafePosition[1],
      doorSafePosition[2],
      math.min(ladderBottom[3] + CabCinematicUtil.KEYFRAME_OFFSETS.STAIRS_SLOPE, doorSafePosition[3])
    }

    local ladderStep = {
      CabCinematicUtil.addByDirection(vehicleFeatures.positions.enterWheel[1], 0.15, vehicleFeatures.flags.isEntryFromCabSideLeft),
      enterPosition[2],
      enterPosition[3] + 0.07
    }

    return self
        :walkTo(ladderStep)
        :climbTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  end

  return self
end

---Builds a keyframe sequence for a beet harvester based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildBeetHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  local ladderBottom = vehicleFeatures.positions.ladderBottom or enterPosition
  local ladderTop = {}

  if vehicleFeatures.flags.isEntryFromCabSide then
    ladderTop = vehicleFeatures.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }
  else
    ladderTop = vehicleFeatures.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabFront),
    }
  end

  local ladderSafe = {
    doorSafePosition[1],
    doorSafePosition[2],
    ladderTop[3]
  }

  return self
      :walkTo(ladderBottom)
      :climbTo(ladderTop)
      :walkTo(ladderSafe)
      :walkTo(doorSafePosition)
end

---Builds a keyframe sequence for a grape and olive harvester based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildGrapeAndOliveHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSideRear then
    local ladderBottom = vehicleFeatures.positions.ladderBottom or {
      doorSafePosition[1],
      enterPosition[2],
      enterPosition[3]
    }

    local ladderTop = vehicleFeatures.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      ladderBottom[3]
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :shiftTo(doorSafePosition)
  end

  return self
end

---Builds a keyframe sequence for a sugarcane harvester based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildSugarcaneHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSide then
    local ladderBottom = vehicleFeatures.positions.ladderBottom or enterPosition

    local ladderTop = vehicleFeatures.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  end

  return self
end

---Builds a keyframe sequence for a rice harvester based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildRiceHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSide then
    local ladderBottom = vehicleFeatures.positions.ladderBottom or enterPosition
    local ladderTop = vehicleFeatures.positions.ladderTop or {
      doorSafePosition[1],
      doorSafePosition[2],
      doorSafePosition[3]
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  end

  return self
end

---Builds a keyframe sequence for sprayers based on its features and entry configuration.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildSprayersKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  if vehicleFeatures.flags.isEntryFromCabSide then
    local ladderBottom = vehicleFeatures.positions.ladderBottom or enterPosition
    local ladderTop = vehicleFeatures.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  elseif vehicleFeatures.flags.isEntryFromCabFront then
    local ladderBottom = vehicleFeatures.positions.ladderBottom or enterPosition
    local ladderTop = vehicleFeatures.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleFeatures.flags.isEntryFromCabFront),
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  end

  return self
end

--- Builds a keyframe sequence for skidsteers which don't have a cab and require the player to shift to the door safe position before entering.
---@param enterPosition table The position where the player enters the vehicle.
---@param doorSafePosition table The position in front of the door considered safe for the player.
---@param vehicleFeatures table The analyzed features of the vehicle, including positions and flags.
---@return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildSkidsteersKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  return self:shiftTo(doorSafePosition)
end

---Prepares a keyframe list builder for the given vehicle by analyzing its features and generating appropriate keyframes.
---@param vehicle table The vehicle for which to prepare the keyframe builder
---@return CabCinematicKeyframeListBuilder | nil builder The prepared keyframe list builder
function CabCinematicKeyframeListBuilder.prepareBuilderForVehicle(vehicle)
  local vehicleFeatures = vehicle:getCabCinematicFeatures()
  if vehicleFeatures == nil then
    return nil
  end

  local storeCategory = vehicle:getStoreCategory()
  local useLeftDoor = vehicleFeatures.flags.isEntryFromCabSideLeft or not vehicleFeatures.flags.isEntryFromCabSide
  local enterPosition = vehicleFeatures.positions.preferredEnter
  local doorPosition = useLeftDoor and vehicleFeatures.positions.leftDoor or vehicleFeatures.positions.rightDoor
  local doorSafePosition = useLeftDoor and vehicleFeatures.positions.leftDoorSafe or vehicleFeatures.positions.rightDoorSafe

  local builder = CabCinematicKeyframeListBuilder.new(vehicleFeatures.positions.enter)
      :walkTo(enterPosition)

  if CabCinematicUtil.isVehicleTractor(vehicle) then
    builder:buildTractorKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TELELOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FRONTLOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.WHEELLOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FORKLIFTS then
    builder:buildTeleloaderKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GRAIN_HARVESTERS then
    builder:buildGrainHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FORAGE_HARVESTERS then
    builder:buildForageHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.BEET_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SPINACH_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.POTATO_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GREEN_BEAN_HARVESTERS then
    builder:buildBeetHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GRAPE_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.OLIVE_HARVESTERS then
    builder:buildGrapeAndOliveHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SUGARCANE_HARVESTERS then
    builder:buildSugarcaneHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.RICE_HARVESTERS then
    builder:buildRiceHarvesterKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SPRAYERS then
    builder:buildSprayersKeyframes(enterPosition, doorSafePosition, vehicleFeatures)
  end

  return builder
      :walkTo(doorPosition)
      :moveInCabTo(CabCinematicKeyframe.TYPES.MOVE_IN_CAB, vehicleFeatures.positions.standup)
      :sitIn(vehicleFeatures.positions.seat)
end
