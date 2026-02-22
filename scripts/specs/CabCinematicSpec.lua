CabCinematicSpec = {}

function CabCinematicSpec.prerequisitesPresent(specializations)
  return true
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getStoreCategory", CabCinematicSpec.getStoreCategory)
  SpecializationUtil.registerFunction(vehicleType, "isCabCinematicSupported", CabCinematicSpec.isCabCinematicSupported)
  SpecializationUtil.registerFunction(vehicleType, "getIndoorCamera", CabCinematicSpec.getIndoorCamera)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicFeatures", CabCinematicSpec.getCabCinematicFeatures)
end

function CabCinematicSpec.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "interact", CabCinematicSpec.interact)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onDraw", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CabCinematicSpec)
end

function CabCinematicSpec:onLoad()
  local spec             = {}
  spec.actionEvents      = {}
  spec.camera            = CabCinematicCamera.new(self)
  spec.vehicleAnalyzer   = CabCinematicVehicleAnalyzer.new(self)
  spec.storeCategory     = nil
  spec.indoorCamera      = nil
  spec.features          = nil
  self.spec_cabCinematic = spec
end

function CabCinematicSpec:onDelete()
  local spec = self.spec_cabCinematic
  if spec == nil then
    return
  end

  self:clearActionEventsTable(spec.actionEvents)

  if spec.camera ~= nil then
    spec.camera:delete()
  end

  if spec.vehicleAnalyzer ~= nil then
    spec.vehicleAnalyzer:delete()
  end

  spec.camera = nil
  spec.storeCategory = nil
  spec.indoorCamera = nil
  spec.features = nil
end

function CabCinematicSpec:onUpdate()
end

function CabCinematicSpec:onDraw()
  local features = self:getCabCinematicFeatures()
  CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, features.positions)
  -- CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, features.debugPositions)
  CabCinematicUtil.drawDebugNodeRelativeHitResults(self.rootNode, features.debugHits)
  CabCinematicUtil.drawDebugBoundingBox(self.rootNode, features.positions)

  local x, y = 0.01, 1.0
  for text, state in pairs(features.flags) do
    y = DebugUtil.renderTextLine(x, y, 0.02, string.format("%s: %s", text, tostring(state)))
  end
end

function CabCinematicSpec:onEnterVehicle()
end

---Get vehicle store category (in lowercase), or "unknown" if it cannot be determined
---@return string
function CabCinematicSpec:getStoreCategory()
  if self.spec_cabCinematic.storeCategory ~= nil then
    return self.spec_cabCinematic.storeCategory
  end

  self.spec_cabCinematic.storeCategory = "unknown"
  local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
  if storeItem ~= nil and storeItem.categoryName ~= nil then
    self.spec_cabCinematic.storeCategory = string.lower(storeItem.categoryName)
  end

  return self.spec_cabCinematic.storeCategory
end

---Tells whether the vehicle is supported for cab cinematics
---@return boolean
function CabCinematicSpec:isCabCinematicSupported()
  if self:getIndoorCamera() == nil then
    Log:info("Vehicle without an indoor camera is not supported for CabCinematic")
    return false
  end

  local storeCategory = self:getStoreCategory()
  for _, category in pairs(CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES) do
    if storeCategory == category then
      return true
    end
  end

  Log:info("Vehicle store category '%s' is not supported for CabCinematic", tostring(storeCategory))

  return false
end

---Finds and returns the indoor camera, or nil if it cannot be found
---@return table|nil indoorCamera (VehicleCamera)
function CabCinematicSpec:getIndoorCamera()
  if self.spec_cabCinematic.indoorCamera ~= nil then
    return self.spec_cabCinematic.indoorCamera
  end

  if self.spec_enterable and self.spec_enterable.cameras then
    for _, camera in ipairs(self.spec_enterable.cameras) do
      if camera.isInside and camera.isRotatable then
        self.spec_cabCinematic.indoorCamera = camera
        return camera
      end
    end
  end

  return nil
end

---Overwrite base methods to provide better vehicle interaction
function CabCinematicSpec:interact(superFunc, player)
  if self.interactionFlag == Vehicle.INTERACTION_FLAG_ENTERABLE then
    if self:isCabCinematicSupported() then
      if CabCinematicUtil.isPlayerInVehicleEnterRange(player, self, CabCinematicUtil.VEHICLE_INTERACT_DISTANCE) == false then
        return
      end
    end
  end

  superFunc(self, player)
end

---Get analyzed vehicle features, using cached value if available unless force is true
---@param force boolean|nil Whether to force re-analyzing or not (default: false)
---@return table features
function CabCinematicSpec:getCabCinematicFeatures(force)
  if not force and self.spec_cabCinematic.features ~= nil then
    return self.spec_cabCinematic.features
  end

  self.spec_cabCinematic.features = self.spec_cabCinematic.vehicleAnalyzer:analyze()
  return self.spec_cabCinematic.features
end
