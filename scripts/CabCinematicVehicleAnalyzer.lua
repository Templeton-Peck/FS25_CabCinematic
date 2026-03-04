---@class CabCinematicVehicleAnalyzer
---Analyzes vehicle features to determine positions and flags for cab cinematics
CabCinematicVehicleAnalyzer = {}
local CabCinematicVehicleAnalyzer_mt = Class(CabCinematicVehicleAnalyzer)

---Creates a new vehicle analyzer instance
---@param vehicle table The vehicle to analyze
---@return CabCinematicVehicleAnalyzer
function CabCinematicVehicleAnalyzer.new(vehicle)
  local self = setmetatable({}, CabCinematicVehicleAnalyzer_mt)
  self.vehicle = vehicle
  return self
end

---Deletes the vehicle analyzer instance and clears references
function CabCinematicVehicleAnalyzer:delete()
  self.vehicle = nil
end

---Gets the indoor camera position relative to vehicle root
---@return table Position {x, y, z}
function CabCinematicVehicleAnalyzer:getVehicleIndoorCameraPosition()
  local camera = self.vehicle:getIndoorCamera()
  if camera ~= nil then
    local dx, dy, dz = getTranslation(camera.cameraPositionNode)
    return { localToLocal(getParent(camera.cameraPositionNode), self.vehicle.rootNode, dx, dy, dz) }
  end

  return { 0, 0, 0 }
end

---Gets the steering wheel position relative to vehicle root
---@return table Position {x, y, z}
function CabCinematicVehicleAnalyzer:getVehicleSteeringWheelPosition()
  if self.vehicle.spec_drivable == nil or self.vehicle.spec_drivable.steeringWheel == nil then
    return { 0, 0, 0 }
  end

  local steeringWheelNode = self.vehicle.spec_drivable.steeringWheel.node
  return { localToLocal(steeringWheelNode, self.vehicle.rootNode, getTranslation(steeringWheelNode)) }
end

---Gets the vehicle exit position relative to vehicle root
---@return table Position {x, y, z}
function CabCinematicVehicleAnalyzer:getVehicleExitPosition()
  local exitNode = self.vehicle:getExitNode()
  return { localToLocal(getParent(exitNode), self.vehicle.rootNode, getTranslation(exitNode)) }
end

---Gets features of a pneumatic wheel
---@param wheel table The wheel data
---@param positions table Current positions for reference
---@return table|nil Wheel features with position, sidewallPosition, treadPosition
function CabCinematicVehicleAnalyzer:getPneumaticWheelFeatures(wheel, positions)
  if wheel == nil or wheel.visualWheels == nil or #wheel.visualWheels == 0 then
    return nil
  end

  local result = {
    position = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
    sidewallPosition = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
    treadPosition = { wheel.isLeft and -math.huge or math.huge, 0, 0 },
  }

  local function getHalfWidth(vw)
    local w = (vw.width) or (wheel.physics and (wheel.physics.width or wheel.physics.wheelShapeWidth)) or 0
    return 0.5 * w
  end

  for _, vw in ipairs(wheel.visualWheels) do
    if vw.node ~= nil and vw.node ~= 0 then
      local halfWidth = getHalfWidth(vw)
      local x, y, z = localToLocal(vw.node, self.vehicle.rootNode, getTranslation(vw.node))
      local swx1, swy1, swz1 = localToLocal(vw.node, self.vehicle.rootNode, halfWidth, 0, 0)
      local swx2, swy2, swz2 = localToLocal(vw.node, self.vehicle.rootNode, -halfWidth, 0, 0)

      if wheel.isLeft then
        if x > result.position[1] then result.position = { x, y, z } end
        if swx1 > result.sidewallPosition[1] then result.sidewallPosition = { swx1, swy1, swz1 } end
        if swx2 > result.sidewallPosition[1] then result.sidewallPosition = { swx2, swy2, swz2 } end
      else
        if x < result.position[1] then result.position = { x, y, z } end
        if swx1 < result.sidewallPosition[1] then result.sidewallPosition = { swx1, swy1, swz1 } end
        if swx2 < result.sidewallPosition[1] then result.sidewallPosition = { swx2, swy2, swz2 } end
      end

      if result.position[3] > positions.root[3] then
        result.treadPosition = { x, y, z - vw.radius }
      else
        result.treadPosition = { x, y, z + vw.radius }
      end
    end
  end

  return result
end

