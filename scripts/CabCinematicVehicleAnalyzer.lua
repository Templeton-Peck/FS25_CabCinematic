--- @class CabCinematicVehicleAnalyzer
--- Analyzes vehicle physics and metadata properties to determine positions and flags for cab cinematics
CabCinematicVehicleAnalyzer = {}
local CabCinematicVehicleAnalyzer_mt = Class(CabCinematicVehicleAnalyzer)

local DOOR_SAFE_DISTANCE = 0.35

--- Creates a new vehicle analyzer instance
--- @param vehicle table The vehicle to analyze
--- @return CabCinematicVehicleAnalyzer
function CabCinematicVehicleAnalyzer.new(vehicle)
  local self = setmetatable({}, CabCinematicVehicleAnalyzer_mt)
  self.vehicle = vehicle
  return self
end

--- Deletes the vehicle analyzer instance and clears references
function CabCinematicVehicleAnalyzer:delete()
  self.vehicle = nil
end

--- Gets the indoor camera position relative to vehicle root
--- @return table Position {x, y, z}
function CabCinematicVehicleAnalyzer:getVehicleIndoorCameraPosition()
  local camera = self.vehicle:getIndoorCamera()
  if camera ~= nil then
    local dx, dy, dz = getTranslation(camera.cameraPositionNode)
    return { localToLocal(getParent(camera.cameraPositionNode), self.vehicle.rootNode, dx, dy, dz) }
  end

  return { 0, 0, 0 }
end

--- Gets the vehicle exit position relative to vehicle root
--- @return table Position {x, y, z}
function CabCinematicVehicleAnalyzer:getVehicleExitPosition()
  local exitNode = self.vehicle:getExitNode()
  return { localToLocal(getParent(exitNode), self.vehicle.rootNode, getTranslation(exitNode)) }
end

--- Gets analysis of a pneumatic wheel
--- @param wheel table The wheel data
--- @param positions table Current positions for reference
--- @return table|nil Wheel analysis with position, sidewallPosition, treadBackPosition, treadFrontPosition
function CabCinematicVehicleAnalyzer:getPneumaticWheelAnalysis(wheel, positions)
  if wheel == nil or wheel.visualWheels == nil or #wheel.visualWheels == 0 then
    return nil
  end

  local result = {
    position = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
    sidewallPosition = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
    treadBackPosition = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
    treadFrontPosition = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
  }

  local function getVisualWheelWidth(vw)
    return (vw.width) or (wheel.physics and (wheel.physics.width or wheel.physics.wheelShapeWidth)) or 0
  end

  if wheel.isLeft then
    local leftestVisualWheel = nil
    for _, vw in ipairs(wheel.visualWheels) do
      if vw.node ~= nil and vw.node ~= 0 then
        local x, y, z = localToLocal(getParent(vw.node), self.vehicle.rootNode, getTranslation(vw.node))
        if x > result.position[1] then
          result.position = { x, y, z }
          leftestVisualWheel = vw
        end
      end
    end

    if leftestVisualWheel ~= nil then
      result.treadBackPosition = { result.position[1], result.position[2], result.position[3] - leftestVisualWheel.radius }
      result.treadFrontPosition = { result.position[1], result.position[2], result.position[3] + leftestVisualWheel.radius }
      result.sidewallPosition = { result.position[1] + getVisualWheelWidth(leftestVisualWheel) * 0.5, result.position[2], result.position[3] }
    end
  else
    local rightestVisualWheel = nil
    for _, vw in ipairs(wheel.visualWheels) do
      if vw.node ~= nil and vw.node ~= 0 then
        local x, y, z = localToLocal(getParent(vw.node), self.vehicle.rootNode, getTranslation(vw.node))
        if x < result.position[1] then
          result.position = { x, y, z }
          rightestVisualWheel = vw
        end
      end
    end

    if rightestVisualWheel ~= nil then
      result.treadBackPosition = { result.position[1], result.position[2], result.position[3] - rightestVisualWheel.radius }
      result.treadFrontPosition = { result.position[1], result.position[2], result.position[3] + rightestVisualWheel.radius }
      result.sidewallPosition = { result.position[1] - getVisualWheelWidth(rightestVisualWheel) * 0.5, result.position[2], result.position[3] }
    end
  end

  return result
end

--- Gets analysis of a crawler track
--- @param crawler table The crawler data
--- @param positions table Current positions for reference
--- @return table Analysis analysis with position, sidewallPosition, treadBackPosition, treadFrontPosition
function CabCinematicVehicleAnalyzer:getCrawlerWheelAnalysis(crawler, positions)
  local x, y, z = localToLocal(crawler.linkNode, self.vehicle.rootNode, getTranslation(crawler.linkNode))

  local result = {
    position = { x, y, z },
    sidewallPosition = { x, y, z },
    treadBackPosition = { x, y, z },
    treadFrontPosition = { x, y, z },
  }

  local getHalfWidth = function(wheel)
    local w = (wheel.physics and (wheel.physics.width or wheel.physics.wheelShapeWidth)) or 0
    return 0.5 * w
  end

  if crawler.wheels ~= nil and #crawler.wheels > 0 then
    local summedPosition = { 0, 0, 0 }
    local wheelsCount = 0
    local largestZWheel = nil
    local smallestZWheel = nil

    for _, wheel in ipairs(crawler.wheels) do
      local node = wheel.wheel.driveNode or wheel.wheel.node
      if node ~= nil and node ~= 0 then
        local x, y, z = localToLocal(node, self.vehicle.rootNode, getTranslation(node))
        summedPosition[1] = summedPosition[1] + x
        summedPosition[2] = summedPosition[2] + y
        summedPosition[3] = summedPosition[3] + z
        wheelsCount = wheelsCount + 1

        if (largestZWheel == nil or z > largestZWheel[3]) then
          largestZWheel = { x, y, z, radius = wheel.wheel.physics.radius, width = getHalfWidth(wheel.wheel) }
        end

        if (smallestZWheel == nil or z < smallestZWheel[3]) then
          smallestZWheel = { x, y, z, radius = wheel.wheel.physics.radius, width = getHalfWidth(wheel.wheel) }
        end
      end
    end

    if wheelsCount > 0 and largestZWheel ~= nil and smallestZWheel ~= nil then
      local avgX = summedPosition[1] / wheelsCount
      local avgY = summedPosition[2] / wheelsCount
      local avgZ = summedPosition[3] / wheelsCount

      local sidewallOffsetX = crawler.isLeft and largestZWheel.width or -largestZWheel.width

      result.position = { avgX, avgY, avgZ }
      result.sidewallPosition = { avgX + sidewallOffsetX, avgY, avgZ }
      result.treadBackPosition = { avgX, avgY, avgZ }
      result.treadFrontPosition = { avgX, avgY, avgZ }

      result.treadBackPosition[3] = smallestZWheel[3] - smallestZWheel.radius
      result.treadFrontPosition[3] = largestZWheel[3] + largestZWheel.radius
    end
  end

  return result
