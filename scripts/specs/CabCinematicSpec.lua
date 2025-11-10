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
  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info(string.format("Player speed: %.2f", player:getSpeed()))
  if CabCinematic:getIsActive() then
    return
  end

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
  return superFunc(self)
  -- pcall(function()
  --   executeConsoleCommand("cls")
  -- end)

  -- Log:info("CabCinematicSpec:doLeaveVehicle called")
  -- if CabCinematic:getIsActive() then
  --   return
  -- end

  -- if (not self:getIsAIActive()) then
  --   self.spec_enterable:deleteVehicleCharacter()
  -- end

  -- return CabCinematic:startLeaveAnimation(self, function()
  --   if (not self:getIsAIActive()) then
  --     self.spec_enterable:restoreVehicleCharacter()
  --   end
  --   return superFunc(self)
  -- end)
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

function CabCinematicSpec:onLoad()
  local spec             = {}
  spec.playerSnapshot    = nil
  self.spec_cabCinematic = spec
end
