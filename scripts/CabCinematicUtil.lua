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

function CabCinematicUtil.getVehicleInteriorCameraPosition(vehicle)
  local camera = vehicle:getVehicleInteriorCamera()
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

function CabCinematicUtil.getVehicleFeatures(vehicle, cameraPosition, steeringWheelPosition)
  local _, lfy, _ = localToLocal(vehicle.spec_enterable.defaultCharacterTargets.leftFoot.targetNode, vehicle.rootNode, 0,
    0,
    0)
  local wfx, wfy, wfz, radius = getShapeWorldBoundingSphere(vehicle:getVehicleInteriorCamera().shadowFocusBoxNode)
  local fx, fy, fz = worldToLocal(vehicle.rootNode, wfx, wfy, wfz)

  local focusBackZ = fz - (radius / 2)
  local focusFrontZ = fz + (radius / 2)
  local focusLeftX = fx + (radius / 2)
  local focusTopY = fy + (radius / 2)
  local centerY = (focusTopY + lfy) / 2

  local exit = { getTranslation(vehicle:getExitNode()) }

  local backHitResult = CabCinematicUtil.raycastVehicleFarthest(
    vehicle,
    cameraPosition[1], cameraPosition[2], cameraPosition[3] - 2.0,
    cameraPosition[1], cameraPosition[2], cameraPosition[3]
  )
  local frontHitResult = CabCinematicUtil.raycastVehicleClosest(
    vehicle,
    steeringWheelPosition[1], cameraPosition[2], steeringWheelPosition[3] + 2.0,
    steeringWheelPosition[1], cameraPosition[2], steeringWheelPosition[3]
  )
  local leftHitResult = CabCinematicUtil.raycastVehicleFarthest(
    vehicle,
    cameraPosition[1] + 2.0, cameraPosition[2], cameraPosition[3],
    cameraPosition[1], cameraPosition[2], cameraPosition[3]
  )

  local adjustedBack = backHitResult.best and
      { cameraPosition[1], centerY, math.max(backHitResult.best[3], focusBackZ) } or
      { cameraPosition[1], centerY, focusBackZ }

  local adjustedFront = frontHitResult.best and
      { steeringWheelPosition[1], centerY, math.min(frontHitResult.best[3], focusFrontZ) } or
      { steeringWheelPosition[1], centerY, focusFrontZ }

  local adjustedLeft = leftHitResult.best and
      { math.min(leftHitResult.best[1], focusLeftX), centerY, cameraPosition[3] } or
      { focusLeftX, centerY, cameraPosition[3] }

  local adjustedRight = { adjustedLeft[1] - 2 * (adjustedLeft[1] - adjustedFront[1]), adjustedLeft[2], adjustedLeft[3] }

  local center = { cameraPosition[1], centerY, (adjustedBack[3] + adjustedFront[3]) / 2 }
  local bottom = { center[1], lfy, center[3] }
  local top = { center[1], focusTopY, center[3] }

  local standupZ = (steeringWheelPosition[3] + cameraPosition[3]) / 2

  local isExitNodeLeftSide = MathUtil.round(exit[1] - center[1], 2) > 0.25
  local isExitNodeFrontSide = MathUtil.round(exit[3] - standupZ, 2) >= 0.5
  local isExitNodeBackSide = MathUtil.round(exit[3] - standupZ, 2) <= -0.5

  local standupX = isExitNodeLeftSide and center[1] + 0.2 or center[1] - 0.2
  local standup = { standupX, cameraPosition[2], standupZ }
  local seat = { cameraPosition[1], cameraPosition[2], cameraPosition[3] }

  local leftDoor = { adjustedLeft[1], cameraPosition[2], standup[3] }
  local rightDoor = { adjustedRight[1], cameraPosition[2], standup[3] }

  if isExitNodeFrontSide then
    if not isNear(adjustedFront[3], steeringWheelPosition[3], 0.3) then
      leftDoor[3] = steeringWheelPosition[3]
      rightDoor[3] = steeringWheelPosition[3]
    end
  elseif isExitNodeBackSide then
    if isNear(standupZ, center[3], 0.15) then
      leftDoor[3] = cameraPosition[3]
      rightDoor[3] = cameraPosition[3]
    end

    leftDoor[3] = clamp(leftDoor[3], adjustedBack[3] + 0.35, adjustedBack[3] + 0.55)
    rightDoor[3] = clamp(rightDoor[3], adjustedBack[3] + 0.35, adjustedBack[3] + 0.55)
  end

  local wheelPositions = {}
  for _, wheel in pairs(vehicle.spec_wheels.wheels) do
    table.insert(wheelPositions, CabCinematicUtil.getWheelExternalPosition(wheel))
  end

  local exitWheel = nil
  local minDist = math.huge
  for _, wheelPos in ipairs(wheelPositions) do
    local dist = MathUtil.vector2Length(exit[1] - wheelPos[1], exit[3] - wheelPos[3])
    if dist < minDist then
      minDist = dist
      exitWheel = wheelPos
    end
  end

  return {
    isExitNodeLeftSide = isExitNodeLeftSide,
    isExitNodeFrontSide = isExitNodeFrontSide,
    isExitNodeBackSide = isExitNodeBackSide,
    isExitNodeCenter = not isExitNodeFrontSide and not isExitNodeBackSide,
    positions = {
      camera        = cameraPosition,
      steeringWheel = steeringWheelPosition,
      exit          = exit,
      standup       = standup,
      seat          = seat,
      exitWheel     = exitWheel,
      leftDoor      = leftDoor,
      rightDoor     = rightDoor
    },
    debugPositions = {
      center     = center,
      front      = adjustedFront,
      left       = adjustedLeft,
      right      = adjustedRight,
      back       = adjustedBack,
      bottom     = bottom,
      top        = top,
      focusBack  = { fx, fy, focusBackZ },
      focusFront = { fx, fy, focusFrontZ },
      focusLeft  = { focusLeftX, fy, fz },
    },
    debugHits = {
      backHitResult  = backHitResult,
      frontHitResult = frontHitResult,
      leftHitResult  = leftHitResult,
    }
  }