end

--- Gets the position of character's feet when seated
--- @param positions table Current positions for reference
--- @return table Position Position of character's feet
function CabCinematicVehicleAnalyzer:getCabCharacterFootPosition(positions)
  local characterTargets = self.vehicle.spec_enterable.defaultCharacterTargets

  if characterTargets ~= nil then
    local foots = { characterTargets.leftFoot, characterTargets.rightFoot }
    local sumFootX = 0
    local lowestFootY = math.huge
    local largestFootZ = -math.huge

    for _, foot in pairs(foots) do
      if foot ~= nil then
        local footX, footY, footZ = localToLocal(foot.targetNode, self.vehicle.rootNode, 0, 0, 0)
        if footX ~= nil then
          sumFootX = sumFootX + footX
        end

        if footY ~= nil and footY < lowestFootY then
          lowestFootY = footY
        end

        if footZ ~= nil and footZ > largestFootZ then
          largestFootZ = footZ
        end
      end
    end

    if lowestFootY ~= math.huge and largestFootZ ~= -math.huge then
      return { sumFootX / 2, lowestFootY, largestFootZ }
    end
  end

  return { positions.camera[1], positions.camera[2] - 1.5, positions.camera[3] + 0.5 }
end

--- Gets the steering wheel position relative to vehicle root
--- @param positions table Current positions for reference
--- @return table Position {x, y, z}
function CabCinematicVehicleAnalyzer:getVehicleSteeringWheelPosition(positions)
  if self.vehicle.spec_drivable == nil or self.vehicle.spec_drivable.steeringWheel == nil then
    return { positions.camera[1], (positions.characterFoot[2] + positions.camera[2]) / 2, math.max(positions.characterFoot[3], positions.camera[3] + 0.35) }
  end

  local steeringWheelNode = self.vehicle.spec_drivable.steeringWheel.node
  return { localToLocal(steeringWheelNode, self.vehicle.rootNode, getTranslation(steeringWheelNode)) }
end

--- Performs raycasts to determine cab bounding box
--- @param positions table Current positions for reference
--- @return table Raycast results with positions and debug hits
function CabCinematicVehicleAnalyzer:raycastCabBoundingBox(positions)
  local backHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.camera[1], positions.camera[2], positions.camera[3] - 2.0 },
    { positions.camera[1], positions.camera[2], positions.camera[3] },
    function(hitA, hitB) return hitA[3] < hitB[3] end
  )

  local frontHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.camera[1], positions.camera[2], positions.steeringWheel[3] + 2.0 },
    { positions.camera[1], positions.camera[2], positions.steeringWheel[3] },
    function(hitA, hitB) return hitA[3] > hitB[3] end
  )

  local leftHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.camera[1] + 2.0, positions.camera[2], positions.camera[3] },
    { positions.camera[1], positions.camera[2], positions.camera[3] },
    function(hitA, hitB) return hitA[1] < hitB[1] end
  )

  local rightHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.camera[1] - 2.0, positions.camera[2], positions.steeringWheel[3] },
    { positions.camera[1], positions.camera[2], positions.steeringWheel[3] },
    function(hitA, hitB) return hitA[1] > hitB[1] end
  )

  local topHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.camera[1], positions.camera[2] + 2.0, positions.camera[3] },
    { positions.camera[1], positions.camera[2], positions.camera[3] },
    function(hitA, hitB) return hitA[2] > hitB[2] end
  )

  local top = topHitResult.best or { positions.camera[1], positions.camera[2] + 0.5, positions.camera[3] }
  local bottom = { positions.camera[1], math.max(positions.camera[2] - 1.5, positions.characterFoot[2]), positions.camera[3] }
  local centerY = (top[2] + bottom[2]) / 2

  local left = leftHitResult.best or { positions.camera[1] + 0.5, centerY, positions.camera[3] }
  local right = rightHitResult.best or { positions.camera[1] - 0.5, centerY, positions.camera[3] }
  local centerX = (left[1] + right[1]) / 2

  local back = backHitResult.best or { positions.camera[1], centerY, positions.camera[3] - 0.5 }
  local front = frontHitResult.best or { positions.camera[1], centerY, positions.steeringWheel[3] + 0.5 }
  local center = { centerX, centerY, (front[3] + back[3]) / 2 }

  return {
    back = back,
    front = front,
    left = left,
    right = right,
    top = top,
    bottom = bottom,
    center = center,
    hasHit = backHitResult.hasHit or frontHitResult.hasHit or leftHitResult.hasHit or rightHitResult.hasHit or topHitResult.hasHit or false,
    debugHits = {
      backHitResult = backHitResult,
      frontHitResult = frontHitResult,
      leftHitResult = leftHitResult,
      rightHitResult = rightHitResult,
      topHitResult = topHitResult,
    }
  }
