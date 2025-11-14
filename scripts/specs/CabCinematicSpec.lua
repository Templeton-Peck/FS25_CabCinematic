CabCinematicSpec = {}

CabCinematicSpec.VEHICLE_INTERACT_DISTANCE = 3.0

local function getDistance(originNode, targetNode)
  if not originNode or originNode == 0 or not targetNode or targetNode == 0 then
    return math.huge
  end

  local ox, oy, oz = getWorldTranslation(originNode)
  local tx, ty, tz = getWorldTranslation(targetNode)

  local dx = tx - ox
  local dy = ty - oy
  local dz = tz - oz

  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function CabCinematicSpec.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleInteriorCamera", CabCinematicSpec.getVehicleInteriorCamera)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCategory", CabCinematicSpec.getVehicleCategory)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleDefaultExteriorPosition",
    CabCinematicSpec.getVehicleDefaultExteriorPosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleAdjustedExteriorPosition",
    CabCinematicSpec.getVehicleAdjustedExteriorPosition)
end

function CabCinematicSpec.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "interact", CabCinematicSpec.interact)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "onPlayerEnterVehicle",
    CabCinematicSpec.onPlayerEnterVehicle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "doLeaveVehicle",
    CabCinematicSpec.doLeaveVehicle)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
end

function CabCinematicSpec:interact(superFunc, player)
  if CabCinematic:getIsActive() then
    return
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info(string.format("Player speed: %.2f", player:getSpeed()))

  local exitNode = self:getExitNode()
  local playerDistance = getDistance(player.rootNode, exitNode)
  local isPlayerInVehicleExitNodeRange = playerDistance <= CabCinematicSpec.VEHICLE_INTERACT_DISTANCE

  self.spec_cabCinematic.playerSnapshot = CabCinematicPlayerSnapshot.new(player)

  Log:info(string.format("CabCinematicSpec:interact - Distance: %.2fm", playerDistance))

  if isPlayerInVehicleExitNodeRange then
    return superFunc(self, player)
  end
end

function CabCinematicSpec:onPlayerEnterVehicle(superFunc, isControlling, playerStyle, farmId, userId)
  Log:info("CabCinematicSpec:onPlayerEnterVehicle called")
  if CabCinematic:getIsActive() then
    return
  end

  superFunc(self, isControlling, playerStyle, farmId, userId)

  if (not self:getIsAIActive()) then
    self.spec_enterable:deleteVehicleCharacter()
  end

  return CabCinematic:startEnterAnimation(self, self.spec_cabCinematic.playerSnapshot, function()
    Log:info("CabCinematicSpec:onPlayerEnterVehicle finish callback called")
    if (not self:getIsAIActive()) then
      self.spec_enterable:restoreVehicleCharacter()
    end


    return self:setActiveCameraIndex(self.spec_enterable.camIndex)
  end);
end

function CabCinematicSpec:doLeaveVehicle(superFunc)
  -- return superFunc(self)

  Log:info("CabCinematicSpec:doLeaveVehicle called")
  if CabCinematic:getIsActive() then
    return
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  if (not self:getIsAIActive()) then
    self.spec_enterable:deleteVehicleCharacter()
  end

  return CabCinematic:startLeaveAnimation(self, function()
    if (not self:getIsAIActive()) then
      self.spec_enterable:restoreVehicleCharacter()
    end
    return superFunc(self)
  end)
end

function CabCinematicSpec:getVehicleInteriorCamera()
  if self.spec_enterable and self.spec_enterable.cameras then
    for _, camera in ipairs(self.spec_enterable.cameras) do
      if camera.isInside then
        return camera
      end
    end
  end
  return nil
end

function CabCinematicSpec:getVehicleCategory()
  if self.spec_cabCinematic.vehicleCategory ~= nil then
    return self.spec_cabCinematic.vehicleCategory
  end

  self.spec_cabCinematic.vehicleCategory = "unknown"
  local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
  if storeItem ~= nil and storeItem.categoryName ~= nil then
    self.spec_cabCinematic.vehicleCategory = string.lower(storeItem.categoryName)
  end

  return self.spec_cabCinematic.vehicleCategory
end

function CabCinematicSpec:getVehicleDefaultExteriorPosition()
  if self.spec_cabCinematic.defaultExteriorPosition ~= nil then
    return self.spec_cabCinematic.defaultExteriorPosition
  end

  local _, wpy, _ = getWorldTranslation(getParent(g_localPlayer.camera.firstPersonCamera))
  local wex, _, wez = getWorldTranslation(self:getExitNode())
  local wty = getTerrainHeightAtWorldPos(g_terrainNode, wex, 0, wez) + 0.05
  self.spec_cabCinematic.defaultExteriorPosition = { worldToLocal(self.rootNode, wex, wty + (wpy - wty), wez) }

  return self.spec_cabCinematic.defaultExteriorPosition
end

function CabCinematicSpec:getVehicleAdjustedExteriorPosition()
  if self.spec_cabCinematic.adjustedExteriorPosition ~= nil then
    return self.spec_cabCinematic.adjustedExteriorPosition
  end

  local dist = 3.0
  local ex, ey, ez = unpack(self:getVehicleDefaultExteriorPosition())
  local sx, sy, sz = localToWorld(self.rootNode, ex, ey, ez)
  local vx, vy, vz = localToWorld(self.rootNode, ex - dist, ey, ez)

  local dx, dy, dz = vx - sx, vy - sy, vz - sz
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)

  dx, dy, dz = dx / len, dy / len, dz / len

  local hit, hitX, hitY, hitZ = RaycastUtil.raycastClosest(sx, sy, sz, dx, dy, dz, dist, CollisionFlag.VEHICLE)
  if hit then
    Log:info(string.format("Raycast hit at (%.2f, %.2f, %.2f)", hitX, hitY, hitZ))
    self.spec_cabCinematic.adjustedExteriorPosition = { worldToLocal(self.rootNode, hitX, hitY, hitZ) }
  end

  return self.spec_cabCinematic.adjustedExteriorPosition
end

function CabCinematicSpec:onLoad()
  local spec                    = {}
  spec.playerSnapshot           = nil
  spec.vehicleCategory          = nil
  spec.defaultExteriorPosition  = nil
  spec.adjustedExteriorPosition = nil
  self.spec_cabCinematic        = spec
end