---Gets features of a crawler track
---@param crawler table The crawler data
---@param positions table Current positions for reference
---@return table Features features with position, sidewallPosition, treadPosition
function CabCinematicVehicleAnalyzer:getCrawlerWheelFeatures(crawler, positions)
  local x, y, z = localToLocal(crawler.linkNode, self.vehicle.rootNode, getTranslation(crawler.linkNode))

  local result = {
    position = { x, y, z },
    sidewallPosition = { x, y, z },
    treadPosition = { x, y, z },
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
      result.treadPosition = { avgX, avgY, avgZ }

      local isFront = avgZ > positions.root[3]
      local largestZDist = math.abs(positions.root[3] - largestZWheel[3])
      local smallestZDist = math.abs(positions.root[3] - smallestZWheel[3])

      if largestZDist <= smallestZDist then
        result.treadPosition[3] = largestZWheel[3] + (isFront and -largestZWheel.radius or largestZWheel.radius)
      else
        result.treadPosition[3] = smallestZWheel[3] + (isFront and -smallestZWheel.radius or smallestZWheel.radius)
      end
    end
  end

  return result
end

---Gets the Y position of character's feet when seated
---@param positions table Current positions for reference
---@return number Y position
function CabCinematicVehicleAnalyzer:getCabCharacterFootY(positions)
  local characterTargets = self.vehicle.spec_enterable.defaultCharacterTargets;

  if characterTargets ~= nil then
    local lowestFootY = math.huge

    for _, foot in pairs({ characterTargets.leftFoot, characterTargets.rightFoot }) do
      if foot ~= nil then
        local _, footY, _ = localToLocal(foot.targetNode, self.vehicle.rootNode, 0, 0, 0)
        if footY ~= nil and footY < lowestFootY then
          lowestFootY = footY
        end
      end
    end

    if lowestFootY ~= math.huge then
      return lowestFootY
    end
  end

  return positions.camera[2] - 1.5
end

---Performs raycasts to determine cab bounding box
---@param positions table Current positions for reference
---@return table Raycast results with positions and debug hits
function CabCinematicVehicleAnalyzer:raycastCabBoundingBox(positions)
  local backHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    positions.camera[1], positions.camera[2], positions.camera[3] - 2.0,
    positions.camera[1], positions.camera[2], positions.camera[3],
    false
  )

  local frontHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    positions.camera[1], positions.camera[2], positions.steeringWheel[3] + 2.0,
    positions.camera[1], positions.camera[2], positions.steeringWheel[3],
    true
  )

  local leftHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    positions.camera[1] + 2.0, positions.camera[2], positions.camera[3],
    positions.camera[1], positions.camera[2], positions.camera[3],
    false
  )

  local rightHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    positions.camera[1] - 2.0, positions.camera[2], positions.steeringWheel[3],
    positions.camera[1], positions.camera[2], positions.steeringWheel[3],
    false
  )

  local topHitResult = CabCinematicUtil.raycastVehicle(
    self.vehicle,
    positions.camera[1], positions.camera[2] + 2.0, positions.camera[3],
    positions.camera[1], positions.camera[2], positions.camera[3],
    false
  )

  local back = backHitResult.best or { positions.camera[1], positions.camera[2], positions.camera[3] - 0.5 }
  local front = frontHitResult.best or { positions.camera[1], positions.camera[2], positions.steeringWheel[3] + 0.5 }
  local left = leftHitResult.best or { positions.camera[1] + 0.5, positions.camera[2], positions.camera[3] }
  local right = rightHitResult.best or { positions.camera[1] - 0.5, positions.camera[2], positions.camera[3] }
  local top = topHitResult.best or { positions.camera[1], positions.camera[2] + 0.5, positions.camera[3] }
  local bottom = { positions.camera[1], positions.camera[2] - 1.5, positions.camera[3] }

  return {
    back = back,
    front = front,
    left = left,
    right = right,
    top = top,
    bottom = bottom,
    debugHits = {
      backHitResult = backHitResult,
      frontHitResult = frontHitResult,
      leftHitResult = leftHitResult,
      rightHitResult = rightHitResult,
      topHitResult = topHitResult,
    }
  }
end