end

--- Calculates the cab bounding box
--- @param positions table Current positions for reference
--- @return table Analysis analysis with bounding box positions, flags and debug hits
function CabCinematicVehicleAnalyzer:getCabAnalysis(positions)
  local raycastResult = self:raycastCabBoundingBox(positions)
  local debugPositions = {}

  local indoorCamera = self.vehicle:getIndoorCamera()
  if indoorCamera ~= nil then
    local shadowFocusBoxNode = indoorCamera.shadowFocusBoxNode
    if shadowFocusBoxNode ~= nil then
      local wfx, wfy, wfz, radius = getShapeWorldBoundingSphere(shadowFocusBoxNode)
      local fx, fy, fz            = worldToLocal(self.vehicle.rootNode, wfx, wfy, wfz)

      local focusBackZ            = fz - (radius / 2)
      local focusFrontZ           = fz + (radius / 2)
      local focusLeftX            = fx + (radius / 2)
      local focusRightX           = fx - (radius / 2)
      local focusTopY             = fy + (radius / 2)
      local focusBottomY          = fy - (radius / 2)

      raycastResult.back[3]       = math.max(raycastResult.back[3], focusBackZ)
      raycastResult.front[3]      = math.min(raycastResult.front[3], focusFrontZ)
      raycastResult.left[1]       = math.min(raycastResult.left[1], focusLeftX)
      raycastResult.right[1]      = math.max(raycastResult.right[1], focusRightX)
      raycastResult.top[2]        = math.max(raycastResult.top[2], focusTopY)
      raycastResult.bottom[2]     = math.min(raycastResult.bottom[2], focusBottomY)

      raycastResult.center[1]     = (raycastResult.left[1] + raycastResult.right[1]) / 2
      raycastResult.center[2]     = (raycastResult.top[2] + raycastResult.bottom[2]) / 2
      raycastResult.center[3]     = (raycastResult.front[3] + raycastResult.back[3]) / 2

      debugPositions.focusBack    = { fx, fy, focusBackZ }
      debugPositions.focusFront   = { fx, fy, focusFrontZ }
      debugPositions.focusLeft    = { focusLeftX, fy, fz }
      debugPositions.focusRight   = { focusRightX, fy, fz }
      debugPositions.focusTop     = { fx, focusTopY, fz }
      debugPositions.focusBottom  = { fx, focusBottomY, fz }
    end
  end

  return {
    debugHits = raycastResult.debugHits,
    debugPositions = debugPositions,
    flags = {
      isCabEquipped = raycastResult.hasHit,
    },
    positions = {
      back = raycastResult.back,
      front = raycastResult.front,
      left = raycastResult.left,
      right = raycastResult.right,
      top = raycastResult.top,
      bottom = raycastResult.bottom,
      center = raycastResult.center,
    },
  }
end

--- Gets the count of crawler tracks on the vehicle
--- @return number Number of crawlers
function CabCinematicVehicleAnalyzer:getCrawlersCount()
  return self.vehicle.spec_crawlers ~= nil and self.vehicle.spec_crawlers.crawlers ~= nil and #self.vehicle.spec_crawlers.crawlers or 0
end

--- Gets the count of pneumatic wheels on the vehicle
--- @return number Number of pneumatic wheels
function CabCinematicVehicleAnalyzer:getPneumaticWheelsCount()
  local count = 0

  if self.vehicle.spec_wheels ~= nil and self.vehicle.spec_wheels.wheels ~= nil then
    for _, wheel in pairs(self.vehicle.spec_wheels.wheels) do
      if wheel.visualWheels ~= nil then
        count = count + #wheel.visualWheels
      end
    end
  end

  return count
end

