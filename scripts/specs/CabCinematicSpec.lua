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
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabHitPositions",
    CabCinematicSpec.getVehicleCabHitPositions)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabSidePosition",
    CabCinematicSpec.getVehicleCabSidePosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabCenterPosition",
    CabCinematicSpec.getVehicleCabCenterPosition)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabCinematicRequiredAnimation",
    CabCinematicSpec.getVehicleCabCinematicRequiredAnimation)
  SpecializationUtil.registerFunction(vehicleType, "playVehicleCabCinematicRequiredAnimations",
    CabCinematicSpec.playVehicleCabCinematicRequiredAnimations)
  SpecializationUtil.registerFunction(vehicleType, "isVehicleCabCinematicRequiredAnimationFinished",
    CabCinematicSpec.isVehicleCabCinematicRequiredAnimationFinished)
  SpecializationUtil.registerFunction(vehicleType, "isVehicleCabCinematicRequiredAnimationPlaying",
    CabCinematicSpec.isVehicleCabCinematicRequiredAnimationPlaying)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
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
  if self.spec_cabCinematic.interiorCameraPosition ~= nil then
    return self.spec_cabCinematic.interiorCameraPosition
  end

  local camera = self:getVehicleInteriorCamera()
  if camera ~= nil then
    local dx, dy, dz = getTranslation(camera.cameraPositionNode)
    self.spec_cabCinematic.interiorCameraPosition = { localToLocal(getParent(camera.cameraPositionNode), self.rootNode,
      dx, dy, dz) }
  else
    self.spec_cabCinematic.interiorCameraPosition = { 0, 0, 0 }
  end

  return self.spec_cabCinematic.interiorCameraPosition
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

  local cabLeftHitPos = self:getVehicleCabHitPositions().left
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

function CabCinematicSpec:getVehicleCabCenterPosition()
  local cameraPosition = self:getVehicleInteriorCameraPosition()
  if self.spec_drivable == nil or self.spec_drivable.steeringWheel == nil then
    return cameraPosition
  end

  local steeringWheelNode = self.spec_drivable.steeringWheel.node;
  local _, _, swz = localToLocal(steeringWheelNode, self.rootNode, getTranslation(steeringWheelNode))
  return {
    cameraPosition[1],
    cameraPosition[2],
    (cameraPosition[3] + swz) / 2,
  }
end

local function performLeftCabRaycast(vehicle, cx, cy, cz)
  local dist = CabCinematicSpec.VEHICLE_RAYCAST_DISTANCE;

  local sx, sy, sz = localToWorld(vehicle.rootNode, cx + dist, cy, cz)
  local vx, vy, vz = localToWorld(vehicle.rootNode, cx, cy, cz)
  local dx, dy, dz = MathUtil.vector3Normalize(vx - sx, vy - sy, vz - sz)

  local hit, hitX, hitY, hitZ = RaycastUtil.raycastClosest(sx, sy, sz, dx, dy, dz, dist, CollisionFlag.VEHICLE)
  if hit then
    return { worldToLocal(vehicle.rootNode, hitX, hitY, hitZ) }
  end

  return { worldToLocal(vehicle.rootNode, sx, sy, sz) }
end

local function performFrontCabRaycast(vehicle, cx, cy, cz)
  local dist = CabCinematicSpec.VEHICLE_RAYCAST_DISTANCE;

  local sx, sy, sz = localToWorld(vehicle.rootNode, cx, cy, cz + dist)
  local vx, vy, vz = localToWorld(vehicle.rootNode, cx, cy, cz)
  local dx, dy, dz = MathUtil.vector3Normalize(vx - sx, vy - sy, vz - sz)

  local hit, hitX, hitY, hitZ = RaycastUtil.raycastClosest(sx, sy, sz, dx, dy, dz, dist, CollisionFlag.VEHICLE)
  if hit then
    return { worldToLocal(vehicle.rootNode, hitX, hitY, hitZ) }
  end

  return { worldToLocal(vehicle.rootNode, sx, sy, sz) }
end

function CabCinematicSpec:getVehicleCabHitPositions()
  if self.spec_cabCinematic.cabHitPositions ~= nil then
    return self.spec_cabCinematic.cabHitPositions
  end

  local cx, cy, cz = unpack(self:getVehicleCabCenterPosition())
  local frontHit = performFrontCabRaycast(self, cx, cy, cz)
  local leftHit = performLeftCabRaycast(self, cx, cy, cz)

  local frontDistance = MathUtil.vector3Length(frontHit[1] - cx, frontHit[2] - cy, frontHit[3] - cz)
  local leftDistance = MathUtil.vector3Length(leftHit[1] - cx, leftHit[2] - cy, leftHit[3] - cz)

  local adjustedLeft = {
    cx + (frontDistance / leftDistance) * (leftHit[1] - cx),
    leftHit[2],
    leftHit[3],
  }

  self.spec_cabCinematic.cabHitPositions = {
    front = frontHit,
    left = adjustedLeft,
    right = { adjustedLeft[1] - 2 * (adjustedLeft[1] - frontHit[1]), adjustedLeft[2], adjustedLeft[3] },
  }

  return self.spec_cabCinematic.cabHitPositions
end

function CabCinematicSpec:getVehicleCabSidePosition()
  return self:getVehicleCabHitPositions().left
end

function CabCinematicSpec:getVehicleCabCinematicRequiredAnimation()
  if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil then
    return {
      name = self.spec_combine.ladder.animName,
      speed = self.spec_combine.ladder.animSpeedScale,
    }
  end

  return nil
end

function CabCinematicSpec:playVehicleCabCinematicRequiredAnimations()
  local anim = self:getVehicleCabCinematicRequiredAnimation()
  if anim ~= nil then
    self:playAnimation(anim.name, anim.speed, self:getAnimationTime(anim.name), true)
  end
end

function CabCinematicSpec:isVehicleCabCinematicRequiredAnimationFinished()
  local anim = self:getVehicleCabCinematicRequiredAnimation()
  return anim == nil or self:getAnimationTime(anim.name) >= 1.0
end

function CabCinematicSpec:isVehicleCabCinematicRequiredAnimationPlaying()
  local anim = self:getVehicleCabCinematicRequiredAnimation()
  return anim ~= nil and self:getIsAnimationPlaying(anim.name)
end

function CabCinematicSpec:onLoad()
  local spec                    = {}
  spec.vehicleCategory          = nil
  spec.defaultExteriorPosition  = nil
  spec.adjustedExteriorPosition = nil
  spec.interiorCameraPosition   = nil
  spec.cabHitPositions          = nil
  self.spec_cabCinematic        = spec
end
