CabCinematicUtil = {}

local function clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

local function isNear(valueA, valueB, threshold)
  return math.abs(valueA - valueB) <= threshold
end

function CabCinematicUtil.printParentNodeHierarchy(node, prefix)
  prefix = prefix or ""
  local parent = getParent(node)
  if parent ~= 0 then
    Log:info("%s%s", prefix, getName(parent))
    CabCinematicUtil.printParentNodeHierarchy(parent, prefix .. "  ")
  end
end

function CabCinematicUtil.printTableRecursively(inputTable, inputIndent, depth, maxDepth, excludeKeys)
  inputIndent = inputIndent or "  "
  depth = depth or 0
  maxDepth = maxDepth or 3

  if depth > maxDepth then
    return
  end

  local debugString = ""
  for i, j in pairs(inputTable) do
    local skip = false

    if excludeKeys ~= nil then
      for _, key in ipairs(excludeKeys) do
        if i == key then
          skip = true
          break
        end
      end
    end

    if not skip then
      print(inputIndent .. tostring(i) .. " :: " .. tostring(j))

      if type(j) == "table" then
        CabCinematicUtil.printTableRecursively(j, inputIndent .. "    ", depth + 1, maxDepth, excludeKeys)
      end
    end
  end

  return debugString
end

function CabCinematicUtil.drawDebugNodeRelativePositions(node, positions)
  for name, position in pairs(positions) do
    local px, py, pz = localToWorld(node, unpack(position))
    local text = string.format("%s (%.2f, %.2f, %.2f)", name, position[1], position[2], position[3])
    DebugUtil.drawDebugGizmoAtWorldPos(px, py, pz, 0, 1, 0, 0, 1, 0, text)
  end
end

function CabCinematicUtil.drawDebugNodeRelativeHitResults(node, hitResults)
  for name, hitResult in pairs(hitResults) do
    for index, hit in ipairs(hitResult.hits) do
      if (hit[1] == hitResult.best[1] and hit[2] == hitResult.best[2] and hit[3] == hitResult.best[3]) then
        local px, py, pz = localToWorld(node, unpack(hitResult.best))
        local text = string.format("%s best (%.2f, %.2f, %.2f) Dist: %.2f", name, hitResult.best[1], hitResult.best[2],
          hitResult.best[3], hitResult.best[4])
        DebugUtil.drawDebugGizmoAtWorldPos(px, py + 0.1, pz, 1, 0, 0, 0, 0, 1, text)
      else
        local px, py, pz = localToWorld(node, unpack(hit))
        local text = string.format("%s %d (%.2f, %.2f, %.2f) Dist: %.2f", name, index, hit[1], hit[2], hit[3], hit[4])
        DebugUtil.drawDebugGizmoAtWorldPos(px, py + 0.1, pz, 1, 0, 0, 0, 0, 1, text)
      end
    end
  end
end

function CabCinematicUtil.drawDebugBoundingBox(node, boundingBox)
  -- Extract min/max coordinates for each axis
  local minX = boundingBox.left[1]
  local maxX = boundingBox.right[1]
  local minY = boundingBox.bottom[2]
  local maxY = boundingBox.top[2]
  local minZ = boundingBox.back[3]
  local maxZ = boundingBox.front[3]

  -- Convert the 8 corners to world coordinates
  local x1, y1, z1 = localToWorld(node, minX, minY, maxZ) -- left-bottom-front
  local x2, y2, z2 = localToWorld(node, maxX, minY, maxZ) -- right-bottom-front
  local x3, y3, z3 = localToWorld(node, maxX, minY, minZ) -- right-bottom-back
  local x4, y4, z4 = localToWorld(node, minX, minY, minZ) -- left-bottom-back
  local x5, y5, z5 = localToWorld(node, minX, maxY, maxZ) -- left-top-front
  local x6, y6, z6 = localToWorld(node, maxX, maxY, maxZ) -- right-top-front
  local x7, y7, z7 = localToWorld(node, maxX, maxY, minZ) -- right-top-back
  local x8, y8, z8 = localToWorld(node, minX, maxY, minZ) -- left-top-back

  -- Bottom rectangle
  DebugUtil.drawDebugLine(x1, y1, z1, x2, y2, z2, 1, 1, 0)
  DebugUtil.drawDebugLine(x2, y2, z2, x3, y3, z3, 1, 1, 0)
  DebugUtil.drawDebugLine(x3, y3, z3, x4, y4, z4, 1, 1, 0)
  DebugUtil.drawDebugLine(x4, y4, z4, x1, y1, z1, 1, 1, 0)

  -- Top rectangle
  DebugUtil.drawDebugLine(x5, y5, z5, x6, y6, z6, 1, 1, 0)
  DebugUtil.drawDebugLine(x6, y6, z6, x7, y7, z7, 1, 1, 0)
  DebugUtil.drawDebugLine(x7, y7, z7, x8, y8, z8, 1, 1, 0)
  DebugUtil.drawDebugLine(x8, y8, z8, x5, y5, z5, 1, 1, 0)

  -- Vertical lines
  DebugUtil.drawDebugLine(x1, y1, z1, x5, y5, z5, 1, 1, 0)
  DebugUtil.drawDebugLine(x2, y2, z2, x6, y6, z6, 1, 1, 0)
  DebugUtil.drawDebugLine(x3, y3, z3, x7, y7, z7, 1, 1, 0)
  DebugUtil.drawDebugLine(x4, y4, z4, x8, y8, z8, 1, 1, 0)