--- Analyzes all wheel analysis (pneumatic and crawler)
--- @param positions table Current positions for reference
--- @return table Analysis analysis with flags and positions
function CabCinematicVehicleAnalyzer:getWheelsAnalysis(positions)
  local crawlersCount = self:getCrawlersCount()
  local wheelsCount = self:getPneumaticWheelsCount()

  local result = {
    flags = {
      isQuadTracks = crawlersCount == 4,
      isBiTracks = crawlersCount == 2,
      isTracksOnly = crawlersCount > 0 and wheelsCount == 0,
    },
    positions = {
      wheelLeftFront = nil,
      wheelRightFront = nil,
      wheelLeftBack = nil,
      wheelRightBack = nil,
      wheelLeftFrontTreadFront = nil,
      wheelLeftFrontTreadBack = nil,
      wheelRightFrontTreadFront = nil,
      wheelRightFrontTreadBack = nil,
      wheelLeftBackTreadFront = nil,
      wheelLeftBackTreadBack = nil,
      wheelRightBackTreadFront = nil,
      wheelRightBackTreadBack = nil,
      wheelLeftFrontSidewall = nil,
      wheelRightFrontSidewall = nil,
      wheelLeftBackSidewall = nil,
      wheelRightBackSidewall = nil,
    },
  }

  if crawlersCount > 0 then
    for _, crawler in pairs(self.vehicle.spec_crawlers.crawlers) do
      local crawlerAnalysis = self:getCrawlerWheelAnalysis(crawler, positions)
      if crawlerAnalysis ~= nil then
        if crawler.isLeft then
          if crawlerAnalysis.position[3] > positions.root[3] then
            result.positions.wheelLeftFront = crawlerAnalysis.position
            result.positions.wheelLeftFrontTreadFront = crawlerAnalysis.treadFrontPosition
            result.positions.wheelLeftFrontTreadBack = crawlerAnalysis.treadBackPosition
            result.positions.wheelLeftFrontSidewall = crawlerAnalysis.sidewallPosition
          else
            result.positions.wheelLeftBack = crawlerAnalysis.position
            result.positions.wheelLeftBackTreadFront = crawlerAnalysis.treadFrontPosition
            result.positions.wheelLeftBackTreadBack = crawlerAnalysis.treadBackPosition
            result.positions.wheelLeftBackSidewall = crawlerAnalysis.sidewallPosition
          end
        else
          if crawlerAnalysis.position[3] > positions.root[3] then
            result.positions.wheelRightFront = crawlerAnalysis.position
            result.positions.wheelRightFrontTreadFront = crawlerAnalysis.treadFrontPosition
            result.positions.wheelRightFrontTreadBack = crawlerAnalysis.treadBackPosition
            result.positions.wheelRightFrontSidewall = crawlerAnalysis.sidewallPosition
          else
            result.positions.wheelRightBack = crawlerAnalysis.position
            result.positions.wheelRightBackTreadFront = crawlerAnalysis.treadFrontPosition
            result.positions.wheelRightBackTreadBack = crawlerAnalysis.treadBackPosition
            result.positions.wheelRightBackSidewall = crawlerAnalysis.sidewallPosition
          end
        end
      end
    end
  end

  if wheelsCount > 0 then
    for _, wheel in pairs(self.vehicle.spec_wheels.wheels) do
      local wheelAnalysis = self:getPneumaticWheelAnalysis(wheel, positions)
      if wheelAnalysis ~= nil then
        if wheelAnalysis.position[1] > positions.root[1] then
          if wheelAnalysis.position[3] > positions.root[3] then
            result.positions.wheelLeftFront = wheelAnalysis.position
            result.positions.wheelLeftFrontTreadFront = wheelAnalysis.treadFrontPosition
            result.positions.wheelLeftFrontTreadBack = wheelAnalysis.treadBackPosition
            result.positions.wheelLeftFrontSidewall = wheelAnalysis.sidewallPosition
          else
            result.positions.wheelLeftBack = wheelAnalysis.position
            result.positions.wheelLeftBackTreadFront = wheelAnalysis.treadFrontPosition
            result.positions.wheelLeftBackTreadBack = wheelAnalysis.treadBackPosition
            result.positions.wheelLeftBackSidewall = wheelAnalysis.sidewallPosition
          end
        else
          if wheelAnalysis.position[3] > positions.root[3] then
            result.positions.wheelRightFront = wheelAnalysis.position
            result.positions.wheelRightFrontTreadFront = wheelAnalysis.treadFrontPosition
            result.positions.wheelRightFrontTreadBack = wheelAnalysis.treadBackPosition
            result.positions.wheelRightFrontSidewall = wheelAnalysis.sidewallPosition
          else
            result.positions.wheelRightBack = wheelAnalysis.position
            result.positions.wheelRightBackTreadFront = wheelAnalysis.treadFrontPosition
            result.positions.wheelRightBackTreadBack = wheelAnalysis.treadBackPosition
            result.positions.wheelRightBackSidewall = wheelAnalysis.sidewallPosition
          end
        end
      end
    end
  end

  return result
end

--- Analyzes the vehicle to determine the enter position and related flags
--- @param positions table Current positions for reference
--- @return table Analysis analysis with positions and flags
function CabCinematicVehicleAnalyzer:getVehicleEnterAnalysis(positions)
  local playerEyeHeight = CabCinematicUtil.getPlayerEyesightHeight()
  local wex, wey, wez = getWorldTranslation(self.vehicle:getExitNode())
  local wty = getTerrainHeightAtWorldPos(g_terrainNode, wex, wey, wez)
  local _, wpy, _ = worldToLocal(self.vehicle.rootNode, wex, wty, wez)
  local enter = { positions.exit[1], wpy + playerEyeHeight, positions.exit[3] }

  local middleZ = (positions.steeringWheel[3] + positions.camera[3]) / 2
  local isEntryLeft = enter[1] >= positions.root[1]
  local isEntryRight = not isEntryLeft
  local isEntryFromCabFront = enter[3] >= positions.front[3] and math.abs(positions.enterWheel[1]) > math.abs(enter[1])
  local isEntryFromCabSide = not isEntryFromCabFront and math.abs(positions.enterWheel[1]) < math.abs(enter[1])
  local isEntryFromCabRear = not isEntryFromCabFront and not isEntryFromCabSide
  local isEntryFromCabSideLeft = isEntryFromCabSide and MathUtil.round(enter[1] - positions.center[1], 2) > 0.01
  local isEntryFromCabSideRight = isEntryFromCabSide and MathUtil.round(enter[1] - positions.center[1], 2) < -0.01
  local isEntryFromCabSideFront = isEntryFromCabSide and MathUtil.round(enter[3] - middleZ, 2) >= 0.35
  local isEntryFromCabSideRear = isEntryFromCabSide and MathUtil.round(enter[3] - middleZ, 2) <= -0.35
  local isEntryFromCabSideCenter = isEntryFromCabSide and not isEntryFromCabSideFront and not isEntryFromCabSideRear

  return {
    positions = {
      enter = enter,
    },
    flags = {
      isEntryLeft = isEntryLeft,
      isEntryRight = isEntryRight,
      isEntryFromCabFront = isEntryFromCabFront,
      isEntryFromCabSide = isEntryFromCabSide,
      isEntryFromCabRear = isEntryFromCabRear,
      isEntryFromCabSideLeft = isEntryFromCabSideLeft,
      isEntryFromCabSideRight = isEntryFromCabSideRight,
      isEntryFromCabSideFront = isEntryFromCabSideFront,
      isEntryFromCabSideRear = isEntryFromCabSideRear,
      isEntryFromCabSideCenter = isEntryFromCabSideCenter
    }
  }
end

