CabCinematicUtil = {}

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

local function clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

local function isNear(valueA, valueB, threshold)
  return math.abs(valueA - valueB) <= threshold
end

function CabCinematicUtil.getWheelExternalPosition(wheel)
  local rootNode = wheel.vehicle.rootNode

  local extX = wheel.isLeft and -math.huge or math.huge
  local extY, extZ = 0, 0

  local function getHalfWidth(vw)
    local w = (vw.width) or (wheel.physics and (wheel.physics.width or wheel.physics.wheelShapeWidth)) or 0
    return 0.5 * w
  end

  local function testNode(node, halfW)
    if node == nil or node == 0 or halfW == 0 then
      return
    end

    local x1, y1, z1 = localToLocal(node, rootNode, halfW, 0, 0)
    local x2, y2, z2 = localToLocal(node, rootNode, -halfW, 0, 0)

    if wheel.isLeft then
      if x1 > extX then extX, extY, extZ = x1, y1, z1 end
      if x2 > extX then extX, extY, extZ = x2, y2, z2 end
    else
      if x1 < extX then extX, extY, extZ = x1, y1, z1 end
      if x2 < extX then extX, extY, extZ = x2, y2, z2 end
    end
  end

  if wheel.visualWheels ~= nil and #wheel.visualWheels > 0 then
    for _, vw in ipairs(wheel.visualWheels) do
      if vw.node ~= nil and vw.node ~= 0 then
        testNode(vw.node, getHalfWidth(vw))
      end
    end
  else
    local node = wheel.driveNode or wheel.node
    if node ~= nil and node ~= 0 then
      testNode(node, getHalfWidth(wheel))
    end
  end

  return { extX, extY, extZ }
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

function CabCinematicUtil.getCabEnterPosition(vehicle, positions)
  local playerEyeHeight = CabCinematicUtil.getPlayerEyesightHeight();
  local wex, wey, wez = getWorldTranslation(vehicle:getExitNode())
  local wty = getTerrainHeightAtWorldPos(g_terrainNode, wex, wey, wez)
  local _, wpy, _ = worldToLocal(vehicle.rootNode, wex, wty, wez)
  return { positions.exit[1], wpy + playerEyeHeight, positions.exit[3] }
end

function CabCinematicUtil.getCabExitWheelPosition(vehicle, positions)
  local wheelPositions = {}
  for _, wheel in pairs(vehicle.spec_wheels.wheels) do
    table.insert(wheelPositions, CabCinematicUtil.getWheelExternalPosition(wheel))
  end

  local exitWheelPosition = nil
  local minDist = math.huge
  for _, wheelPos in ipairs(wheelPositions) do
    local dist = MathUtil.vector2Length(positions.exit[1] - wheelPos[1], positions.exit[3] - wheelPos[3])
    if dist < minDist then
      minDist = dist
      exitWheelPosition = wheelPos
    end
  end

  return exitWheelPosition or wheelPositions[1]
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
  local r = {
    flags = {},
    debugPositions = {},
    debugHits = {},
    positions = {
      camera = CabCinematicUtil.getVehicleIndoorCameraPosition(vehicle),
      steeringWheel = CabCinematicUtil.getVehicleSteeringWheelPosition(vehicle),
      exit = { getTranslation(vehicle:getExitNode()) }
    }
  }

  r.positions.enter = CabCinematicUtil.getCabEnterPosition(vehicle, r.positions)
  r.positions.exitWheel = CabCinematicUtil.getCabExitWheelPosition(vehicle, r.positions)
  r.positions.seat = { r.positions.camera[1], r.positions.camera[2], r.positions.camera[3] }

  local cabBoundingBox = CabCinematicUtil.getCabBoundingBox(vehicle, r.positions)
  r.positions = CabCinematicUtil.merge(r.positions, cabBoundingBox.positions)
  r.debugPositions = CabCinematicUtil.merge(r.debugPositions, cabBoundingBox.debugPositions)
  r.debugHits = CabCinematicUtil.merge(r.debugHits, cabBoundingBox.debugHits)

  local middleZ = (r.positions.steeringWheel[3] + r.positions.camera[3]) / 2
  r.flags.isEnterLeftSide = MathUtil.round(r.positions.enter[1] - cabBoundingBox.positions.center[1], 2) > 0.25
  r.flags.isEnterFrontSide = MathUtil.round(r.positions.enter[3] - middleZ, 2) >= 0.5
  r.flags.isEnterBackSide = MathUtil.round(r.positions.enter[3] - middleZ, 2) <= -0.5
  r.flags.isEnterCenter = not r.flags.isEnterFrontSide and not r.flags.isEnterBackSide

  r.positions.standup = CabCinematicUtil.getCabStandupPosition(vehicle, r.positions, r.flags)
  local doors = CabCinematicUtil.getCabDoors(vehicle, r.positions, r.flags)
  r.positions = CabCinematicUtil.merge(r.positions, doors)

  return r;
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
