CabCinematicUtil = {}

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

function CabCinematicUtil.merge(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
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
    if position.hits ~= nil then
      for index, hit in ipairs(position.hits) do
        if (hit[1] == position.best[1] and hit[2] == position.best[2] and hit[3] == position.best[3]) then
          local px, py, pz = localToWorld(node, unpack(position.best))
          local text = string.format("%s best (%.2f, %.2f, %.2f) Dist: %.2f", name, position.best[1], position.best[2],
            position.best[3], position.best[4])
          DebugUtil.drawDebugGizmoAtWorldPos(px, py + 0.1, pz, 1, 0, 0, 0, 0, 1, text)
        else
          local px, py, pz = localToWorld(node, unpack(hit))
          local text = string.format("%s %d (%.2f, %.2f, %.2f) Dist: %.2f", name, index, hit[1], hit[2], hit[3], hit[4])
          DebugUtil.drawDebugGizmoAtWorldPos(px, py + 0.1, pz, 1, 0, 0, 0, 0, 1, text)
        end
      end
    else
      local px, py, pz = localToWorld(node, unpack(position))
      local text = string.format("%s (%.2f, %.2f, %.2f)", name, position[1], position[2], position[3])
      DebugUtil.drawDebugGizmoAtWorldPos(px, py, pz, 0, 1, 0, 0, 1, 0, text)
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

function CabCinematicUtil.getVehicleCabPositions(vehicle, cameraPosition, steeringWheelPosition)
  local wfx, wfy, wfz, radius = getShapeWorldBoundingSphere(vehicle:getVehicleInteriorCamera().shadowFocusBoxNode)
  local fx, fy, fz = worldToLocal(vehicle.rootNode, wfx, wfy, wfz)

  local focusBackZ = fz - (radius / 2)
  local focusFrontZ = fz + (radius / 2)
  local focusLeftX = fx + (radius / 2)

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
      { cameraPosition[1], cameraPosition[2], math.max(backHitResult.best[3], focusBackZ) } or
      { cameraPosition[1], cameraPosition[2], focusBackZ }

  local adjustedFront = frontHitResult.best and
      { steeringWheelPosition[1], cameraPosition[2], math.min(frontHitResult.best[3], focusFrontZ) } or
      { steeringWheelPosition[1], cameraPosition[2], focusFrontZ }

  local adjustedLeft = leftHitResult.best and
      { math.min(leftHitResult.best[1], focusLeftX), cameraPosition[2], cameraPosition[3] } or
      { focusLeftX, cameraPosition[2], cameraPosition[3] }

  local adjustedRight = { adjustedLeft[1] - 2 * (adjustedLeft[1] - adjustedFront[1]), adjustedLeft[2], adjustedLeft[3] }

  local center = { cameraPosition[1], cameraPosition[2], (adjustedBack[3] + adjustedFront[3]) / 2 }

  local seatingZ = (steeringWheelPosition[3] + cameraPosition[3]) / 2

  local isExitNodeLeftSide = MathUtil.round(exit[1] - center[1], 2) > 0.25
  local isExitNodeFrontSide = MathUtil.round(exit[3] - seatingZ, 2) >= 0.5
  local isExitNodeBackSide = MathUtil.round(exit[3] - seatingZ, 2) <= -0.5

  local seatingX = isExitNodeLeftSide and center[1] + 0.2 or center[1] - 0.2
  local seating = { seatingX, center[2], seatingZ }

  local leftDoor = { adjustedLeft[1], center[2], seating[3] }
  local rightDoor = { adjustedRight[1], center[2], seating[3] }

  if isExitNodeFrontSide then
    if not isNear(adjustedFront[3], steeringWheelPosition[3], 0.3) then
      leftDoor[3] = steeringWheelPosition[3]
      rightDoor[3] = steeringWheelPosition[3]
    end
  elseif isExitNodeBackSide then
    if isNear(seatingZ, center[3], 0.15) then
      leftDoor[3] = cameraPosition[3]
      rightDoor[3] = cameraPosition[3]
    end

    leftDoor[3] = clamp(leftDoor[3], adjustedBack[3] + 0.35, adjustedBack[3] + 0.55)
    rightDoor[3] = clamp(rightDoor[3], adjustedBack[3] + 0.35, adjustedBack[3] + 0.55)
  end

  return {
    exit = exit,
    center = center,
    front = adjustedFront,
    left = adjustedLeft,
    right = adjustedRight,
    back = adjustedBack,
    seating = seating,
    -- backHitResult = backHitResult,
    -- leftHitResult = leftHitResult,
    -- frontHitResult = frontHitResult,
    -- focusBack = { fx, fy, focusBackZ },
    -- focusFront = { fx, fy, focusFrontZ },
    -- focusLeft = { focusLeftX, fy, fz },

    leftDoor = leftDoor,
    rightDoor = rightDoor
  }
end