--- Finds the closest wheel to the enter position based on combined distance to exit and camera
--- @param positions table Current positions for reference
--- @return table Wheel position {x, y, z }
function CabCinematicVehicleAnalyzer:getCabEnterWheelPosition(positions)
  local candidates = {}

  if positions.wheelLeftFrontSidewall ~= nil then
    if positions.wheelLeftFrontTreadFront ~= nil then
      table.insert(candidates, {
        positions.wheelLeftFrontSidewall[1],
        positions.wheelLeftFrontSidewall[2],
        positions.wheelLeftFrontTreadFront[3],
      })
    end
    if positions.wheelLeftFrontTreadBack ~= nil then
      table.insert(candidates, {
        positions.wheelLeftFrontSidewall[1],
        positions.wheelLeftFrontSidewall[2],
        positions.wheelLeftFrontTreadBack[3],
      })
    end
  end

  if positions.wheelRightFrontSidewall ~= nil then
    if positions.wheelRightFrontTreadFront ~= nil then
      table.insert(candidates, {
        positions.wheelRightFrontSidewall[1],
        positions.wheelRightFrontSidewall[2],
        positions.wheelRightFrontTreadFront[3],
      })
    end
    if positions.wheelRightFrontTreadBack ~= nil then
      table.insert(candidates, {
        positions.wheelRightFrontSidewall[1],
        positions.wheelRightFrontSidewall[2],
        positions.wheelRightFrontTreadBack[3],
      })
    end
  end

  if positions.wheelLeftBackSidewall ~= nil then
    if positions.wheelLeftBackTreadFront ~= nil then
      table.insert(candidates, {
        positions.wheelLeftBackSidewall[1],
        positions.wheelLeftBackSidewall[2],
        positions.wheelLeftBackTreadFront[3],
      })
    end
    if positions.wheelLeftBackTreadBack ~= nil then
      table.insert(candidates, {
        positions.wheelLeftBackSidewall[1],
        positions.wheelLeftBackSidewall[2],
        positions.wheelLeftBackTreadBack[3],
      })
    end
  end

  if positions.wheelRightBackSidewall ~= nil then
    if positions.wheelRightBackTreadFront ~= nil then
      table.insert(candidates, {
        positions.wheelRightBackSidewall[1],
        positions.wheelRightBackSidewall[2],
        positions.wheelRightBackTreadFront[3],
      })
    end
    if positions.wheelRightBackTreadBack ~= nil then
      table.insert(candidates, {
        positions.wheelRightBackSidewall[1],
        positions.wheelRightBackSidewall[2],
        positions.wheelRightBackTreadBack[3],
      })
    end
  end

  return CabCinematicUtil.getClosestPositionToTwoRefs(candidates, positions.exit, positions.camera)
end

--- Builds candidate Z door depths based on entry class and cabin depth
--- @param positions table
--- @param flags table
--- @return table
function CabCinematicVehicleAnalyzer:getDoorZCandidates(positions, flags)
  local minDoorZ = positions.back[3] + 0.2
  local maxDoorZ = positions.front[3] - 0.2
  local cabDepth = math.max(positions.front[3] - positions.back[3], 0.3)

  local frontZ = CabCinematicUtil.clamp(math.max(positions.steeringWheel[3], positions.front[3] - cabDepth * 0.2), minDoorZ, maxDoorZ)
  local centerZ = CabCinematicUtil.clamp((positions.steeringWheel[3] + positions.camera[3]) / 2, minDoorZ, maxDoorZ)
  local rearZ = CabCinematicUtil.clamp(positions.back[3] + cabDepth / 3, minDoorZ, maxDoorZ)

  local preferredZ = centerZ
  if flags.isEntryFromCabSideFront then
    preferredZ = frontZ
  elseif flags.isEntryFromCabSideRear then
    preferredZ = rearZ
  elseif flags.isEntryFromCabRear then
    preferredZ = rearZ
  elseif flags.isEntryFromCabFront then
    preferredZ = frontZ
  end

  return {
    frontZ = frontZ,
    centerZ = centerZ,
    rearZ = rearZ,
    preferredZ = preferredZ,
    minDoorZ = minDoorZ,
    maxDoorZ = maxDoorZ,
  }
end