end

function CabCinematicUtil.getVehiclePathPositions(vehicle, cabFeatures)
  local category = vehicle:getVehicleCategory()
  Log:info("CabCinematicUtil.getVehiclePathPositions category: %s", tostring(category))

  local start = {
    cabFeatures.positions.exit[1],
    cabFeatures.positions.exit[2] + 1.80,
    cabFeatures.positions.exit[3]
  }

  local pathStart = {
    start
  }

  local pathEnd = {
    cabFeatures.positions.leftDoor,
    cabFeatures.positions.standup,
    cabFeatures.positions.seat,
  }

  if category == 'harvesters' then
    if cabFeatures.isExitNodeCenter then
      local ladderBottom = {
        math.min(start[1], cabFeatures.positions.exitWheel[1] + 1),
        start[2],
        start[3]
      };

      local ladderTop = {
        ladderBottom[1] - 1.0,
        cabFeatures.positions.leftDoor[2],
        start[3]
      };

      return CabCinematicUtil.concat(
        pathStart,
        {
          ladderBottom,
          ladderTop,
        },
        pathEnd
      )
    end

    return {}
  end

  if category == 'forageharvesters' then
    if cabFeatures.isExitNodeBackSide then
      local leftDoorCross = {
        cabFeatures.positions.leftDoor[1] + 0.35,
        cabFeatures.positions.leftDoor[2],
        cabFeatures.positions.leftDoor[3]
      };

      local ladderBottom = {
        leftDoorCross[1],
        start[2] + 0.15,
        start[3] + 0.25
      };

      local ladderTop = {
        leftDoorCross[1],
        leftDoorCross[2],
        ladderBottom[3] + 1.0
      };

      return CabCinematicUtil.concat(
        pathStart,
        {
          ladderBottom,
          ladderTop,
          leftDoorCross,
        },
        pathEnd
      )
    end

    return {}
  end

  if category == 'beetharvesters' then
    if cabFeatures.isExitNodeBackSide then
      local leftDoorCross = {
        cabFeatures.positions.leftDoor[1] + 0.35,
        cabFeatures.positions.leftDoor[2],
        cabFeatures.positions.leftDoor[3]
      };

      local ladderTop = {
        leftDoorCross[1] + 0.2,
        leftDoorCross[2],
        start[3]
      };

      local ladderBottom = {
        ladderTop[1] + 1.0,
        start[2],
        ladderTop[3]
      };

      return CabCinematicUtil.concat(
        pathStart,
        {
          ladderBottom,
          ladderTop,
          leftDoorCross,
        },
        pathEnd
      )
    end
  end

  if category == 'tractorss' then
    if isNear(cabFeatures.positions.exitWheel[1], cabFeatures.positions.exit[1], 0.1) then
      local leftDoorCross = {
        (cabFeatures.positions.center[1] + cabFeatures.positions.leftDoor[1]),
        cabFeatures.positions.leftDoor[2],
        cabFeatures.positions.exit[3]
      };

      return CabCinematicUtil.concat(
        pathStart,
        {
          leftDoorCross
        },
        pathEnd
      )
    end
    return CabCinematicUtil.concat(
      pathStart,
      pathEnd
    )
  end

  if category == 'tractorsm' then
    return CabCinematicUtil.concat(
      pathStart,
      pathEnd
    )
  end

  if category == 'tractorsl' then
    return CabCinematicUtil.concat(
      pathStart,
      pathEnd
    )
  end

  return {}
end
