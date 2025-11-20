CabCinematic = Mod:init()
CabCinematic.camera = CabCinematicCamera.new()
CabCinematic.cinematicAnimation = nil
CabCinematic.vehicle = nil
CabCinematic.finishCallback = nil
CabCinematic.inputEventIds = {
  skipAnimation = nil,
}
CabCinematic.inputStates = {
  skipAnimation = false,
}
CabCinematic.flags = {
  skipAnimation = false,
  debug = false
}
CabCinematic.debugAnimation = nil

CabCinematic.VEHICLE_INTERACT_DISTANCE = 3.0

function CabCinematic:isPlayerInFirstPerson()
  if g_currentVehicle ~= nil then
    return g_cameraManager:getActiveCamera() == g_currentVehicle:getVehicleInteriorCamera().cameraNode
  end

  return g_localPlayer.camera.isFirstPerson;
end

function CabCinematic:getIsActive()
  return self.cinematicAnimation ~= nil and self.cinematicAnimation:getIsActive()
end

function CabCinematic:getIsReadyToStart()
  return self.cinematicAnimation ~= nil and not self.cinematicAnimation:getIsActive() and
      not self.cinematicAnimation:getIsEnded()
end

function CabCinematic:getIsReadyToStop()
  return self.cinematicAnimation ~= nil and (self.cinematicAnimation:getIsEnded() or CabCinematic:getIsSkipping())
end

function CabCinematic:getIsSkipping()
  return self.inputStates.skipAnimation or self.flags.skipAnimation
end

function CabCinematic:getIsDisabled()
  return self:getIsSkipping() or not self:isPlayerInFirstPerson()
end

function CabCinematic:startCurrentAnimation()
  if self.flags.debug then
    self.debugAnimation = self.cinematicAnimation
  end

  g_inputBinding:setActionEventTextVisibility(CabCinematic.inputEventIds.skipAnimation, true)
  CabCinematic.inputStates.skipAnimation = false
  self.cinematicAnimation:start()
end

function CabCinematic:stopCurrentAnimation()
  self.cinematicAnimation:stop()

  if not self.flags.debug then
    self.cinematicAnimation:delete()
  end

  self.cinematicAnimation = nil

  CabCinematic.inputStates.skipAnimation = false
  g_inputBinding:setActionEventTextVisibility(CabCinematic.inputEventIds.skipAnimation, false)
end

function CabCinematic:update(dt)
  if self:getIsReadyToStart() then
    self:startCurrentAnimation()
  elseif self:getIsReadyToStop() then
    self:stopCurrentAnimation()
  elseif self:getIsActive() then
    self.cinematicAnimation:update(dt)
    self.camera:update(dt)
  end
end