--- Calculates the door positions on left and right sides
--- @param positions table Current positions for reference
--- @param flags table Current flags for reference
--- @return table Doors analysis with positions and flags
function CabCinematicVehicleAnalyzer:getCabDoorsAnalysis(positions, flags)
  local doorZCandidates = self:getDoorZCandidates(positions, flags)
  local minDoorZ = doorZCandidates.minDoorZ
  local maxDoorZ = doorZCandidates.maxDoorZ
  local preferredZ = doorZCandidates.preferredZ

  local function mirrorDrivenDoorZ(mirrorPosition)
    if mirrorPosition == nil then
      return nil
    end

    -- Use mirror depth as an anchor but keep entry-aware preferred depth influence.
    local mirrorZ = (positions.back[3] + mirrorPosition[3]) / 2
    local blendedZ = mirrorZ * 0.75 + preferredZ * 0.25
    return CabCinematicUtil.clamp(blendedZ, minDoorZ, maxDoorZ)
  end

  local leftZ = mirrorDrivenDoorZ(positions.leftMirror)
  local rightZ = mirrorDrivenDoorZ(positions.rightMirror)

  if leftZ == nil and rightZ ~= nil then
    leftZ = rightZ
  elseif rightZ == nil and leftZ ~= nil then
    rightZ = leftZ
  elseif leftZ == nil and rightZ == nil then
    leftZ = preferredZ
    rightZ = preferredZ
  end

  if CabCinematicUtil.isVehicleTractor(self.vehicle) and flags.isEntryFromCabSideFront then
    local frontTargetZ = doorZCandidates.frontZ
    if positions.enterWheel ~= nil then
      frontTargetZ = CabCinematicUtil.clamp(math.max(frontTargetZ, positions.enterWheel[3] - 0.1), minDoorZ, maxDoorZ)
    end

    -- For front-side tractor entries, keep the chosen side more forward to match real ladder/step access.
    if flags.isEntryFromCabSideLeft then
      leftZ = CabCinematicUtil.clamp(leftZ * 0.35 + frontTargetZ * 0.65, minDoorZ, maxDoorZ)
      rightZ = CabCinematicUtil.clamp(rightZ * 0.60 + frontTargetZ * 0.40, minDoorZ, maxDoorZ)
    else
      rightZ = CabCinematicUtil.clamp(rightZ * 0.35 + frontTargetZ * 0.65, minDoorZ, maxDoorZ)
      leftZ = CabCinematicUtil.clamp(leftZ * 0.60 + frontTargetZ * 0.40, minDoorZ, maxDoorZ)
    end
  end

  local platformLeft = positions.platformLeft ~= nil and (positions.platformLeft[1] - 0.25) or math.huge
  local platformRight = positions.platformRight ~= nil and (positions.platformRight[1] + 0.25) or -math.huge

  local leftDoor = { positions.left[1], positions.camera[2], leftZ }
  local rightDoor = { positions.right[1], positions.camera[2], rightZ }
  local leftDoorSafe = { math.min(leftDoor[1] + DOOR_SAFE_DISTANCE, platformLeft), leftDoor[2], leftDoor[3] }
  local rightDoorSafe = { math.max(rightDoor[1] - DOOR_SAFE_DISTANCE, platformRight), rightDoor[2], rightDoor[3] }

  if flags.isEntryFromCabSideFront then
    leftDoorSafe[3] = leftDoorSafe[3] + 0.15
    rightDoorSafe[3] = rightDoorSafe[3] + 0.15
  elseif flags.isEntryFromCabSideRear then
    leftDoorSafe[3] = leftDoorSafe[3] - 0.15
    rightDoorSafe[3] = rightDoorSafe[3] - 0.15
  end

  return {
    positions = {
      leftDoor = leftDoor,
      rightDoor = rightDoor,
      leftDoorSafe = leftDoorSafe,
      rightDoorSafe = rightDoorSafe,
    }
  }
end

--- Calculates the standup position inside the cab
--- @param positions table Current positions for reference
--- @param flags table Current flags for reference
--- @return table Standup position {x, y, z}
function CabCinematicVehicleAnalyzer:getCabStandupPosition(positions, flags)
  local standupX = (positions.camera[1] + positions.left[1]) / 2

  if flags.isEntryFromCabSide and not flags.isEntryFromCabSideLeft then
    standupX = (positions.camera[1] + positions.right[1]) / 2
  end

  local standupY = positions.camera[2] + 0.05
  local preferredStandupZ = ((positions.steeringWheel[3] + positions.camera[3]) * 0.5) * 1.05
  local standupZ = CabCinematicUtil.clamp(preferredStandupZ, positions.leftDoor[3], positions.front[3] - 0.15)
  return { standupX, standupY, standupZ }
end

--- Calculates the platform positions if the vehicle has a platform or returns empty if not
--- @param positions table Current positions for reference
--- @return table Platform analysis with positions and flags
function CabCinematicVehicleAnalyzer:getCabPlatformAnalysis(positions)
  if CabCinematicUtil.isVehicleTractor(self.vehicle) or CabCinematicUtil.isVehicleTelehandler(self.vehicle) or positions.bottom[2] <= 1.2 then
    return {
      positions = {},
      flags = {
        isPlatformEquipped = false
      }
    }
  end

  local leftPlatformHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.left[1] + 1.5, positions.bottom[2] - 0.175, positions.left[3] },
    { positions.left[1], positions.bottom[2] - 0.175, positions.left[3] },
    function(hitA, hitB) return hitA[1] > hitB[1] end
  )

  local rightPlatformHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    { positions.right[1] - 1.5, positions.bottom[2] - 0.175, positions.right[3] },
    { positions.right[1], positions.bottom[2] - 0.175, positions.right[3] },
    function(hitA, hitB) return hitA[1] < hitB[1] end
  )

  local leftPositions = { positions.left[1] }
  if positions.wheelLeftBack ~= nil then table.insert(leftPositions, positions.wheelLeftBack[1]) end
  if positions.wheelLeftFront ~= nil then table.insert(leftPositions, positions.wheelLeftFront[1]) end
  if leftPlatformHitResult.best ~= nil then table.insert(leftPositions, leftPlatformHitResult.best[1]) end


  local rightPositions = { positions.right[1] }
  if positions.wheelRightBack ~= nil then table.insert(rightPositions, positions.wheelRightBack[1]) end
  if positions.wheelRightFront ~= nil then table.insert(rightPositions, positions.wheelRightFront[1]) end
  if rightPlatformHitResult.best ~= nil then table.insert(rightPositions, rightPlatformHitResult.best[1]) end

  local platformLeftX = math.max(unpack(leftPositions))
  local platformRightX = math.min(unpack(rightPositions))

  local positions = {
    platformLeft = { platformLeftX, positions.bottom[2], positions.center[3] },
    platformRight = { platformRightX, positions.bottom[2], positions.center[3] },
    platformFront = { positions.center[1], positions.bottom[2], positions.front[3] },
    platformBack = { positions.center[1], positions.bottom[2], positions.back[3] },
    platformTop = { positions.center[1], positions.bottom[2], positions.center[3] },
    platformBottom = { positions.center[1], positions.bottom[2] - 0.25, positions.center[3] },
  }

  local flags = {
    isPlatformEquipped = true
  }

  return {
    positions = positions,
    flags = flags,
    debugHits = {
      leftPlatformHitResult = leftPlatformHitResult,
      rightPlatformHitResult = rightPlatformHitResult,
    }
  }
end