end

function CabCinematicUtil.getNodeDistance2D(nodeA, nodeB)
  local xA, zA = getWorldTranslation(nodeA)
  local xB, zB = getWorldTranslation(nodeB)
  return MathUtil.vector2Length(xA - xB, zA - zB)
end

function CabCinematicUtil.getNodeDistance3D(nodeA, nodeB)
  local xA, yA, zA = getWorldTranslation(nodeA)
  local xB, yB, zB = getWorldTranslation(nodeB)
  return MathUtil.vector3Length(xA - xB, yA - yB, zA - zB)
end

function CabCinematicUtil.merge(t1, ...)
  local args = { ... }

  for _, t2 in ipairs(args) do
    for k, v in pairs(t2) do
      t1[k] = v
    end
  end

  return t1
end

function CabCinematicUtil.concat(t1, ...)
  local args = { ... }

  for _, t2 in ipairs(args) do
    for _, v in ipairs(t2) do
      table.insert(t1, v)
    end
  end

  return t1
end

function CabCinematicUtil.raycastVehicle(vehicle, startX, startY, startZ, endX, endY, endZ, closest)
  local dist = MathUtil.vector3Length(endX - startX, endY - startY, endZ - startZ)
  local sx, sy, sz = localToWorld(vehicle.rootNode, startX, startY, startZ)
  local ex, ey, ez = localToWorld(vehicle.rootNode, endX, endY, endZ)

  local dx, dy, dz = MathUtil.vector3Normalize(ex - sx, ey - sy, ez - sz)

  local result = {
    best = nil,
    hits = {},
  }

  local raycaster = {
    callback = function(self, hitObjectId, x, y, z)
      if hitObjectId == vehicle.rootNode then
        local dist = MathUtil.vector3Length(x - ex, y - ey, z - ez)
        local rx, ry, rz = worldToLocal(vehicle.rootNode, x, y, z)
        local hit = { rx, ry, rz, dist }
        table.insert(result.hits, hit)

        if result.best == nil then
          result.best = hit
        end

        if closest then
          return true;
        elseif hit[4] < result.best[4] then
          result.best = hit
        end
      end
    end
  };

  raycastAll(sx, sy, sz, dx, dy, dz, dist, "callback", raycaster, CollisionFlag.VEHICLE)

  return result;
end

function CabCinematicUtil.raycastVehicleClosest(vehicle, startX, startY, startZ, endX, endY, endZ)
  return CabCinematicUtil.raycastVehicle(vehicle, startX, startY, startZ, endX, endY, endZ, true)
end

function CabCinematicUtil.raycastVehicleFarthest(vehicle, startX, startY, startZ, endX, endY, endZ)
  return CabCinematicUtil.raycastVehicle(vehicle, startX, startY, startZ, endX, endY, endZ, false)
end

function CabCinematicUtil.isVehicleTractor(vehicle)
  local category = vehicle:getVehicleCategory()
  return category == "tractorss" or category == "tractorsm" or category == "tractorl"
end

