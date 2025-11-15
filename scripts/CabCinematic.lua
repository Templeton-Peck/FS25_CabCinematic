CabCinematic = Mod:init()
CabCinematic.initialized = false
CabCinematic.camera = CabCinematicCamera.new()
CabCinematic.cinematicAnimation = nil
CabCinematic.vehicle = nil
CabCinematic.finishCallback = nil
CabCinematic.flags = {
  skipAnimation = false,
  debug = false
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

function CabCinematic:startEnterAnimation(vehicle, playerSnapshot, finishCallback)
  Log:info(string.format("CabCinematic:startEnterAnimation"))

  if self:getIsActive() then
    return
  end

  self.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.ENTER, vehicle, self.camera,
    finishCallback)
  self.cinematicAnimation.playerSnapshot = playerSnapshot
end

function CabCinematic:startLeaveAnimation(vehicle, finishCallback)
  Log:info("CabCinematic:startLeaveAnimation called")

  if self:getIsActive() then
    return
  end

  self.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.LEAVE, vehicle,
    self.camera, finishCallback)
end

function CabCinematic:update(dt)
  if not self.initialized then
    self:initialize()
    return
  end

  if self.cinematicAnimation ~= nil then
    if self.cinematicAnimation:getIsEnded() then
      if not self.flags.debug then
        self.cinematicAnimation:delete()
        self.cinematicAnimation = nil
      end
    elseif not self.cinematicAnimation:getIsActive() then
      self.cinematicAnimation:start()
    end
  end

  if self:getIsActive() then
    self.cinematicAnimation:update(dt)
    self.camera:update(dt)
  end
end

function CabCinematic:draw()
  if self.flags.debug then
    if self.cinematicAnimation ~= nil then
      self.cinematicAnimation:drawDebug()
    end

    local vehicle = self.cinematicAnimation and self.cinematicAnimation.vehicle or
        g_currentMission.interactiveVehicleInRange or nil
    if vehicle ~= nil then
      DebugUtil.drawDebugNode(vehicle:getExitNode(), "exitNode")
      DebugUtil.drawDebugNode(vehicle:getVehicleInteriorCamera().cameraPositionNode, "cameraPositionNode")
    end
  end
end

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccSkipAnimation", "Skip animation", "consoleCommandSkipAnimation", self)
  addConsoleCommand("ccDebug", "Debug animation", "consoleCommandDebug", self)
end

function CabCinematic:consoleCommandSkipAnimation()
  self.flags.skipAnimation = not self.flags.skipAnimation
  Log:info("Cab cinematic animation skip is now " .. tostring(self.flags.skipAnimation))
end

function CabCinematic:consoleCommandDebug()
  self.flags.debug = not self.flags.debug
  Log:info("Cab cinematic debug is now " .. tostring(self.flags.debug))
end

function CabCinematic:onVehicleCameraActivate(superFunc)
  Log:info(string.format("CabCinematic:onVehicleCameraActivate called"))
  self.resetCameraOnVehicleSwitch = false
  superFunc(self)
end

function CabCinematic:registerActionEvents()
  local ok, actionEventId = g_inputBinding:registerActionEvent(InputAction.CAB_CINEMATIC_DEBUG, CabCinematic,
    CabCinematic.debugAction, true, true, false, true)

  if ok then
    g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
    g_inputBinding:setActionEventActive(actionEventId, true)
    g_inputBinding:setActionEventText(actionEventId, "CabCinematic Debug Action")
    g_inputBinding:setActionEventTextVisibility(actionEventId, true)
  else
    Log:error("Failed to register action event for CabCinematic")
  end
end

function CabCinematic:debugAction(actionName, state, arg3, arg4, isAnalog)
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