--- Calculates the mirror positions if the vehicle has mirrors or returns empty if not
--- @param positions table Current positions for reference
--- @return table Mirror analysis with positions and flags
function CabCinematicVehicleAnalyzer:getCabMirrorsAnalysis(positions)
  local leftMirrors = {}
  local rightMirrors = {}

  local mirrors = {}
  if self.vehicle.spec_enterable ~= nil and self.vehicle.spec_enterable.mirrors ~= nil then
    mirrors = self.vehicle.spec_enterable.mirrors
  end

  for _, mirror in ipairs(mirrors) do
    if mirror ~= nil and mirror.node ~= nil and mirror.node ~= 0 then
      local mirrorX, mirrorY, mirrorZ = localToLocal(mirror.node, self.vehicle.rootNode, 0, 0, 0)
      if mirrorX >= positions.center[1] then
        table.insert(leftMirrors, { mirrorX, mirrorY, mirrorZ })
      else
        table.insert(rightMirrors, { mirrorX, mirrorY, mirrorZ })
      end
    end
  end

  return {
    positions = {
      leftMirror = #leftMirrors > 0 and CabCinematicUtil.getClosestPositionToRef(leftMirrors, positions.center) or nil,
      rightMirror = #rightMirrors > 0 and CabCinematicUtil.getClosestPositionToRef(rightMirrors, positions.center) or nil,
    },
    flags = {
      hasMirrors = #leftMirrors + #rightMirrors > 0,
      hasLeftMirror = #leftMirrors > 0,
      hasRightMirror = #rightMirrors > 0,
    }
  }
end

--- Calculates the movable ladder positions based on combine ladder or enter animations
--- @param positions table Current positions for reference
--- @return table | nil ladderTopXZ The top X and Z positions for the ladder, can be nil if no candidates found
function CabCinematicVehicleAnalyzer:getCabMovableLadderTopXZ(positions)
  local nodes = {}

  if #nodes == 0 and self.vehicle.spec_combine ~= nil and self.vehicle.spec_combine.ladder ~= nil then
    nodes = CabCinematicUtil.getVehicleAnimationNodes(self.vehicle, self.vehicle.spec_combine.ladder.animName)
  end

  if #nodes == 0 and self.vehicle.spec_enterable ~= nil and self.vehicle.spec_enterable.enterAnimation ~= nil then
    nodes = CabCinematicUtil.getVehicleAnimationNodes(self.vehicle, self.vehicle.spec_enterable.enterAnimation)
  end

  if #nodes > 0 then
    local xCandidates = {}
    local zCandidates = {}
    local weights = {}

    for _, node in ipairs(nodes) do
      local nodeName = getName(node)
      if nodeName ~= nil and nodeName:lower():find("ladder") ~= nil and nodeName:lower():find("joint") == nil then
        local x, _, z = localToLocal(node, self.vehicle.rootNode, 0, 0, 0)
        table.insert(xCandidates, x)
        table.insert(zCandidates, z)
        table.insert(weights, 1.5)
      end
    end

    if #xCandidates > 0 and #zCandidates > 0 then
      table.insert(xCandidates, positions.enter[1])
      table.insert(zCandidates, positions.enter[3])
      table.insert(weights, 1.0)

      local ladderTopX = CabCinematicUtil.weightedAvg(xCandidates, weights)
      local ladderTopZ = CabCinematicUtil.weightedAvg(zCandidates, weights)

      return { ladderTopX = ladderTopX, ladderTopZ = ladderTopZ }
    end
  end

  return nil
end

--- Calculates the ladder positions if the vehicle has a movable ladder or returns empty if not
--- @param positions table Current positions for reference
--- @param flags table Current flags for reference
--- @return table Ladder analysis with positions and flags
function CabCinematicVehicleAnalyzer:getCabLadderAnalysis(positions, flags)
  local ladderTopXZ = self:getCabMovableLadderTopXZ(positions)

  if ladderTopXZ ~= nil then
    if flags.isEntryFromCabSide then
      if flags.isEntryFromCabSideLeft then
        local ladderTop = { math.max(positions.platformLeft and positions.platformLeft[1] or 0, positions.left[1], positions.enterWheel[1] + 0.1), positions.camera[2], ladderTopXZ.ladderTopZ }
        local ladderBottom = { math.min(ladderTop[1] + 0.8, positions.enter[1]), positions.enter[2], ladderTop[3] }
        return {
          positions = {
            ladderTop = ladderTop,
            ladderBottom = ladderBottom
          },
          flags = {
            isMovableLadderEquipped = true,
          }
        }
      else
        local ladderTop = { math.min(positions.platformRight and positions.platformRight[1] or 0, positions.right[1], positions.enterWheel[1] - 0.1), positions.camera[2], ladderTopXZ.ladderTopZ }
        local ladderBottom = { math.max(ladderTop[1] - 0.8, positions.enter[1]), positions.enter[2], ladderTop[3] }
        return {
          positions = {
            ladderTop = ladderTop,
            ladderBottom = ladderBottom
          },
          flags = {
            isMovableLadderEquipped = true,
          }
        }
      end
    elseif flags.isEntryFromCabFront then
      local ladderTop = { ladderTopXZ.ladderTopX, positions.camera[2], math.max(positions.platformFront and positions.platformFront[3] or 0, positions.front[3], positions.enterWheel[3] + 0.1) }
      local ladderBottom = { ladderTop[1], positions.enter[2], math.min(ladderTop[3] + 0.8, positions.enter[3]) }

      return {
        positions = {
          ladderTop = ladderTop,
          ladderBottom = ladderBottom
        },
        flags = {
          isMovableLadderEquipped = true,
        }
      }
    end
  end

  return {
    positions = {},
    flags = {
      isMovableLadderEquipped = false,
    }
  }
end