function CabCinematicUtil.buildParentsNodes(vehicle)
  local frameRoot = createTransformGroup("cc_frameRootNode")
  link(vehicle.rootNode, frameRoot)
  setTranslation(frameRoot, 0, 0, 0)
  setRotation(frameRoot, 0, 0, 0)

  local cabRoot = createTransformGroup("cc_cabRootNode")
  local indoorCamera = vehicle:getVehicleIndoorCamera()
  if indoorCamera ~= nil then
    link(getParent(indoorCamera.cameraPositionNode), cabRoot)
  else
    link(vehicle.rootNode, cabRoot)
  end
  setTranslation(cabRoot, 0, 0, 0)
  setRotation(cabRoot, 0, 0, 0)

  return {
    cabRoot = cabRoot,
    frameRoot = frameRoot,
  }
end

function CabCinematicUtil.deleteParentNodes(nodesParents)
  if nodesParents ~= nil then
    for _, node in pairs(nodesParents) do
      unlink(node)
      delete(node)
    end
  end
end

function CabCinematicUtil.getVehicleIndoorCameraPosition(vehicle)
  local camera = vehicle:getVehicleIndoorCamera()
  if camera ~= nil then
    local dx, dy, dz = getTranslation(camera.cameraPositionNode)
    return { localToLocal(getParent(camera.cameraPositionNode), vehicle.rootNode, dx, dy, dz) }
  end

  return { 0, 0, 0 }
end

function CabCinematicUtil.getVehicleSteeringWheelPosition(vehicle)
  if vehicle.spec_drivable == nil or vehicle.spec_drivable.steeringWheel == nil then
    return { 0, 0, 0 }
  end

  local steeringWheelNode = vehicle.spec_drivable.steeringWheel.node;
  return { localToLocal(steeringWheelNode, vehicle.rootNode, getTranslation(steeringWheelNode)) }
end

function CabCinematicUtil.getVehicleExitPosition(vehicle)
  local exitNode = vehicle:getExitNode()
  return { localToLocal(getParent(exitNode), vehicle.rootNode, getTranslation(exitNode)) }
end

function CabCinematicUtil.getPneumaticWheelFeatures(vehicle, wheel, positions)
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
      local x, y, z = localToLocal(vw.node, vehicle.rootNode, getTranslation(vw.node))
      local swx1, swy1, swz1 = localToLocal(vw.node, vehicle.rootNode, halfWidth, 0, 0)
      local swx2, swy2, swz2 = localToLocal(vw.node, vehicle.rootNode, -halfWidth, 0, 0)

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

function CabCinematicUtil.getCrawlerWheelFeatures(vehicle, crawler, positions)
  local x, y, z = localToLocal(crawler.linkNode, vehicle.rootNode, getTranslation(crawler.linkNode))

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
        local x, y, z = localToLocal(node, vehicle.rootNode, getTranslation(node))
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

function CabCinematicUtil.getCabCharacterFootY(vehicle, positions)
  local leftFoot = vehicle.spec_enterable.defaultCharacterTargets.leftFoot
  if leftFoot ~= nil then
    local _, bottomY, _ = localToLocal(leftFoot.targetNode, vehicle.rootNode, 0, 0, 0)
    return bottomY
  end

  local rightFoot = vehicle.spec_enterable.defaultCharacterTargets.rightFoot
  if rightFoot ~= nil then
    local _, bottomY, _ = localToLocal(rightFoot.targetNode, vehicle.rootNode, 0, 0, 0)
    return bottomY
  end

  return positions.camera[2] - 1.5
end