function CabCinematic:draw()
  if self.flags.debug then
    if self.debugAnimation ~= nil then
      self.debugAnimation:drawDebug()
    end

    local vehicle = self.debugAnimation and self.debugAnimation.vehicle or
        g_currentMission.interactiveVehicleInRange or nil
    if vehicle ~= nil then
      DebugUtil.drawDebugNode(vehicle:getExitNode(), "exitNode")
      DebugUtil.drawDebugNode(vehicle.spec_drivable.steeringWheel.node, "steeringAxleNode")

      local wdx, wdy, wdz = localToWorld(vehicle.rootNode, unpack(vehicle:getVehicleInteriorCameraPosition()))
      local dex, dey, dez = localToWorld(vehicle.rootNode, unpack(vehicle:getVehicleDefaultExteriorPosition()))
      local aex, aey, aez = localToWorld(vehicle.rootNode, unpack(vehicle:getVehicleAdjustedExteriorPosition()))

      local positions = vehicle:getVehicleCabHitPositions()

      local cfx, cfy, cfz = localToWorld(vehicle.rootNode, unpack(positions.front))
      local clx, cly, clz = localToWorld(vehicle.rootNode, unpack(positions.left))
      local crx, cry, crz = localToWorld(vehicle.rootNode, unpack(positions.right))
      local ccx, ccy, ccz = localToWorld(vehicle.rootNode, unpack(vehicle:getVehicleCabCenterPosition()))

      DebugUtil.drawDebugGizmoAtWorldPos(wdx, wdy, wdz, 1, 0, 0, 0, 1, 0, "interiorCameraPosition")
      DebugUtil.drawDebugGizmoAtWorldPos(dex, dey, dez, 1, 0, 0, 0, 1, 0, "defaultExteriorPosition")
      DebugUtil.drawDebugGizmoAtWorldPos(aex, aey, aez, 1, 0, 0, 0, 1, 0, "adjustedExteriorPosition")
      DebugUtil.drawDebugGizmoAtWorldPos(cfx, cfy, cfz, 1, 0, 0, 0, 1, 0, "cabFrontHit")
      DebugUtil.drawDebugGizmoAtWorldPos(clx, cly, clz, 1, 0, 0, 0, 1, 0, "cabLeftHit")
      DebugUtil.drawDebugGizmoAtWorldPos(crx, cry, crz, 1, 0, 0, 0, 1, 0, "cabRightHit")
      DebugUtil.drawDebugGizmoAtWorldPos(ccx, ccy, ccz, 1, 0, 0, 0, 1, 0, "cabCenterPosition")
    end

    -- local rVehicle = g_currentMission.interactiveVehicleInRange
    -- if rVehicle ~= nil then
    -- end
  end
end

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccPauseAnimation", "Pause animation", "onPauseAnimationConsoleCommand", self)
  addConsoleCommand("ccSkipAnimation", "Skip animation", "onSkipAnimationConsoleCommand", self)
  addConsoleCommand("ccDebug", "Debug animation", "onDebugConsoleCommand", self)
end

function CabCinematic:onPauseAnimationConsoleCommand()
  if self.cinematicAnimation ~= nil then
    self.cinematicAnimation:pause()
  else
    Log:info("No cab cinematic animation to pause")
  end
end

function CabCinematic:onSkipAnimationConsoleCommand()
  self.flags.skipAnimation = not self.flags.skipAnimation
  Log:info("Cab cinematic animation skip is now " .. tostring(self.flags.skipAnimation))
end

function CabCinematic:onDebugConsoleCommand()
  self.flags.debug = not self.flags.debug
  Log:info("Cab cinematic debug is now " .. tostring(self.flags.debug))
end

function CabCinematic.onVehicleCameraActivate(self, superFunc, ...)
  Log:info(string.format("onVehicleCameraActivate called"))
  -- self.resetCameraOnVehicleSwitch = false
  superFunc(self, ...)
end

function CabCinematic:onSkipAnimationInput(actionName, state, arg3, arg4, isAnalog)
  self.inputStates.skipAnimation = state == 1
end

function CabCinematic.onPlayerEnterVehicle(playerInput, superFunc, ...)
  if CabCinematic:getIsActive() then
    return
  end

  if CabCinematic:getIsDisabled() then
    return superFunc(playerInput, ...)
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info("enterableActionEventEnter called")


  if g_time <= g_currentMission.lastInteractionTime + 200 then
    return
  end

  local vehicle = g_currentMission.interactiveVehicleInRange
  if vehicle == nil then
    return
  end

  local exitNode = vehicle:getExitNode()
  local playerDistance = CabCinematicUtil.getNodeDistance3D(g_localPlayer.rootNode, exitNode)
  local isPlayerInVehicleExitNodeRange = playerDistance <= CabCinematic.VEHICLE_INTERACT_DISTANCE

  Log:info(string.format("Player distance: %.2fm", playerDistance))

  if not isPlayerInVehicleExitNodeRange then
    return
  end

  CabCinematic.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.ENTER, vehicle,
    CabCinematic.camera,
    function()
      if (not vehicle:getIsAIActive()) then
        vehicle.spec_enterable:restoreVehicleCharacter()
      end

      return vehicle:setActiveCameraIndex(vehicle.spec_enterable.camIndex)
    end)
  CabCinematic.cinematicAnimation.playerSnapshot = CabCinematicPlayerSnapshot.new(g_localPlayer)

  superFunc(playerInput, ...)

  if (not vehicle:getIsAIActive()) then
    vehicle.spec_enterable:deleteVehicleCharacter()
  end