---Calculates the cab bounding box
---@param positions table Current positions for reference
---@return table Bounding box with positions and debug information
function CabCinematicVehicleAnalyzer:getCabBoundingBox(positions)
  local raycastResult = self:raycastCabBoundingBox(positions)
  local characterFootY = self:getCabCharacterFootY(positions)
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

      debugPositions.focusBack    = { fx, fy, focusBackZ }
      debugPositions.focusFront   = { fx, fy, focusFrontZ }
      debugPositions.focusLeft    = { focusLeftX, fy, fz }
      debugPositions.focusRight   = { focusRightX, fy, fz }
      debugPositions.focusTop     = { fx, focusTopY, fz }
      debugPositions.focusBottom  = { fx, focusBottomY, fz }
    end
  end

  raycastResult.bottom[2] = math.max(raycastResult.bottom[2], characterFootY)

  local center = {
    (raycastResult.left[1] + raycastResult.right[1]) / 2,
    (raycastResult.bottom[2] + raycastResult.top[2]) / 2,
    (raycastResult.back[3] + raycastResult.front[3]) / 2,
  }

  return {
    debugHits = raycastResult.debugHits,
    debugPositions = debugPositions,
    positions = {
      back = raycastResult.back,
      front = raycastResult.front,
      left = raycastResult.left,
      right = raycastResult.right,
      top = raycastResult.top,
      bottom = raycastResult.bottom,
      center = center,
    },
  }
end

---Gets the count of crawler tracks on the vehicle
---@return number Number of crawlers
function CabCinematicVehicleAnalyzer:getCrawlersCount()
  return self.vehicle.spec_crawlers ~= nil and self.vehicle.spec_crawlers.crawlers ~= nil and #self.vehicle.spec_crawlers.crawlers or 0
end

---Gets the count of pneumatic wheels on the vehicle
---@return number Number of pneumatic wheels
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

---Analyzes all wheel features (pneumatic and crawler)
---@param positions table Current positions for reference
---@return table Features features with flags and positions
function CabCinematicVehicleAnalyzer:getWheelsFeatures(positions)
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
      wheelLeftFrontTread = nil,
      wheelRightFrontTread = nil,
      wheelLeftBackTread = nil,
      wheelRightBackTread = nil,
      wheelLeftFrontSidewall = nil,
      wheelRightFrontSidewall = nil,
      wheelLeftBackSidewall = nil,
      wheelRightBackSidewall = nil,
    },
  }

  if crawlersCount > 0 then
    for _, crawler in pairs(self.vehicle.spec_crawlers.crawlers) do
      local crawlerFeatures = self:getCrawlerWheelFeatures(crawler, positions)
      if crawlerFeatures ~= nil then
        if crawler.isLeft then
          if crawlerFeatures.position[3] > positions.root[3] then
            result.positions.wheelLeftFront = crawlerFeatures.position
            result.positions.wheelLeftFrontTread = crawlerFeatures.treadPosition
            result.positions.wheelLeftFrontSidewall = crawlerFeatures.sidewallPosition
          else
            result.positions.wheelLeftBack = crawlerFeatures.position
            result.positions.wheelLeftBackTread = crawlerFeatures.treadPosition
            result.positions.wheelLeftBackSidewall = crawlerFeatures.sidewallPosition
          end
        else
          if crawlerFeatures.position[3] > positions.root[3] then
            result.positions.wheelRightFront = crawlerFeatures.position
            result.positions.wheelRightFrontTread = crawlerFeatures.treadPosition
            result.positions.wheelRightFrontSidewall = crawlerFeatures.sidewallPosition
          else
            result.positions.wheelRightBack = crawlerFeatures.position
            result.positions.wheelRightBackTread = crawlerFeatures.treadPosition
            result.positions.wheelRightBackSidewall = crawlerFeatures.sidewallPosition
          end
        end
      end
    end
  end

  if wheelsCount > 0 then
    for _, wheel in pairs(self.vehicle.spec_wheels.wheels) do
      local wheelFeatures = self:getPneumaticWheelFeatures(wheel, positions)
      if wheelFeatures ~= nil then
        if wheelFeatures.position[1] > positions.root[1] then
          if wheelFeatures.position[3] > positions.root[3] then
            result.positions.wheelRightFront = wheelFeatures.position
            result.positions.wheelRightFrontTread = wheelFeatures.treadPosition
            result.positions.wheelRightFrontSidewall = wheelFeatures.sidewallPosition
          else
            result.positions.wheelRightBack = wheelFeatures.position
            result.positions.wheelRightBackTread = wheelFeatures.treadPosition
            result.positions.wheelRightBackSidewall = wheelFeatures.sidewallPosition
          end
        else
          if wheelFeatures.position[3] > positions.root[3] then
            result.positions.wheelLeftFront = wheelFeatures.position
            result.positions.wheelLeftFrontTread = wheelFeatures.treadPosition
            result.positions.wheelLeftFrontSidewall = wheelFeatures.sidewallPosition
          else
            result.positions.wheelLeftBack = wheelFeatures.position
            result.positions.wheelLeftBackTread = wheelFeatures.treadPosition
            result.positions.wheelLeftBackSidewall = wheelFeatures.sidewallPosition
          end
        end
      end
    end
  end

  return result
