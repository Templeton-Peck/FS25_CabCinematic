CabCinematic = Mod:init()
CabCinematic.initialized = false
CabCinematic.camera = CabCinematicCamera.new()
CabCinematic.cinematicAnimation = nil
CabCinematic.vehicle = nil
CabCinematic.finishCallback = nil
CabCinematic.debug = {
  skipAnimation = false,
}

function CabCinematic:initialize()
  Log:info("CabCinematic:initialize called")

  if not self.initialized then
    self:registerActionEvents()
    self.initialized = true
  end
end

function CabCinematic:getIsActive()
  return self.cinematicAnimation ~= nil and self.cinematicAnimation:getIsActive()
end

function CabCinematic:startEnterAnimation(vehicle, withPreMovement, playerDistance, finishCallback)
  Log:info(string.format("CabCinematic:startEnterAnimation called (withPreMovement: %s, distance: %.2fm)",
    tostring(withPreMovement), playerDistance or 0))

  if self:getIsActive() then
    return
  end

  self.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.ANIMATION_TYPE.ENTER, g_localPlayer, vehicle,
    self.camera, withPreMovement, playerDistance, finishCallback)
end

function CabCinematic:startLeaveAnimation(vehicle, finishCallback)
  Log:info("CabCinematic:startLeaveAnimation called")

  if self:getIsActive() then
    return
  end

  self.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.ANIMATION_TYPE.LEAVE, g_localPlayer, vehicle,
    self.camera, false, 0, finishCallback)
end

function CabCinematic:update(dt)
  if not self.initialized then
    self:initialize()
    return
  end

  if self.cinematicAnimation ~= nil then
    if self.cinematicAnimation:getIsEnded() then
      self.cinematicAnimation:delete()
      self.cinematicAnimation = nil
    elseif not self.cinematicAnimation:getIsActive() then
      self.cinematicAnimation:start()
    end
  end

  if self:getIsActive() then
    self.cinematicAnimation:update(dt)
    self.camera:update(dt)
  end
end

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccSkipAnimation", "Skip cab cinematic animation", "consoleCommandSkipCabCinematicAnimation", self)
  addConsoleCommand("ccPauseAnimation", "Pause cab cinematic animation", "consoleCommandPauseCabCinematicAnimation", self)
  addConsoleCommand("ccResumeAnimation", "Resume cab cinematic animation", "consoleCommandResumeCabCinematicAnimation",
    self)
  addConsoleCommand("ccDebugCameras", "Debug cameras", "consoleCommandDebugCameras", self)
end

function CabCinematic:consoleCommandSkipCabCinematicAnimation()
  self.debug.skipAnimation = not self.debug.skipAnimation
  Log:info("Cab cinematic animation skip is now " .. tostring(self.debug.skipAnimation))
end

function CabCinematic:consoleCommandPauseCabCinematicAnimation()
  if self.cinematicAnimation ~= nil then
    self.cinematicAnimation:pause()
  end
end

function CabCinematic:consoleCommandResumeCabCinematicAnimation()
  if self.cinematicAnimation ~= nil then
    self.cinematicAnimation:resume()
  end
end

function CabCinematic:consoleCommandDebugCameras()
  local rx, ry, rz = g_localPlayer.camera:getRotation()
  Log:info(string.format("Player camera rotation (rx, ry, rz): (%.2f, %.2f, %.2f)", rx, ry, rz))

  if g_activeVehicleCamera ~= nil then
    Log:info(string.format("Active vehicle camera rotation (rx, ry, rz): (%.2f, %.2f, %.2f)", g_activeVehicleCamera.rotX,
      g_activeVehicleCamera.rotY, g_activeVehicleCamera.rotZ))
  else
    Log:info("No active vehicle camera")
  end
end

function CabCinematic:onVehicleCameraActivate(superFunc)
  Log:info(string.format("CabCinematic:onVehicleCameraActivate called"))
  self.resetCameraOnVehicleSwitch = false
  superFunc(self)
end

function CabCinematic:registerActionEvents()
  local ok, actionEventId = g_inputBinding:registerActionEvent(InputAction.CAB_CINEMATIC_DEBUG, CabCinematic,
    CabCinematic.debugAction, true, true, false, true)

  Log:info("Registered action event for CabCinematic: " .. tostring(ok))

  if ok then
    g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
    g_inputBinding:setActionEventActive(actionEventId, true)
    g_inputBinding:setActionEventText(actionEventId, "Switch camera")
    g_inputBinding:setActionEventTextVisibility(actionEventId, true)
  else
    Log:error("Failed to register action event for CabCinematic")
  end
end

function CabCinematic:debugAction(actionName, state, arg3, arg4, isAnalog)
  Log:info("Switch camera action triggered with state: " .. tostring(state))
  if state ~= 1 then
    return
  end
end

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

VehicleCamera.onActivate = Utils.overwrittenFunction(VehicleCamera.onActivate, CabCinematic.onVehicleCameraActivate)