end

function CabCinematic.onPlayerVehicleLeave(enterable, superFunc, ...)
  if CabCinematic:getIsActive() then
    return
  end

  if CabCinematic:getIsDisabled() then
    return superFunc(enterable, ...)
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info("enterableActionEventLeave called")

  local vehicle = g_localPlayer:getCurrentVehicle()
  if vehicle == nil then
    return
  end


  if (not vehicle:getIsAIActive()) then
    vehicle.spec_enterable:deleteVehicleCharacter()
  end

  CabCinematic.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.LEAVE, vehicle,
    CabCinematic.camera,
    function()
      if (not vehicle:getIsAIActive()) then
        vehicle.spec_enterable:restoreVehicleCharacter()
      end

      return superFunc(enterable)
    end)
end

function CabCinematic.onPlayerSwitchVehicleCamera(enterable, superFunc, ...)
  Log:info("onPlayerSwitchVehicleCamera called")
  if CabCinematic:getIsActive() then
    return
  end

  return superFunc(enterable, ...)
end

function CabCinematic.registerPlayerActionEvents(playerInput, superFunc, ...)
  superFunc(playerInput, ...)

  Log:info("CabCinematic.registerPlayerActionEvents called")

  local ok, eventId = g_inputBinding:registerActionEvent(InputAction.CAB_CINEMATIC_SKIP, CabCinematic,
    CabCinematic.onSkipAnimationInput, true, true, true, true)

  if ok then
    CabCinematic.inputEventIds.skipAnimation = eventId
    g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
    g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_CAB_CINEMATIC_SKIP"))
    g_inputBinding:setActionEventTextVisibility(eventId, false)
  else
    Log:error("Failed to register action event for CabCinematic")
  end
end

function CabCinematic.onEnterOrLeaveCombine(combine, superFunc, ...)
  if CabCinematic:getIsActive() or CabCinematic:getIsReadyToStart() then
    return
  end

  return superFunc(combine, ...)
end

VehicleCamera.onActivate = Utils.overwrittenFunction(VehicleCamera.onActivate, CabCinematic.onVehicleCameraActivate)
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
  PlayerInputComponent.registerGlobalPlayerActionEvents, CabCinematic.registerPlayerActionEvents)
PlayerInputComponent.onInputEnter = Utils.overwrittenFunction(PlayerInputComponent.onInputEnter,
  CabCinematic.onPlayerEnterVehicle)
Enterable.actionEventLeave = Utils.overwrittenFunction(Enterable.actionEventLeave, CabCinematic.onPlayerVehicleLeave)
Enterable.actionEventCameraSwitch = Utils.overwrittenFunction(Enterable.actionEventCameraSwitch,
  CabCinematic.onPlayerSwitchVehicleCamera)
Combine.onEnterVehicle = Utils.overwrittenFunction(Combine.onEnterVehicle, CabCinematic.onEnterOrLeaveCombine)
Combine.onLeaveVehicle = Utils.overwrittenFunction(Combine.onLeaveVehicle, CabCinematic.onEnterOrLeaveCombine)

if g_specializationManager:getSpecializationByName("cabCinematicSpec") == nil then
  g_specializationManager:addSpecialization("cabCinematicSpec", "CabCinematicSpec",
    Utils.getFilename("scripts/specs/CabCinematicSpec.lua", CabCinematic.dir), nil)
end

for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
  if typeEntry ~= nil and SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations) then
    if not SpecializationUtil.hasSpecialization(CabCinematicSpec, typeEntry.specializations) then
      Log:info(string.format("[CabCinematicSpec] Add spec to '%s'", typeName))
      g_vehicleTypeManager:addSpecialization(typeName, CabCinematic.name .. ".cabCinematicSpec")
    end
  end
end