end

---Analyzes the vehicle to determine the enter position and related flags
---@param positions table Current positions for reference
---@return table Features features with positions and flags
function CabCinematicVehicleAnalyzer:getVehicleEnterFeatures(positions)
  local playerEyeHeight = CabCinematicUtil.getPlayerEyesightHeight()
  local wex, wey, wez = getWorldTranslation(self.vehicle:getExitNode())
  local wty = getTerrainHeightAtWorldPos(g_terrainNode, wex, wey, wez)
  local _, wpy, _ = worldToLocal(self.vehicle.rootNode, wex, wty, wez)
  local enter = { positions.exit[1], wpy + playerEyeHeight, positions.exit[3] }

  local middleZ = (positions.steeringWheel[3] + positions.camera[3]) / 2
  local isEntryFromCabFront = enter[3] >= positions.front[3] and math.abs(positions.enterWheel[1]) > math.abs(enter[1])
  local isEntryFromCabSide = not isEntryFromCabFront and math.abs(positions.enterWheel[1]) < math.abs(enter[1])
  local isEntryFromCabRear = not isEntryFromCabFront and not isEntryFromCabSide
  local isEntryFromCabSideLeft = isEntryFromCabSide and MathUtil.round(enter[1] - positions.center[1], 2) > 0.25
  local isEntryFromCabSideFront = isEntryFromCabSide and MathUtil.round(enter[3] - middleZ, 2) >= 0.5
  local isEntryFromCabSideRear = isEntryFromCabSide and MathUtil.round(enter[3] - middleZ, 2) <= -0.5
  local isEntryFromCabSideCenter = isEntryFromCabSide and not isEntryFromCabSideFront and not isEntryFromCabSideRear

  if CabCinematicUtil.isVehicleTractor(self.vehicle) and isEntryFromCabSide then
    if isEntryFromCabSideLeft then
      if positions.wheelLeftBack ~= nil and positions.wheelLeftFront ~= nil then
        local centerEnterZ = (positions.wheelLeftFront[3] + positions.wheelLeftBack[3]) / 2
        if CabCinematicUtil.isNear(enter[3], centerEnterZ, 0.15) then
          enter[3] = centerEnterZ
        end
      end
    else
      if positions.wheelRightBack ~= nil and positions.wheelRightFront ~= nil then
        local centerEnterZ = (positions.wheelRightFront[3] + positions.wheelRightBack[3]) / 2
        if CabCinematicUtil.isNear(enter[3], centerEnterZ, 0.15) then
          enter[3] = centerEnterZ
        end
      end
    end
  end

  return {
    positions = {
      enter = enter,
    },
    flags = {
      isEntryFromCabFront = isEntryFromCabFront,
      isEntryFromCabSide = isEntryFromCabSide,
      isEntryFromCabRear = isEntryFromCabRear,
      isEntryFromCabSideLeft = isEntryFromCabSideLeft,
      isEntryFromCabSideFront = isEntryFromCabSideFront,
      isEntryFromCabSideRear = isEntryFromCabSideRear,
      isEntryFromCabSideCenter = isEntryFromCabSideCenter
    }
  }
end

---Finds the closest wheel to the enter position based on combined distance to exit and camera
---@param positions table Current positions for reference
---@return table Wheel position {x, y, z }
function CabCinematicVehicleAnalyzer:getCabEnterWheelPosition(positions)
  local candidates = {}

  if positions.wheelLeftFrontSidewall ~= nil and positions.wheelLeftFrontTread ~= nil then
    table.insert(candidates, {
      positions.wheelLeftFrontSidewall[1],
      positions.wheelLeftFrontSidewall[2],
      positions.wheelLeftFrontTread[3],
    })
  end

  if positions.wheelRightFrontSidewall ~= nil and positions.wheelRightFrontTread ~= nil then
    table.insert(candidates, {
      positions.wheelRightFrontSidewall[1],
      positions.wheelRightFrontSidewall[2],
      positions.wheelRightFrontTread[3],
    })
  end

  if positions.wheelLeftBackSidewall ~= nil and positions.wheelLeftBackTread ~= nil then
    table.insert(candidates, {
      positions.wheelLeftBackSidewall[1],
      positions.wheelLeftBackSidewall[2],
      positions.wheelLeftBackTread[3],
    })
  end

  if positions.wheelRightBackSidewall ~= nil and positions.wheelRightBackTread ~= nil then
    table.insert(candidates, {
      positions.wheelRightBackSidewall[1],
      positions.wheelRightBackSidewall[2],
      positions.wheelRightBackTread[3],
    })
  end

  return CabCinematicUtil.getClosestPositionToTwoRefs(candidates, positions.exit, positions.camera)