--- Determines the preferred enter position based on the entry point and available analysis
--- @param positions table Current positions for reference
--- @param flags table Current flags for reference
--- @return table Preferred enter position
function CabCinematicVehicleAnalyzer:getPreferredEnterPosition(positions, flags)
  local preferredEnter = { positions.enter[1], positions.enter[2], positions.enter[3] }
  local bodyworkSafeDistance = 0.5

  if positions.ladderBottom ~= nil then
    preferredEnter[1] = positions.ladderBottom[1]
    preferredEnter[3] = positions.ladderBottom[3]
  elseif flags.isEntryFromCabSide then
    if flags.isEntryFromCabSideLeft then
      local bodyworkX = math.max(positions.enterWheel[1], positions.platformLeft and positions.platformLeft[1] or 0, positions.left[1])
      preferredEnter[1] = math.min(positions.enter[1], bodyworkX + bodyworkSafeDistance)

      if CabCinematicUtil.isVehicleTractor(self.vehicle) then
        if positions.wheelLeftBack ~= nil and positions.wheelLeftFront ~= nil then
          local centerEnterZ = (positions.wheelLeftFront[3] + positions.wheelLeftBack[3]) / 2
          if CabCinematicUtil.isNear(positions.enter[3], centerEnterZ, 0.15) then
            preferredEnter[3] = centerEnterZ
          end
        end
      end
    elseif flags.isEntryFromCabSideRight then
      local bodyworkX = math.min(positions.enterWheel[1], positions.platformRight and positions.platformRight[1] or 0, positions.right[1])
      preferredEnter[1] = math.max(positions.enter[1], bodyworkX - bodyworkSafeDistance)

      if CabCinematicUtil.isVehicleTractor(self.vehicle) then
        if positions.wheelRightBack ~= nil and positions.wheelRightFront ~= nil then
          local centerEnterZ = (positions.wheelRightFront[3] + positions.wheelRightBack[3]) / 2
          if CabCinematicUtil.isNear(positions.enter[3], centerEnterZ, 0.15) then
            preferredEnter[3] = centerEnterZ
          end
        end
      end
    end
  else
    if flags.isEntryFromCabFront then
      local bodyworkZ = math.max(positions.enterWheel[3], positions.platformFront and positions.platformFront[3] or 0, positions.front[3])
      preferredEnter[3] = math.min(positions.enter[3], bodyworkZ + bodyworkSafeDistance)
    elseif flags.isEntryFromCabRear then
      local bodyworkZ = math.min(positions.enterWheel[3], positions.platformBack and positions.platformBack[3] or 0, positions.back[3])
      preferredEnter[3] = math.max(positions.enter[3], bodyworkZ - bodyworkSafeDistance)
    end
  end

  return preferredEnter
end

--- Analyzes the vehicle and returns all positions and flags
--- @return table Analysis result with positions, flags, and debug information
function CabCinematicVehicleAnalyzer:analyze()
  local flags = {}
  local debugPositions = {}
  local debugHits = {}

  -- Base positions
  local positions = {
    root = { localToLocal(getParent(self.vehicle.rootNode), self.vehicle.rootNode, getTranslation(self.vehicle.rootNode)) },
    camera = self:getVehicleIndoorCameraPosition(),
    exit = self:getVehicleExitPosition()
  }

  positions.seat = { positions.camera[1], positions.camera[2], positions.camera[3] }
  positions.characterFoot = self:getCabCharacterFootPosition(positions)
  positions.steeringWheel = self:getVehicleSteeringWheelPosition(positions)

  -- Wheel analysis
  local wheelsAnalysis = self:getWheelsAnalysis(positions)
  CabCinematicUtil.merge(positions, wheelsAnalysis.positions)
  CabCinematicUtil.merge(flags, wheelsAnalysis.flags)

  -- Enter wheel position
  positions.enterWheel = self:getCabEnterWheelPosition(positions)

  -- Cab analysis
  local cabAnalysis = self:getCabAnalysis(positions)
  CabCinematicUtil.merge(positions, cabAnalysis.positions)
  CabCinematicUtil.merge(flags, cabAnalysis.flags)
  CabCinematicUtil.merge(debugPositions, cabAnalysis.debugPositions)
  CabCinematicUtil.merge(debugHits, cabAnalysis.debugHits)

  --- Platform analysis
  local platformAnalysis = self:getCabPlatformAnalysis(positions)
  CabCinematicUtil.merge(positions, platformAnalysis.positions)
  CabCinematicUtil.merge(flags, platformAnalysis.flags)
  CabCinematicUtil.merge(debugHits, platformAnalysis.debugHits)

  -- Enter analysis
  local enterAnalysis = self:getVehicleEnterAnalysis(positions)
  CabCinematicUtil.merge(positions, enterAnalysis.positions)
  CabCinematicUtil.merge(flags, enterAnalysis.flags)

  --- Mirror analysis
  local mirrorsAnalysis = self:getCabMirrorsAnalysis(positions)
  CabCinematicUtil.merge(positions, mirrorsAnalysis.positions)
  CabCinematicUtil.merge(flags, mirrorsAnalysis.flags)

  -- Door positions
  local doors = self:getCabDoorsAnalysis(positions, flags)
  CabCinematicUtil.merge(positions, doors.positions)
  CabCinematicUtil.merge(flags, doors.flags)
  CabCinematicUtil.merge(debugPositions, doors.debugPositions)

  -- Ladder analysis
  local ladderAnalysis = self:getCabLadderAnalysis(positions, flags)
  CabCinematicUtil.merge(positions, ladderAnalysis.positions)
  CabCinematicUtil.merge(flags, ladderAnalysis.flags)

  -- Standup position
  positions.standup = self:getCabStandupPosition(positions, flags)

  -- Preferred enter position
  positions.preferredEnter = self:getPreferredEnterPosition(positions, flags)

  return {
    positions = positions,
    flags = flags,
    debugPositions = debugPositions,
    debugHits = debugHits,
  }
end