function CabCinematicUtil.raycastCabBoundingBox(vehicle, positions)
  local backHitResult = CabCinematicUtil.raycastVehicleFarthest(
    vehicle,
    positions.camera[1], positions.camera[2], positions.camera[3] - 2.0,
    positions.camera[1], positions.camera[2], positions.camera[3]
  )

  local frontHitResult = CabCinematicUtil.raycastVehicleClosest(
    vehicle,
    positions.camera[1], positions.camera[2], positions.steeringWheel[3] + 2.0,
    positions.camera[1], positions.camera[2], positions.steeringWheel[3]
  )

  local leftHitResult = CabCinematicUtil.raycastVehicleFarthest(
    vehicle,
    positions.camera[1] + 2.0, positions.camera[2], positions.camera[3],
    positions.camera[1], positions.camera[2], positions.camera[3]
  )

  local rightHitResult = CabCinematicUtil.raycastVehicleFarthest(
    vehicle,
    positions.camera[1] - 2.0, positions.camera[2], positions.steeringWheel[3],
    positions.camera[1], positions.camera[2], positions.steeringWheel[3]
  )

  local topHitResult = CabCinematicUtil.raycastVehicleFarthest(
    vehicle,
    positions.camera[1], positions.camera[2] + 2.0, positions.camera[3],
    positions.camera[1], positions.camera[2], positions.camera[3]
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

function CabCinematicUtil.getCabBoundingBox(vehicle, positions)
  local raycastResult = CabCinematicUtil.raycastCabBoundingBox(vehicle, positions)
  local characterFootY = CabCinematicUtil.getCabCharacterFootY(vehicle, positions)
  local debugPositions = {}

  local shadowFocusBoxNode = vehicle:getVehicleIndoorCamera().shadowFocusBoxNode
  if shadowFocusBoxNode ~= nil then
    local wfx, wfy, wfz, radius = getShapeWorldBoundingSphere(shadowFocusBoxNode)
    local fx, fy, fz            = worldToLocal(vehicle.rootNode, wfx, wfy, wfz)

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

function CabCinematicUtil.getCrawlersCount(vehicle)
  return vehicle.spec_crawlers ~= nil and vehicle.spec_crawlers.crawlers ~= nil and
      #vehicle.spec_crawlers.crawlers or 0
end

function CabCinematicUtil.getPneumaticWheelsCount(vehicle)
  local count = 0

  if vehicle.spec_wheels ~= nil and vehicle.spec_wheels.wheels ~= nil then
    for _, wheel in pairs(vehicle.spec_wheels.wheels) do
      if wheel.visualWheels ~= nil then
        count = count + #wheel.visualWheels
      end
    end
  end

  return count
end

function CabCinematicUtil.getWheelsFeatures(vehicle, positions)
  local crawlersCount = CabCinematicUtil.getCrawlersCount(vehicle)
  local wheelsCount = CabCinematicUtil.getPneumaticWheelsCount(vehicle)

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
    for _, crawler in pairs(vehicle.spec_crawlers.crawlers) do
      local crawlerFeatures = CabCinematicUtil.getCrawlerWheelFeatures(vehicle, crawler, positions)
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
    for _, wheel in pairs(vehicle.spec_wheels.wheels) do
      local wheelFeatures = CabCinematicUtil.getPneumaticWheelFeatures(vehicle, wheel, positions)
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

function CabCinematicUtil.getCabEnterPosition(vehicle, positions)
  local playerEyeHeight = CabCinematicUtil.getPlayerEyesightHeight();
  local wex, wey, wez = getWorldTranslation(vehicle:getExitNode())
  local wty = getTerrainHeightAtWorldPos(g_terrainNode, wex, wey, wez)
  local _, wpy, _ = worldToLocal(vehicle.rootNode, wex, wty, wez)
  local enter = { positions.exit[1], wpy + playerEyeHeight, positions.exit[3] }

  if CabCinematicUtil.isVehicleTractor(vehicle) then
    if positions.wheelLeftBack ~= nil and positions.wheelLeftFront ~= nil then
      enter[3] = (positions.wheelLeftFront[3] + positions.wheelLeftBack[3]) / 2
    end
  end

  return enter
end

function CabCinematicUtil.getCabEnterWheelPosition(vehicle, positions)
  local minDist = math.huge
  local enterWheel = nil;

  if positions.wheelLeftFrontSidewall ~= nil and positions.wheelLeftFrontTread ~= nil then
    local dist = MathUtil.vector2Length(positions.exit[1] - positions.wheelLeftFrontSidewall[1],
      positions.exit[3] - positions.wheelLeftFrontTread[3])
    if dist < minDist then
      minDist = dist
      enterWheel = {
        positions.wheelLeftFrontSidewall[1],
        positions.wheelLeftFrontSidewall[2],
        positions.wheelLeftFrontTread[3]
      }
    end
  end

  if positions.wheelRightFrontSidewall ~= nil and positions.wheelRightFrontTread ~= nil then
    local dist = MathUtil.vector2Length(positions.exit[1] - positions.wheelRightFrontSidewall[1],
      positions.exit[3] - positions.wheelRightFrontTread[3])
    if dist < minDist then
      minDist = dist
      enterWheel = {
        positions.wheelRightFrontSidewall[1],
        positions.wheelRightFrontSidewall[2],
        positions.wheelRightFrontTread[3]
      }
    end
  end

  if positions.wheelLeftBackSidewall ~= nil and positions.wheelLeftBackTread ~= nil then
    local dist = MathUtil.vector2Length(positions.exit[1] - positions.wheelLeftBackSidewall[1],
      positions.exit[3] - positions.wheelLeftBackTread[3])
    if dist < minDist then
      minDist = dist
      enterWheel = {
        positions.wheelLeftBackSidewall[1],
        positions.wheelLeftBackSidewall[2],
        positions.wheelLeftBackTread[3]
      }
    end
  end

  if positions.wheelRightBackSidewall ~= nil and positions.wheelRightBackTread ~= nil then
    local dist = MathUtil.vector2Length(positions.exit[1] - positions.wheelRightBackSidewall[1],
      positions.exit[3] - positions.wheelRightBackTread[3])
    if dist < minDist then
      minDist = dist
      enterWheel = {
        positions.wheelRightBackSidewall[1],
        positions.wheelRightBackSidewall[2],
        positions.wheelRightBackTread[3]
      }
    end
  end

  return enterWheel
end

function CabCinematicUtil.getCabStandupPosition(vehicle, positions, flags)
  local standupX = flags.isEnterLeftSide and positions.center[1] + 0.2 or positions.center[1] - 0.2
  local standupY = positions.camera[2] + 0.05
  local standupZ = (positions.steeringWheel[3] + positions.camera[3]) / 2
  return { standupX, standupY, standupZ }
end

function CabCinematicUtil.getCabDoors(vehicle, positions, flags)
  local leftDoor = { positions.left[1], positions.camera[2], positions.standup[3] }
  local rightDoor = { positions.right[1], positions.camera[2], positions.standup[3] }

  if flags.isEnterFrontSide then
    if not isNear(positions.front[3], positions.steeringWheel[3], 0.3) then
      leftDoor[3] = positions.steeringWheel[3]
      rightDoor[3] = positions.steeringWheel[3]
    end

    if CabCinematicUtil.isVehicleTractor(vehicle) then
      leftDoor[3] = math.max((positions.center[3] + positions.front[3]) / 2, positions.enterWheel[3])
      rightDoor[3] = math.max((positions.center[3] + positions.front[3]) / 2, positions.enterWheel[3])
    end
  elseif flags.isEnterBackSide then
    if isNear(positions.standup[3], positions.center[3], 0.15) then
      leftDoor[3] = positions.camera[3]
      rightDoor[3] = positions.camera[3]
    end

    leftDoor[3] = clamp(leftDoor[3], positions.back[3] + 0.35, positions.back[3] + 0.55)
    rightDoor[3] = clamp(rightDoor[3], positions.back[3] + 0.35, positions.back[3] + 0.55)
  end

  return {
    leftDoor = leftDoor,
    rightDoor = rightDoor
  }
end

function CabCinematicUtil.getVehicleFeatures(vehicle)
  local flags = {}
  local debugPositions = {}
  local debugHits = {}
  local positions = {
    root = { localToLocal(getParent(vehicle.rootNode), vehicle.rootNode, getTranslation(vehicle.rootNode)) },
    camera = CabCinematicUtil.getVehicleIndoorCameraPosition(vehicle),
    steeringWheel = CabCinematicUtil.getVehicleSteeringWheelPosition(vehicle),
    exit = CabCinematicUtil.getVehicleExitPosition(vehicle)
  }

  local wheelsFeatures = CabCinematicUtil.getWheelsFeatures(vehicle, positions)
  CabCinematicUtil.merge(positions, wheelsFeatures.positions)
  CabCinematicUtil.merge(flags, wheelsFeatures.flags)

  positions.seat = { positions.camera[1], positions.camera[2], positions.camera[3] }
  positions.enterWheel = CabCinematicUtil.getCabEnterWheelPosition(vehicle, positions)
  positions.enter = CabCinematicUtil.getCabEnterPosition(vehicle, positions)

  local cabBoundingBox = CabCinematicUtil.getCabBoundingBox(vehicle, positions)
  CabCinematicUtil.merge(positions, cabBoundingBox.positions)
  CabCinematicUtil.merge(debugPositions, cabBoundingBox.debugPositions)
  CabCinematicUtil.merge(debugHits, cabBoundingBox.debugHits)

  local middleZ = (positions.steeringWheel[3] + positions.camera[3]) / 2
  flags.isEnterLeftSide = MathUtil.round(positions.enter[1] - cabBoundingBox.positions.center[1], 2) > 0.25
  flags.isEnterFrontSide = MathUtil.round(positions.enter[3] - middleZ, 2) >= 0.5
  flags.isEnterBackSide = MathUtil.round(positions.enter[3] - middleZ, 2) <= -0.5
  flags.isEnterCenter = not flags.isEnterFrontSide and not flags.isEnterBackSide

  positions.standup = CabCinematicUtil.getCabStandupPosition(vehicle, positions, flags)
  local doors = CabCinematicUtil.getCabDoors(vehicle, positions, flags)
  CabCinematicUtil.merge(positions, doors)

  local nodes = {
    root = CabCinematicNode.newFrameNode("root", vehicle):setVehicleTranslation(positions.root),
    exit = CabCinematicNode.newFrameNode("exit", vehicle):setVehicleTranslation(positions.exit),
    enterWheel = CabCinematicNode.newFrameNode("enterWheel", vehicle):setVehicleTranslation(positions.enterWheel),
    enter = CabCinematicNode.newFrameNode("enter", vehicle):setVehicleTranslation(positions.enter),
    camera = CabCinematicNode.newCabNode("camera", vehicle):setVehicleTranslation(positions.camera),
    steeringWheel = CabCinematicNode.newCabNode("steeringWheel", vehicle):setVehicleTranslation(positions.steeringWheel),
    standup = CabCinematicNode.newCabNode("standup", vehicle):setVehicleTranslation(positions.standup),
    seat = CabCinematicNode.newCabNode("seat", vehicle):setVehicleTranslation(positions.seat),
  }

  for name, pos in pairs(wheelsFeatures.positions) do
    nodes[name] = CabCinematicNode.newFrameNode(name, vehicle):setVehicleTranslation(pos)
  end

  for name, pos in pairs(doors) do
    nodes[name] = CabCinematicNode.newCabNode(name, vehicle):setVehicleTranslation(pos)
  end

  for name, pos in pairs(cabBoundingBox.positions) do
    nodes[name] = CabCinematicNode.newCabNode(name, vehicle):setVehicleTranslation(pos)
  end

  return {
    nodes = nodes,
    flags = flags,
    debugPositions = debugPositions,
    debugHits = debugHits,
  }
end

function CabCinematicUtil.deleteVehicleFeatures(vehicleFeatures)
  if vehicleFeatures ~= nil then
    for _, node in pairs(vehicleFeatures.nodes) do
      node:delete()
    end
  end
end

function CabCinematicUtil.getPlayerEyesightHeight()
  return 1.75
end

function CabCinematicUtil.syncVehicleCameraFovY(vehicleCamera)
  if (vehicleCamera ~= nil and vehicleCamera.cameraNode ~= nil) then
    local fovY = g_gameSettings:getValue(GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON)
    vehicleCamera.fovY = fovY
    vehicleCamera.fovMin = fovY
    vehicleCamera.fovMax = fovY
    setFovY(vehicleCamera.cameraNode, fovY)
  end
end

function CabCinematicUtil.isPlayerInVehicleEnterRange(player, vehicle, range)
  local vehicleFeatures = CabCinematicUtil.getVehicleFeatures(vehicle)
  local px, py, pz = localToLocal(getParent(player.rootNode), vehicle.rootNode, getTranslation(player.rootNode))
  local ex, ey, ez = unpack(vehicleFeatures.nodes.enter:getVehicleTranslation())

  if (ex > 0 and px < ex) or (ex < 0 and px > ex) then
    return false
  end

  local dist = MathUtil.vector3Length(px - ex, py - ey, pz - ez)
  return dist <= range
end