end

---Calculates the standup position inside the cab
---@param positions table Current positions for reference
---@param flags table Current flags for reference
---@return table Standup position {x, y, z}
function CabCinematicVehicleAnalyzer:getCabStandupPosition(positions, flags)
  local leftStandupX = math.min(positions.camera[1] + 0.2, positions.left[1])
  local rightStandupX = math.max(positions.camera[1] - 0.2, positions.right[1])
  local standupX = flags.isEntryFromCabSideLeft and leftStandupX or rightStandupX
  local standupY = positions.camera[2] + 0.05
  local standupZ = (positions.steeringWheel[3] + positions.camera[3]) / 2
  return { standupX, standupY, standupZ }
end

---Calculates the door positions on left and right sides
---@param positions table Current positions for reference
---@param flags table Current flags for reference
---@return table Door positions {leftDoor, rightDoor}
function CabCinematicVehicleAnalyzer:getCabDoors(positions, flags)
  local leftDoor = { positions.left[1], positions.camera[2], positions.standup[3] }
  local rightDoor = { positions.right[1], positions.camera[2], positions.standup[3] }

  if flags.isEntryFromCabSideFront then
    if not CabCinematicUtil.isNear(positions.front[3], positions.steeringWheel[3], 0.3) then
      leftDoor[3] = positions.steeringWheel[3]
      rightDoor[3] = positions.steeringWheel[3]
    end

    if CabCinematicUtil.isVehicleTractor(self.vehicle) then
      local refZ = positions.enterWheel[3]
      if refZ > positions.front[3] then
        refZ = positions.steeringWheel[3]
      end

      leftDoor[3] = math.max((positions.center[3] + positions.front[3]) / 2, refZ)
      rightDoor[3] = math.max((positions.center[3] + positions.front[3]) / 2, refZ)
    end
  elseif flags.isEntryFromCabSideRear then
    if CabCinematicUtil.isNear(positions.standup[3], positions.center[3], 0.15) then
      leftDoor[3] = positions.camera[3]
      rightDoor[3] = positions.camera[3]
    end

    leftDoor[3] = CabCinematicUtil.clamp(leftDoor[3], positions.back[3] + 0.35, positions.back[3] + 0.55)
    rightDoor[3] = CabCinematicUtil.clamp(rightDoor[3], positions.back[3] + 0.35, positions.back[3] + 0.55)
  end

  return {
    leftDoor = leftDoor,
    rightDoor = rightDoor
  }
end

---Analyzes the vehicle and returns all positions and flags
---@return table Analysis result with positions, flags, and debug information
function CabCinematicVehicleAnalyzer:analyze()
  local flags = {}
  local debugPositions = {}
  local debugHits = {}

  -- Base positions
  local positions = {
    root = { localToLocal(getParent(self.vehicle.rootNode), self.vehicle.rootNode, getTranslation(self.vehicle.rootNode)) },
    camera = self:getVehicleIndoorCameraPosition(),
    steeringWheel = self:getVehicleSteeringWheelPosition(),
    exit = self:getVehicleExitPosition()
  }

  -- Wheel features
  local wheelsFeatures = self:getWheelsFeatures(positions)
  CabCinematicUtil.merge(positions, wheelsFeatures.positions)
  CabCinematicUtil.merge(flags, wheelsFeatures.flags)

  -- Seat and enter positions
  positions.seat = { positions.camera[1], positions.camera[2], positions.camera[3] }
  positions.enterWheel = self:getCabEnterWheelPosition(positions)

  -- Cab bounding box
  local cabBoundingBox = self:getCabBoundingBox(positions)
  CabCinematicUtil.merge(positions, cabBoundingBox.positions)
  CabCinematicUtil.merge(debugPositions, cabBoundingBox.debugPositions)
  CabCinematicUtil.merge(debugHits, cabBoundingBox.debugHits)

  -- Enter features
  local enterFeatures = self:getVehicleEnterFeatures(positions)
  CabCinematicUtil.merge(positions, enterFeatures.positions)
  CabCinematicUtil.merge(flags, enterFeatures.flags)

  -- Standup position
  positions.standup = self:getCabStandupPosition(positions, flags)

  -- Door positions
  local doors = self:getCabDoors(positions, flags)
  CabCinematicUtil.merge(positions, doors)

  return {
    positions = positions,
    flags = flags,
    debugPositions = debugPositions,
    debugHits = debugHits,
  }
end
