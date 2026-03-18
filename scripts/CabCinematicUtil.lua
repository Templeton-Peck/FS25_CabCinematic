CabCinematicUtil = {
  VEHICLE_TARGET_DISTANCE = 6.0,
  VEHICLE_INTERACT_DISTANCE = 2.75,
  VEHICLE_DOOR_SAFE_DISTANCE = 0.35,
  SUPPORTED_VEHICLE_CATEGORIES = {
    TRACTORS_S = 'tractorss',
    TRACTORS_M = 'tractorsm',
    TRACTORS_L = 'tractorsl',
    GRAIN_HARVESTERS = 'harvesters',
    FORAGE_HARVESTERS = 'forageharvesters',
    BEET_HARVESTERS = 'beetharvesters',
    SPINACH_HARVESTERS = 'spinachharvesters',
    POTATO_HARVESTERS = 'potatoharvesting',
    GREEN_BEAN_HARVESTERS = "greenbeanharvesters",
    GRAPE_HARVESTERS = "grapeharvesters",
    OLIVE_HARVESTERS = "oliveharvesters",
    SUGARCANE_HARVESTERS = "sugarcaneharvesters",
    RICE_HARVESTERS = "riceharvesters",
    TELELOADERS = 'teleloadervehicles',
    FRONTLOADERS = 'frontloadervehicles',
    WHEELLOADERS = 'wheelloadervehicles',
    FORKLIFTS = 'forklifts',
    SPRAYERS = 'sprayers',
  },
  KEYFRAME_OFFSETS = {
    LADDER_SLOPE = 0.8,
    STAIRS_SLOPE = 1.0,
  }
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
        local text = string.format("%s best (%.2f, %.2f, %.2f)", name, hitResult.best[1], hitResult.best[2], hitResult.best[3])
        DebugUtil.drawDebugGizmoAtWorldPos(px, py + 0.1, pz, 1, 0, 0, 0, 0, 1, text)
      else
        local px, py, pz = localToWorld(node, unpack(hit))
        local text = string.format("%s %d (%.2f, %.2f, %.2f)", name, index, hit[1], hit[2], hit[3])
        DebugUtil.drawDebugGizmoAtWorldPos(px, py + 0.1, pz, 1, 0, 0, 0, 0, 1, text)
      end
    end
  end
end

function CabCinematicUtil.drawDebugBoundingBox(node, minX, maxX, minY, maxY, minZ, maxZ, r, g, b)
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
  DebugUtil.drawDebugLine(x1, y1, z1, x2, y2, z2, r, g, b)
  DebugUtil.drawDebugLine(x2, y2, z2, x3, y3, z3, r, g, b)
  DebugUtil.drawDebugLine(x3, y3, z3, x4, y4, z4, r, g, b)
  DebugUtil.drawDebugLine(x4, y4, z4, x1, y1, z1, r, g, b)

  -- Top rectangle
  DebugUtil.drawDebugLine(x5, y5, z5, x6, y6, z6, r, g, b)
  DebugUtil.drawDebugLine(x6, y6, z6, x7, y7, z7, r, g, b)
  DebugUtil.drawDebugLine(x7, y7, z7, x8, y8, z8, r, g, b)
  DebugUtil.drawDebugLine(x8, y8, z8, x5, y5, z5, r, g, b)

  -- Vertical lines
  DebugUtil.drawDebugLine(x1, y1, z1, x5, y5, z5, r, g, b)
  DebugUtil.drawDebugLine(x2, y2, z2, x6, y6, z6, r, g, b)
  DebugUtil.drawDebugLine(x3, y3, z3, x7, y7, z7, r, g, b)
  DebugUtil.drawDebugLine(x4, y4, z4, x8, y8, z8, r, g, b)
end

function CabCinematicUtil.drawDebugCabBoundingBox(node, boundingBox)
  local minX = boundingBox.left[1]
  local maxX = boundingBox.right[1]
  local minY = boundingBox.bottom[2]
  local maxY = boundingBox.top[2]
  local minZ = boundingBox.back[3]
  local maxZ = boundingBox.front[3]

  CabCinematicUtil.drawDebugBoundingBox(node, minX, maxX, minY, maxY, minZ, maxZ, 1, 1, 0)

  -- Draw 2 pairs of lines which divide the bounding box into 3 sections on the Z axis, to visualize potential door positions
  local thirdSizeZ = (maxZ - minZ) / 3
  CabCinematicUtil.drawDebugBoundingBox(node, minX, maxX, minY, maxY, minZ + thirdSizeZ, minZ + thirdSizeZ, 1, 1, 0)
  CabCinematicUtil.drawDebugBoundingBox(node, minX, maxX, minY, maxY, minZ + 2 * thirdSizeZ, minZ + 2 * thirdSizeZ, 1, 1, 0)
end

function CabCinematicUtil.drawDebugPlatformBoundingBox(node, boundingBox)
  local minX = boundingBox.platformRight[1]
  local maxX = boundingBox.platformLeft[1]
  local minY = boundingBox.platformBottom[2]
  local maxY = boundingBox.platformTop[2]
  local minZ = boundingBox.platformBack[3]
  local maxZ = boundingBox.platformFront[3]

  return CabCinematicUtil.drawDebugBoundingBox(node, minX, maxX, minY, maxY, minZ, maxZ, 1, 0.5, 0)
end

function CabCinematicUtil.drawDebugShadowFocusBoxNode(node, boundingBox)
  local minX = boundingBox.focusRight[1]
  local maxX = boundingBox.focusLeft[1]
  local minY = boundingBox.focusBottom[2]
  local maxY = boundingBox.focusTop[2]
  local minZ = boundingBox.focusBack[3]
  local maxZ = boundingBox.focusFront[3]

  return CabCinematicUtil.drawDebugBoundingBox(node, minX, maxX, minY, maxY, minZ, maxZ, 0, 0, 1)
end

--- Clamps a value between a minimum and maximum range
--- @param value number The value to clamp
--- @param min number The minimum value
--- @param max number The maximum value
--- @return number The clamped value
function CabCinematicUtil.clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

--- Checks if two values are within a certain threshold of each other
--- @param valueA number The first value
--- @param valueB number The second value
--- @param threshold number The maximum allowed difference between the values
--- @return boolean True if the values are within the threshold, false otherwise
function CabCinematicUtil.isNear(valueA, valueB, threshold)
  return math.abs(valueA - valueB) <= threshold
end

--- Get the closest position from a list to a reference point
--- @param positions table Positions to evaluate {{x, y, z}, ...}
--- @param ref table Reference point {x, y, z}
--- @return table | nil ClosestPosition {x, y, z }
function CabCinematicUtil.getClosestPositionToRef(positions, ref)
  local bestPoint = nil
  local bestDist = math.huge

  for _, p in ipairs(positions) do
    local dist = MathUtil.vector3Length(p[1] - ref[1], p[2] - ref[2], p[3] - ref[3])
    if dist ~= nil and dist < bestDist then
      bestDist = dist
      bestPoint = p
    end
  end

  return bestPoint
end

--- Get the closest position from a list to two reference points
--- @param positions table Positions to evaluate {{x, y, z}, ...}
--- @param ref1 table Reference point 1 {x, y, z}
--- @param ref2 table Reference point 2 {x, y, z}
--- @return table | nil ClosestPosition {x, y, z }
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

  return bestPoint
end

--- Merges multiple tables into the first table.
--- Later tables will overwrite values of earlier tables in case of key conflicts.
--- @param t1 table The first table to merge into and return
--- @param ... table | nil Additional tables to merge into the first table
--- @return table Merged table (same as the first table)
function CabCinematicUtil.merge(t1, ...)
  local args = { ... }

  for _, t2 in ipairs(args) do
    if t2 ~= nil then
      for k, v in pairs(t2) do
        t1[k] = v
      end
    end
  end

  return t1
end

--- Concatenates multiple lists into the first list.
--- @param t1 table The first list to concatenate into and return
--- @param ... table | nil Additional lists to concatenate into the first list
--- @return table Concatenated list (same as the first list)
function CabCinematicUtil.concat(t1, ...)
  local args = { ... }

  for _, t2 in ipairs(args) do
    if t2 ~= nil then
      for _, v in ipairs(t2) do
        table.insert(t1, v)
      end
    end
  end

  return t1
end

--- Calculate the average of a list of numbers
--- @param values table List of numbers
--- @return number Average of the numbers
function CabCinematicUtil.avg(values)
  if #values == 0 then
    return 0
  end

  local sum = 0
  for _, v in ipairs(values) do
    sum = sum + v
  end

  return sum / #values
end

--- Calculate the weighted average of a list of numbers
--- @param values table List of numbers
--- @param weights table List of weights corresponding to the values
--- @return number Weighted average of the numbers
function CabCinematicUtil.weightedAvg(values, weights)
  if #values == 0 or #values ~= #weights then
    return 0
  end

  local sum = 0
  local weightSum = 0
  for i, v in ipairs(values) do
    local w = weights[i]
    sum = sum + v * w
    weightSum = weightSum + w
  end

  if weightSum == 0 then
    return 0
  end

  return sum / weightSum
end

--- Raycast against a vehicle and return all hit positions on the vehicle, as well as the closest hit if specified
--- @param vehicle table The vehicle to raycast against
--- @param from table The start position of the raycast {x, y, z} in local vehicle coordinates
--- @param to table The end position of the raycast {x, y, z} in local vehicle coordinates
--- @param bestComparer function(hitA, hitB) Function to compare two hits and determine which is better. Should return true if hitA is better than hitB.
--- @return table Raycast result containing hit positions and distances
function CabCinematicUtil.raycastVehicle(vehicle, from, to, bestComparer)
  local dist = MathUtil.vector3Length(to[1] - from[1], to[2] - from[2], to[3] - from[3])
  local sx, sy, sz = localToWorld(vehicle.rootNode, from[1], from[2], from[3])
  local ex, ey, ez = localToWorld(vehicle.rootNode, to[1], to[2], to[3])

  local dx, dy, dz = MathUtil.vector3Normalize(ex - sx, ey - sy, ez - sz)

  local result = {
    best = nil,
    hits = {},
    hasHit = false,
  }

  local raycaster = {
    callback = function(self, hitObjectId, x, y, z)
      if hitObjectId == vehicle.rootNode then
        local rx, ry, rz = worldToLocal(vehicle.rootNode, x, y, z)
        local hit = { rx, ry, rz }
        table.insert(result.hits, hit)
        result.hasHit = true

        if result.best == nil or bestComparer(hit, result.best) then
          result.best = { unpack(hit) }
        end
      end
    end
  }

  raycastAll(sx, sy, sz, dx, dy, dz, dist, "callback", raycaster, CollisionFlag.VEHICLE)

  return result
end

--- Tells whether the given vehicle is a tractor.
--- @param vehicle table The vehicle to check.
--- @return boolean true if the vehicle is a tractor, false otherwise.
function CabCinematicUtil.isVehicleTractor(vehicle)
  local category = vehicle:getStoreCategory()

  return category == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TRACTORS_S or
      category == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TRACTORS_M or
      category == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TRACTORS_L
end

--- Tells whether the given vehicle is a telehandler.
--- @param vehicle table The vehicle to check.
--- @return boolean true if the vehicle is a telehandler, false otherwise.
function CabCinematicUtil.isVehicleTelehandler(vehicle)
  return vehicle:getStoreCategory() == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TELELOADERS
end

--- Get the player's eyesight height from the ground
--- @return number The player's eyesight height in meters
function CabCinematicUtil.getPlayerEyesightHeight()
  return 1.78
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

function CabCinematicUtil.isPlayerInVehicleAccessRange(player, vehicle, range)
  local analysis = vehicle:getCabCinematicAnalysis()
  if analysis == nil then
    return false
  end

  local accessPosition = analysis.positions.access

  local px, py, pz = localToLocal(getParent(player.rootNode), vehicle.rootNode, getTranslation(player.rootNode))
  local ex, ey, ez = unpack(accessPosition)

  if analysis.flags.isEntryFromCabSide then
    -- if player is between vehicle and access point on X axis
    -- and more than 1.0m away from access point, then return false
    if analysis.flags.isEntryFromCabSideLeft then
      if px < ex - 1 then return false end
    else
      if px > ex + 1 then return false end
    end
  elseif analysis.flags.isEntryFromCabFront then
    if pz < ez - 1 then return false end
  elseif analysis.flags.isEntryFromCabBack then
    if pz > ez + 1 then return false end
  end

  local dist = MathUtil.vector3Length(px - ex, py - ey, pz - ez)
  return dist <= range
end

--- Tells whether the player is currently in first person mode while on foot.
--- @param player table The player to check.
--- @return boolean true if the player is in first person mode, false otherwise.
function CabCinematicUtil.isOnFootPlayerInFirstPerson(player)
  return player.camera.isFirstPerson == true
end

--- Tells whether the vehicle camera indoor first person camera is used
--- @param vehicle table The vehicle to check.
--- @return boolean true if the vehicle is in first person mode, false otherwise.
function CabCinematicUtil.isVehicleInFirstPerson(vehicle)
  local camera = vehicle:getIndoorCamera()
  if camera ~= nil then
    return g_cameraManager:getActiveCamera() == camera.cameraNode
  end

  return false
end

--- Applies the player's camera rotation to the vehicle's indoor camera rotation
--- @param player table The player whose camera rotation to apply
--- @param vehicle table The vehicle whose camera rotation to modify
function CabCinematicUtil.applyPlayerCameraRotationToVehicleCameraRotation(player, vehicle)
  local playerCamera = player.camera
  local vehicleCamera = vehicle:getIndoorCamera()

  if playerCamera == nil or vehicleCamera == nil then
    return
  end

  local dirX, dirY, dirZ = localDirectionToWorld(playerCamera.cameraRootNode, 0, 0, 1)
  local lX, lY, lZ = worldDirectionToLocal(getParent(vehicleCamera.rotateNode), dirX, dirY, dirZ)
  local pitch, yaw = MathUtil.directionToPitchYaw(lX, lY, lZ)

  vehicleCamera.rotX = pitch
  vehicleCamera.rotY = yaw
  vehicleCamera.rotZ = 0
  vehicleCamera:updateRotateNodeRotation()
end

--- Applies the vehicle's indoor camera rotation to the player's camera rotation
--- @param vehicle table The vehicle whose camera rotation to apply
--- @param player table The player whose camera rotation to modify
function CabCinematicUtil.applyVehicleCameraRotationToPlayerCameraRotation(vehicle, player)
  local playerCamera = player.camera
  local vehicleCamera = vehicle:getIndoorCamera()

  if playerCamera == nil or vehicleCamera == nil then
    return
  end

  local dirX, dirY, dirZ = localDirectionToWorld(vehicleCamera.rotateNode, 0, 0, -1)
  local pitch, yaw = MathUtil.directionToPitchYaw(dirX, dirY, dirZ)
  playerCamera:setRotation(pitch, yaw, 0)
end

function CabCinematicUtil.setVehiclePauseInputActiveState(vehicle, state)
  if vehicle.spec_cabCinematic == nil then
    return
  end

  local actionEvent = vehicle.spec_cabCinematic.actionEvents[InputAction.CAB_CINEMATIC_PAUSE]
  if actionEvent == nil or actionEvent.actionEventId == nil then
    return
  end

  g_inputBinding:setActionEventTextVisibility(actionEvent.actionEventId, state)
  g_inputBinding:setActionEventActive(actionEvent.actionEventId, state)
end

--- Gets all nodes involved in an animation
--- @param vehicle table The vehicle whose animation to extract nodes from
--- @param animationName string The name of the animation to extract nodes from
--- @return table List of nodes involved in the animation
function CabCinematicUtil.getVehicleAnimationNodes(vehicle, animationName)
  local nodes = {}

  if animationName == nil or vehicle.spec_animatedVehicle == nil then
    return nodes
  end

  local animation = vehicle.spec_animatedVehicle.animations[animationName]
  if animation == nil then
    return nodes
  end

  if animation.isKeyframe then
    for node, _ in pairs(animation.curvesByNode) do
      table.insert(nodes, node)
    end
  elseif animation.parts ~= nil then
    for _, part in ipairs(animation.parts) do
      for _, av in ipairs(part.animationValues) do
        table.insert(nodes, av.node)
      end
    end
  end

  return nodes
end

--- Adds two x axis values together, taking into account the direction of the keyframe (positive or negative).
--- @param x1 number The first x value.
--- @param x2 number The second x value to add to the first.
--- @param positiveDir boolean Whether to add on a positive direction (true for left/front, false for right/rear).
--- @return number Result The result of the addition, adjusted for the direction.
function CabCinematicUtil.addByDirection(x1, x2, positiveDir)
  if positiveDir then
    return x1 + x2
  else
    return x1 - x2
  end
end

--- Subtracts two x axis values, taking into account the direction of the keyframe (positive or negative).
--- @param x1 number The first x value.
--- @param x2 number The second x value to subtract from the first.
--- @param positiveDir boolean Whether to subtract in a positive direction (true for left/front, false for right/rear).
--- @return number Result The result of the subtraction, adjusted for the direction.
function CabCinematicUtil.subByDirection(x1, x2, positiveDir)
  return CabCinematicUtil.addByDirection(x1, -x2, positiveDir)
end
