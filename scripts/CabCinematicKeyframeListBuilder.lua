--- @class CabCinematicKeyframeListBuilder
--- Builds a sequence of keyframes by chaining positions and movement types.
--- @field waypoints table List of positions (tables with x, y, z) for each keyframe.
--- @field types table List of movement types (strings) corresponding to each keyframe.
CabCinematicKeyframeListBuilder = {}
local CabCinematicKeyframeListBuilder_mt = Class(CabCinematicKeyframeListBuilder)

--- Creates a new builder starting from the given position.
--- @param startPosition table The starting position {x, y, z}
--- @return CabCinematicKeyframeListBuilder
function CabCinematicKeyframeListBuilder.new(startPosition)
  local self = setmetatable({}, CabCinematicKeyframeListBuilder_mt)
  self.waypoints = { startPosition }
  self.types = {}
  return self
end

--- Adds a waypoint to the sequence.
--- @param type string The movement type to reach this position (e.g., WALK, CLIMB)
--- @param position table The target position {x, y, z}
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:add(type, position)
  if #self.waypoints > 0 then
    local lastPosition = self.waypoints[#self.waypoints]
    local distance = MathUtil.vector3Length(position[1] - lastPosition[1], position[2] - lastPosition[2], position[3] - lastPosition[3])
    if distance <= 0.15 then
      lastPosition[1] = (lastPosition[1] + position[1]) / 2
      lastPosition[2] = (lastPosition[2] + position[2]) / 2
      lastPosition[3] = (lastPosition[3] + position[3]) / 2

      return self
    end
  end

  table.insert(self.types, type or CabCinematicKeyframe.TYPES.WALK)
  table.insert(self.waypoints, position)

  return self
end

--- Adds a waypoint relative to the last waypoint in the sequence.
--- @param type string The movement type to reach this position (e.g., WALK, CLIMB)
--- @param offsets table The offsets {x, y, z} to apply to the last waypoints position
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:addRelative(type, offsets)
  local lastPosition = self.waypoints[#self.waypoints]
  local newPosition = {
    lastPosition[1] + (offsets[1] or 0),
    lastPosition[2] + (offsets[2] or 0),
    lastPosition[3] + (offsets[3] or 0)
  }

  return self:add(type, newPosition)
end

--- Adds a walk waypoint to the sequence.
--- @param position table The target position {x, y, z}
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:walkTo(position)
  return self:add(CabCinematicKeyframe.TYPES.WALK, position)
end

--- Adds a climb waypoint to the sequence.
--- @param position table The target position {x, y, z}
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:climbTo(position)
  return self:add(CabCinematicKeyframe.TYPES.CLIMB, position)
end

--- Adds a shift waypoint to the sequence.
--- @param position table The target position {x, y, z}
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:shiftTo(position)
  return self:add(CabCinematicKeyframe.TYPES.SHIFT, position)
end

--- Adds a sit waypoint to the sequence.
--- @param position table The target position {x, y, z}
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:sitIn(position)
  return self:add(CabCinematicKeyframe.TYPES.SIT, position)
end

--- Adds a move in cab waypoint to the sequence.
--- @param position table The target position {x, y, z}
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:moveInCabTo(type, position)
  return self:add(type, position)
end

--- Builds and returns the array of keyframes.
--- @return table keyframes The list of CabCinematicKeyframe instances
function CabCinematicKeyframeListBuilder:build()
  local keyframes = {}
  for i = 1, #self.types do
    table.insert(keyframes, CabCinematicKeyframe.new(self.types[i], self.waypoints[i], self.waypoints[i + 1]))
  end
  return keyframes
end

--- Reverses the order of the waypoints and movement types in the builder.
--- @return CabCinematicKeyframeListBuilder self for method chaining
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

--- Adapts builder to start from the given position and lead to the closest waypoint
--- @param position table The starting position for the adapted keyframe.
--- @param type string | nil The type of the adapted keyframe.
--- @return CabCinematicKeyframeListBuilder self for method chaining
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

--- Builds a keyframe sequence for a tractor based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildTractorKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if not vehicleAnalysis.flags.isCabEquipped then
    return self:shiftTo(doorSafePosition)
  elseif vehicleAnalysis.flags.isBiTracks and vehicleAnalysis.flags.isTracksOnly then
    local wheelNode = vehicleAnalysis.flags.isEntryLeft and vehicleAnalysis.positions.wheelLeftBack or vehicleAnalysis.positions.wheelRightBack
    local wheel = wheelNode

    local ladderBottom = vehicleAnalysis.positions.ladderBottom or {
      wheel[1] or doorSafePosition[1],
      accessPosition[2],
      accessPosition[3]
    }

    local ladderTop = vehicleAnalysis.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabSideFront)
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  else
    return self:climbTo(doorSafePosition)
  end
end

--- Builds a keyframe sequence for a teleloader based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildTeleloaderKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  return self:climbTo(doorSafePosition)
end

--- Builds a keyframe sequence for a grain harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildGrainHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition
  local ladderTop = {}

  if vehicleAnalysis.flags.isEntryFromCabSide then
    ladderTop = vehicleAnalysis.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }
  else
    ladderTop = vehicleAnalysis.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabFront),
    }
  end

  return self
      :walkTo(ladderBottom)
      :climbTo(ladderTop)
      :walkTo(doorSafePosition)
