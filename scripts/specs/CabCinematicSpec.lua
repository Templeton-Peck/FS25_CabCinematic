CabCinematicSpec = {}

CabCinematicSpec.VEHICLE_RAYCAST_DISTANCE = 3.0

function CabCinematicSpec.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleInteriorCamera", CabCinematicSpec.getVehicleInteriorCamera)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleInteriorCameraPosition",
    CabCinematicSpec.getVehicleInteriorCameraPosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCategory", CabCinematicSpec.getVehicleCategory)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleDefaultExteriorPosition",
    CabCinematicSpec.getVehicleDefaultExteriorPosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleAdjustedExteriorPosition",
    CabCinematicSpec.getVehicleAdjustedExteriorPosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabSidePosition",
    CabCinematicSpec.getVehicleCabSidePosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabCinematicRequiredAnimation",
    CabCinematicSpec.getVehicleCabCinematicRequiredAnimation)
  SpecializationUtil.registerFunction(vehicleType, "playVehicleCabCinematicRequiredAnimations",
    CabCinematicSpec.playVehicleCabCinematicRequiredAnimations)
  SpecializationUtil.registerFunction(vehicleType, "getIsVehicleCabCinematicRequiredAnimationFinished",
    CabCinematicSpec.getIsVehicleCabCinematicRequiredAnimationFinished)
  SpecializationUtil.registerFunction(vehicleType, "getIsVehicleCabCinematicRequiredAnimationPlaying",
    CabCinematicSpec.getIsVehicleCabCinematicRequiredAnimationPlaying)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicPositions",
    CabCinematicSpec.getCabCinematicPositions)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onInitCabCinematic", CabCinematicSpec)
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

function CabCinematicSpec:getVehicleInteriorCameraPosition()
  return self:getCabCinematicPositions().camera
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

  local cabLeftHitPos = self:getCabCinematicPositions().cabLeft
  local defaultExteriorPosition = self:getVehicleDefaultExteriorPosition()

  local xOffset = 0.0
  local yOffset = 0.0
  local zOffset = 0.0

  if (self.typeName == "combineDrivable" and self:getVehicleCategory() == "forageharvesters") then
    zOffset = 0.2
  end

  self.spec_cabCinematic.adjustedExteriorPosition = {
    cabLeftHitPos[1] + xOffset,
    defaultExteriorPosition[2] + yOffset,
    defaultExteriorPosition[3] + zOffset
  }

  return self.spec_cabCinematic.adjustedExteriorPosition
end

function CabCinematicSpec:getVehicleCabSidePosition()
  return self:getCabCinematicPositions().cabLeft
end

function CabCinematicSpec:getVehicleCabCinematicRequiredAnimation()
  if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil then
    local ladder = self.spec_combine.ladder
    if ladder.animName ~= nil then
      return {
        name = ladder.animName,
        speed = math.abs(ladder.animSpeedScale)
      }
    end
  end

  if self.spec_enterable and self.spec_enterable.enterAnimation then
    if string.find(self.spec_enterable.enterAnimation:lower(), "ladder") ~= nil then
      return {
        name = self.spec_enterable.enterAnimation,
        speed = 1
      }
    end
  end

  return nil
end

function CabCinematicSpec:playVehicleCabCinematicRequiredAnimations()
  local anim = self:getVehicleCabCinematicRequiredAnimation()
  if anim ~= nil then
    self:playAnimation(anim.name, anim.speed, self:getAnimationTime(anim.name), true)
  end
end

function CabCinematicSpec:getIsVehicleCabCinematicRequiredAnimationFinished()
  if self:getIsAIActive() then
    return true
  end

  local anim = self:getVehicleCabCinematicRequiredAnimation()
  if anim ~= nil then
    return self:getAnimationTime(anim.name) >= 1.0
  else
    return true
  end
end

function CabCinematicSpec:getIsVehicleCabCinematicRequiredAnimationPlaying()
  local anim = self:getVehicleCabCinematicRequiredAnimation()
  return anim ~= nil and self:getIsAnimationPlaying(anim.name)
end

function CabCinematicSpec:getCabCinematicPositions()
  if self.spec_cabCinematic.positions == nil then
    local cameraPosition = CabCinematicUtil.getVehicleInteriorCameraPosition(self)
    local steeringWheelPosition = CabCinematicUtil.getVehicleSteeringWheelPosition(self)
    local cabFeatures = CabCinematicUtil.getVehicleCabFeatures(self, cameraPosition, steeringWheelPosition)
    local pathPositions = CabCinematicUtil.getVehiclePathPositions(self, cabFeatures)
    -- self.spec_cabCinematic.positions = CabCinematicUtil.merge(cabFeatures.positions, pathPositions, {
    --   camera        = cameraPosition,
    --   steeringWheel = steeringWheelPosition
    -- })
    self.spec_cabCinematic.positions = pathPositions
  end

  return self.spec_cabCinematic.positions;
end

function CabCinematicSpec:onLoad()
  local spec                    = {}
  spec.vehicleCategory          = nil
  spec.enterSide                = "left"
  spec.defaultExteriorPosition  = nil
  spec.adjustedExteriorPosition = nil
  spec.positions                = nil
  self.spec_cabCinematic        = spec
end

function CabCinematicSpec:onDelete()
  self.spec_cabCinematic.vehicleCategory = nil
  self.spec_cabCinematic.enterSide = nil
  self.spec_cabCinematic.defaultExteriorPosition = nil
  self.spec_cabCinematic.adjustedExteriorPosition = nil
  self.spec_cabCinematic.positions = nil
end
