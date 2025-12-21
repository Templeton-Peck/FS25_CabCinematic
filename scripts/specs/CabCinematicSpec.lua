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
  return self:getCabCinematicFeatures().positions.camera
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

function CabCinematicSpec:onLoad()
  local spec             = {}
  spec.actionEvents      = {}
  spec.vehicleCategory   = nil
  spec.features          = nil
  self.spec_cabCinematic = spec
end

function CabCinematicSpec:onDelete()
  local spec = self.spec_cabCinematic

  self:clearActionEventsTable(spec.actionEvents)
  spec.vehicleCategory = nil
  spec.features = nil
  spec.actionEvents = nil
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