end

--- Builds a keyframe sequence for a forage harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildForageHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if vehicleAnalysis.flags.isEntryFromCabSideRear then
    local ladderBottom = {
      doorSafePosition[1],
      accessPosition[2] + 0.25,
      accessPosition[3] + 0.25
    }

    local ladderTop = {
      doorSafePosition[1],
      doorSafePosition[2],
      math.min(ladderBottom[3] + CabCinematicUtil.KEYFRAME_OFFSETS.STAIRS_SLOPE, doorSafePosition[3])
    }

    local ladderStep = {
      CabCinematicUtil.addByDirection(vehicleAnalysis.positions.accessWheel[1], 0.15, vehicleAnalysis.flags.isEntryFromCabSideLeft),
      accessPosition[2],
      accessPosition[3] + 0.07
    }

    return self
        :walkTo(ladderStep)
        :climbTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  end

  return self
end

--- Builds a keyframe sequence for a beet harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildBeetHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition
  local ladderTop = {}

  if vehicleAnalysis.flags.isEntryFromCabSide then
    ladderTop = vehicleAnalysis.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }
  else
    ladderTop = vehicleAnalysis.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabFront),
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

--- Builds a keyframe sequence for a grape and olive harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildGrapeAndOliveHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if vehicleAnalysis.flags.isEntryFromCabSideRear then
    local ladderBottom = vehicleAnalysis.positions.ladderBottom or {
      doorSafePosition[1],
      accessPosition[2],
      accessPosition[3]
    }

    local ladderTop = vehicleAnalysis.positions.ladderTop or {
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

--- Builds a keyframe sequence for a sugarcane harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildSugarcaneHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if vehicleAnalysis.flags.isEntryFromCabSide then
    local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition

    local ladderTop = vehicleAnalysis.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabSideLeft),
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

--- Builds a keyframe sequence for a rice harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildRiceHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if vehicleAnalysis.flags.isEntryFromCabSide then
    local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition
    local ladderTop = vehicleAnalysis.positions.ladderTop or {
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

--- Builds a keyframe sequence for a cotton harvester based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildCottonHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if vehicleAnalysis.flags.isEntryFromCabSide then
    local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition
    local ladderTop = vehicleAnalysis.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_LIGHT_SLOPE, true),
      doorSafePosition[2],
      ladderBottom[3]
    }

    self:walkTo(ladderBottom)
    self:climbTo(ladderTop)

    if configuration ~= nil then
      for _, waypoint in ipairs(configuration.keyframeWaypoints) do
        self:addRelative(waypoint.type, waypoint.offsets)
      end
    end

    return self:walkTo(doorSafePosition)
  end

  return self
end

