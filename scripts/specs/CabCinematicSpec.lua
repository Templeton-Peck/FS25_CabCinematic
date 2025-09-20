CabCinematicSpec = {}

local function isNear(originNode, targetNode, distance)
  if not originNode or originNode == 0 or not targetNode or targetNode == 0 then
    return false
  end

  local ox, oy, oz = getWorldTranslation(originNode)
  local tx, ty, tz = getWorldTranslation(targetNode)

  local dx = tx - ox
  local dy = ty - oy
  local dz = tz - oz
  local distanceSquared = dx * dx + dy * dy + dz * dz

  return distanceSquared <= (distance * distance)
end

function CabCinematicSpec.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
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

  local isPlayerNearVehicleExitNode = isNear(player.rootNode, self:getExitNode(), 0.5)
  Log:info(string.format("CabCinematicSpec:interact called : %s", tostring(isPlayerNearVehicleExitNode)))

  if isPlayerNearVehicleExitNode then
    return superFunc(self, player)
  end
end

function CabCinematicSpec:onPlayerEnterVehicle(superFunc, isControlling, playerStyle, farmId, userId)
  Log:info("CabCinematicSpec:onPlayerEnterVehicle called")
  if CabCinematic:getIsActive() then
    return
  end

  superFunc(self, isControlling, playerStyle, farmId, userId)
  local spec = self.spec_enterable
  spec:deleteVehicleCharacter()

  return CabCinematic:startEnterAnimation(self, function()
    Log:info("CabCinematicSpec:onPlayerEnterVehicle finish callback called")
    spec:restoreVehicleCharacter()

    return self:setActiveCameraIndex(spec.camIndex)
  end);
end

function CabCinematicSpec:doLeaveVehicle(superFunc)
  Log:info("CabCinematicSpec:doLeaveVehicle called")
  if CabCinematic:getIsActive() then
    return
  end

  local spec = self.spec_enterable
  spec:deleteVehicleCharacter()

  return CabCinematic:startLeaveAnimation(self, function()
    spec:restoreVehicleCharacter()
    return superFunc(self)
  end)
end

function CabCinematicSpec:onLoad()
  local spec                 = {}
  self.spec_cabCinematicSpec = spec
end
