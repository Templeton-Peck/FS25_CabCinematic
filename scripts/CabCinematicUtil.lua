CabCinematicUtil = {
  VEHICLE_INTERACT_DISTANCE = 4.0,
  SUPPORTED_VEHICLE_CATEGORIES = {
    TRACTORS_S = 'tractorss',
    TRACTORS_M = 'tractorsm',
    TRACTORS_L = 'tractorsl',
    HARVESTERS = 'harvesters',
    FORAGE_HARVESTERS = 'forageharvesters',
    BEET_HARVESTERS = 'beetharvesters',
    SPINACH_HARVESTERS = 'spinachharvesters',
    POTATO_HARVESTERS = 'potatoharvesting',
    GREEN_BEAN_HARVESTERS = "greenbeanharvesters",
    TELELOADERS = 'teleloadervehicles',
    FRONTLOADERS = 'frontloadervehicles',
    WHEELLOADERS = 'wheelloadervehicles',
    FORKLIFTS = 'forklifts',
  },
}

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

function CabCinematicUtil.clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

function CabCinematicUtil.isNear(valueA, valueB, threshold)
  return math.abs(valueA - valueB) <= threshold
end

---Get the closest position from a list to two reference points
---@param positions table Positions to evaluate {{x, y, z}, ...}
---@param ref1 table Reference point 1 {x, y, z}
---@param ref2 table Reference point 2 {x, y, z}
---@return table ClosestPosition {x, y, z }
function CabCinematicUtil.getClosestPositionToTwoRefs(positions, ref1, ref2)
  local bestPoint = nil
  local bestScore = math.huge

  for _, p in ipairs(positions) do
    local ref1Dist = MathUtil.vector3Length(p[1] - ref1[1], p[2] - ref1[2], p[3] - ref1[3])
    local ref2Dist = MathUtil.vector3Length(p[1] - ref2[1], p[2] - ref2[2], p[3] - ref2[3])
    local score = ref1Dist + ref2Dist
    if score < bestScore then
      bestScore = score
      bestPoint = p
    end
  end

  return bestPoint, bestScore
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
          return true
        elseif hit[4] < result.best[4] then
          result.best = hit
        end
      end
    end
  }

  raycastAll(sx, sy, sz, dx, dy, dz, dist, "callback", raycaster, CollisionFlag.VEHICLE)

  return result
end

function CabCinematicUtil.isVehicleTractor(vehicle)
  local category = vehicle:getStoreCategory()

  return category == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TRACTORS_S or
      category == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TRACTORS_M or
      category == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TRACTORS_L
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
  local features = vehicle:getCabCinematicFeatures()
  if features == nil then
    return false
  end

  local enterPosition = features.positions.enter

  local px, py, pz = localToLocal(getParent(player.rootNode), vehicle.rootNode, getTranslation(player.rootNode))
  local ex, ey, ez = unpack(enterPosition)

  -- if player is between vehicle and enter point on X axis
  -- and more than 1.0m away from enter point, then return false
  if features.flags.isEntryFromCabSideLeft then
    if px < math.max(ex - 1, 0) then
      return false
    end
  else
    if px > math.min(ex + 1, 0) then
      return false
    end
  end

  local dist = MathUtil.vector3Length(px - ex, py - ey, pz - ez)
  return dist <= range
end

function CabCinematicUtil:isPlayerInFirstPerson(player)
  local currentVehicle = player:getCurrentVehicle()
  if currentVehicle ~= nil then
    local camera = currentVehicle:getVehicleIndoorCamera()
    if camera ~= nil then
      return g_cameraManager:getActiveCamera() == camera.cameraNode
    end

    return false
  end

  return player.camera.isFirstPerson
end