--- Builds a keyframe sequence for sprayers based on its analysis and entry configuration.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildSprayersKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  if vehicleAnalysis.flags.isEntryFromCabSide then
    local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition
    local ladderTop = vehicleAnalysis.positions.ladderTop or {
      CabCinematicUtil.subByDirection(ladderBottom[1], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabSideLeft),
      doorSafePosition[2],
      ladderBottom[3]
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  elseif vehicleAnalysis.flags.isEntryFromCabFront then
    local ladderBottom = vehicleAnalysis.positions.ladderBottom or accessPosition
    local ladderTop = vehicleAnalysis.positions.ladderTop or {
      ladderBottom[1],
      doorSafePosition[2],
      CabCinematicUtil.subByDirection(ladderBottom[3], CabCinematicUtil.KEYFRAME_OFFSETS.LADDER_SLOPE, vehicleAnalysis.flags.isEntryFromCabFront),
    }

    return self
        :walkTo(ladderBottom)
        :climbTo(ladderTop)
        :walkTo(doorSafePosition)
  end

  return self
end

--- Builds a keyframe sequence for skidsteers which don't have a cab and require the player to shift to the door safe position before entering.
--- @param accessPosition table The position where the player accesses the vehicle.
--- @param doorSafePosition table The position in front of the door considered safe for the player.
--- @param vehicleAnalysis table The analyzed analysis of the vehicle, including positions and flags.
--- @param configuration CabCinematicConfiguration | nil The vehicle-specific configuration.
--- @return CabCinematicKeyframeListBuilder self for method chaining
function CabCinematicKeyframeListBuilder:buildSkidsteersKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  return self:shiftTo(doorSafePosition)
end

--- Prepares a keyframe list builder for the given vehicle by analyzing its analysis and generating appropriate keyframes.
--- @param vehicle table The vehicle for which to prepare the keyframe builder
--- @return CabCinematicKeyframeListBuilder | nil builder The prepared keyframe list builder
function CabCinematicKeyframeListBuilder.prepareBuilderForVehicle(vehicle)
  local vehicleAnalysis = vehicle:getCabCinematicAnalysis()
  if vehicleAnalysis == nil then
    return nil
  end

  local storeCategory = vehicle:getStoreCategory()
  local useLeftDoor = vehicleAnalysis.flags.isEntryFromCabSideLeft or not vehicleAnalysis.flags.isEntryFromCabSide
  local accessPosition = vehicleAnalysis.positions.preferredAccess
  local doorPosition = useLeftDoor and vehicleAnalysis.positions.leftDoor or vehicleAnalysis.positions.rightDoor
  local doorSafePosition = useLeftDoor and vehicleAnalysis.positions.leftDoorSafe or vehicleAnalysis.positions.rightDoorSafe

  local builder = CabCinematicKeyframeListBuilder.new(accessPosition)

  local configuration = CabCinematic.configurationManager:get(vehicle)

  if CabCinematicUtil.isVehicleTractor(vehicle) then
    builder:buildTractorKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TELELOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FRONTLOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.WHEELLOADERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FORKLIFTS then
    builder:buildTeleloaderKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GRAIN_HARVESTERS then
    builder:buildGrainHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.FORAGE_HARVESTERS then
    builder:buildForageHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.BEET_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SPINACH_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.POTATO_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GREEN_BEAN_HARVESTERS then
    builder:buildBeetHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.GRAPE_HARVESTERS
      or storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.OLIVE_HARVESTERS then
    builder:buildGrapeAndOliveHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SUGARCANE_HARVESTERS then
    builder:buildSugarcaneHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.RICE_HARVESTERS then
    builder:buildRiceHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.COTTON_HARVESTERS then
    builder:buildCottonHarvesterKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  elseif storeCategory == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.SPRAYERS then
    builder:buildSprayersKeyframes(accessPosition, doorSafePosition, vehicleAnalysis, configuration)
  end

  return builder
      :walkTo(doorPosition)
      :moveInCabTo(CabCinematicKeyframe.TYPES.MOVE_IN_CAB, vehicleAnalysis.positions.standup)
      :sitIn(vehicleAnalysis.positions.seat)
end
