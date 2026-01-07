CabCinematicSpec = {}

CabCinematicSpec.VEHICLE_RAYCAST_DISTANCE = 3.0

function CabCinematicSpec.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleIndoorCamera", CabCinematicSpec.getVehicleIndoorCamera)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCategory", CabCinematicSpec.getVehicleCategory)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicNodesParents",
    CabCinematicSpec.getCabCinematicNodesParents)
  SpecializationUtil.registerFunction(vehicleType, "getVehicleCabCinematicRequiredAnimation",
    CabCinematicSpec.getVehicleCabCinematicRequiredAnimation)
  SpecializationUtil.registerFunction(vehicleType, "playVehicleCabCinematicRequiredAnimations",
    CabCinematicSpec.playVehicleCabCinematicRequiredAnimations)
  SpecializationUtil.registerFunction(vehicleType, "getIsVehicleCabCinematicRequiredAnimationFinished",
    CabCinematicSpec.getIsVehicleCabCinematicRequiredAnimationFinished)
  SpecializationUtil.registerFunction(vehicleType, "getIsVehicleCabCinematicRequiredAnimationPlaying",
    CabCinematicSpec.getIsVehicleCabCinematicRequiredAnimationPlaying)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicFeatures",
    CabCinematicSpec.getCabCinematicFeatures)
  SpecializationUtil.registerFunction(vehicleType, "setCabCinematicSkipAnimationAllowed",
    CabCinematicSpec.setCabCinematicSkipAnimationAllowed)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CabCinematicSpec)
end

function CabCinematicSpec:getVehicleIndoorCamera()
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

function CabCinematicSpec:getVehicleCabCinematicRequiredAnimation()
  if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil then
    local ladder = self.spec_combine.ladder
    if ladder ~= nil and ladder.animName ~= nil then
      return {
        name = ladder.animName,
        speed = ladder.animSpeedScale,
        direction = ladder.foldDirection or 1
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
    local time = self:getAnimationTime(anim.name)
    local logicalTime = (anim.direction == 1) and time or (1 - time)
    return logicalTime >= (1 - 0.001)
  else
    return true
  end
end

function CabCinematicSpec:getIsVehicleCabCinematicRequiredAnimationPlaying()
  local anim = self:getVehicleCabCinematicRequiredAnimation()
  return anim ~= nil and self:getIsAnimationPlaying(anim.name)
end

function CabCinematicSpec:getCabCinematicFeatures()
  if self.spec_cabCinematic.features == nil then
    local features = CabCinematicUtil.getVehicleFeatures(self)
    self.spec_cabCinematic.features = features
  end

  return self.spec_cabCinematic.features;
end

function CabCinematicSpec:setCabCinematicSkipAnimationAllowed(allowed)
  local actionEvents = self.spec_cabCinematic.actionEvents;
  if actionEvents[InputAction.CAB_CINEMATIC_SKIP] ~= nil then
    g_inputBinding:setActionEventActive(actionEvents[InputAction.CAB_CINEMATIC_SKIP].actionEventId, allowed)
    g_inputBinding:setActionEventTextVisibility(actionEvents[InputAction.CAB_CINEMATIC_SKIP].actionEventId, allowed)
  end
end

function CabCinematicSpec:getCabCinematicNodesParents()
  if self.spec_cabCinematic.nodesParents == nil then
    self.spec_cabCinematic.nodesParents = CabCinematicUtil.buildParentsNodes(self)
  end

  return self.spec_cabCinematic.nodesParents
end

function CabCinematicSpec:onLoad()
  local spec             = {}
  spec.actionEvents      = {}
  spec.nodesParents      = nil
  spec.indoorCamera      = nil
  spec.vehicleCategory   = nil
  spec.features          = nil
  self.spec_cabCinematic = spec

  CabCinematicUtil.syncVehicleCameraFovY(self:getVehicleIndoorCamera())
end

function CabCinematicSpec:onDelete()
  local spec = self.spec_cabCinematic

  self:clearActionEventsTable(spec.actionEvents)
  CabCinematicUtil.deleteVehicleFeatures(spec.features)
  CabCinematicUtil.deleteParentNodes(spec.nodesParents)
  spec.actionEvents    = nil
  spec.nodesParents    = nil
  spec.indoorCamera    = nil
  spec.vehicleCategory = nil
  spec.features        = nil
end

function CabCinematicSpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  if self.isClient then
    local spec = self.spec_cabCinematic
    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection then
      local _, eventId = self:addActionEvent(spec.actionEvents, InputAction.CAB_CINEMATIC_SKIP, self,
        CabCinematicSpec.onCabCinematicSkipAnimationInput, false, true, false, true, nil)

      if eventId then
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_CAB_CINEMATIC_SKIP"))
        g_inputBinding:setActionEventActive(eventId, false)
        g_inputBinding:setActionEventTextVisibility(eventId, false)
      end
    end
  end
end

function CabCinematicSpec.onCabCinematicSkipAnimationInput(self, actionName, state, arg3, arg4, isAnalog)
  CabCinematic:setSkipAnimationInputState(state == 1)
end
