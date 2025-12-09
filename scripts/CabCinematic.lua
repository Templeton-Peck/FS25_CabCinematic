CabCinematic = Mod:init({
  camera = CabCinematicCamera.new(),
  cinematicAnimation = nil,
  vehicle = nil,
  finishCallback = nil,
  inputEventIds = {
    skipAnimation = nil,
  },
  inputStates = {
    skipAnimation = false,
  },
  flags = {
    skipAnimation = false,
    disabled = true,
    debug = true
  },
  debugAnimation = nil,
})

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
  return self.flags.disabled or self:getIsSkipping() or not self:isPlayerInFirstPerson()
end

function CabCinematic:getIsVehicleSupported(vehicle)
  local vehiclePreset = CabCinematicAnimation.PRESETS[vehicle.typeName]
  if vehiclePreset == nil then
    return false
  end

  local vehicleCategory = vehicle:getVehicleCategory()
  if vehiclePreset[vehicleCategory] == nil then
    return false
  end

  return true
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

    local vehicle = g_currentMission.interactiveVehicleInRange or self.debugAnimation and self.debugAnimation.vehicle or
        nil
    if vehicle ~= nil then
      if vehicle.spec_cabCinematic ~= nil then
        CabCinematicUtil.drawDebugNodeRelativePositions(vehicle.rootNode, vehicle:getCabCinematicPositions())

        local cx, cy, cz, radius = getShapeWorldBoundingSphere(vehicle:getVehicleInteriorCamera().shadowFocusBoxNode)
        DebugUtil.drawDebugCube(vehicle:getVehicleInteriorCamera().shadowFocusBoxNode, radius, radius, radius,
          0, 0, 1, 0, 0, 0)

        for _, wheel in pairs(vehicle.spec_wheels.wheels) do
          local wheelNode = wheel.driveNode
          if wheel.linkNode ~= wheel.driveNode then
            wheelNode = wheel.linkNode
          end
          DebugUtil.drawDebugNode(wheelNode, getName(wheelNode))
        end

        -- -- DebugUtil.drawDebugCube(node, sizeX, sizeY, sizeZ, r, g, b, offsetX, offsetY, offsetZ)

        -- -- DebugUtil.drawDebugParallelogram(x,z, widthX,widthZ, heightX,heightZ, heightOffset, r,g,b,a, fixedHeight)
        -- -- DebugUtil.drawDebugParallelogram(cx, cz, radius, 0, 0, radius, cy - radius, 1, 0, 0, 0.5, false)

        -- local _, _, _, radius = getShapeGeometryBoundingSphere(vehicle:getVehicleInteriorCamera().shadowFocusBoxNode)
        -- DebugUtil.drawDebugCircleAtNode(vehicle:getVehicleInteriorCamera().shadowFocusBoxNode, radius, 10)

        -- local shadowFocusBoxNode = vehicle:getVehicleInteriorCamera().shadowFocusBoxNode
        -- local sx, sy, sz = getScale(shadowFocusBoxNode)
        -- DebugUtil.drawDebugNode(shadowFocusBoxNode, "shadowFocusBoxNode");
        -- -- DebugUtil.drawDebugRectangle(shadowFocusBoxNode, minX, maxX, minZ, maxZ, yOffset, r, g, b, a, filled)
        -- --DebugUtil.drawDebugCube(node, sizeX, sizeY, sizeZ, r, g, b, offsetX, offsetY, offsetZ)
        -- DebugUtil.drawDebugRectangle(shadowFocusBoxNode, -sx, sx, -sz, sz, 0, 1, 0, 0, 0.5, false)
        -- DebugUtil.drawDebugCube(shadowFocusBoxNode, sx * 2, sy * 2, sz * 2, 0, 0, 1, 0, 0, 0)
      end

      -- if vehicle.spec_combine ~= nil and vehicle.spec_combine.ladder ~= nil then
      --   local animation = vehicle.spec_animatedVehicle.animations[vehicle.spec_combine.ladder.animName];
      --   if animation ~= nil then
      --     for _, part in ipairs(animation.parts) do
      --       for index = 1, #part.animationValues do
      --         local value = part.animationValues[index]
      --         DebugUtil.drawDebugNode(value.node, getName(value.node))
      --       end
      --     end
      --   end
      -- end
    end
  end
end

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccPauseAnimation", "Pause animation", "onPauseAnimationConsoleCommand", self)
  addConsoleCommand("ccSkipAnimation", "Skip animation", "onSkipAnimationConsoleCommand", self)
  addConsoleCommand("ccDisable", "Disable animation", "onDisableConsoleCommand", self)
  addConsoleCommand("ccDebug", "Debug animation", "onDebugConsoleCommand", self)
end

function CabCinematic:delete()
  removeConsoleCommand("ccPauseAnimation")
  removeConsoleCommand("ccSkipAnimation")
  removeConsoleCommand("ccDisable")
  removeConsoleCommand("ccDebug")

  if self.camera ~= nil then
    self.camera:delete()
    self.camera = nil
  end

  if self.inputEventIds.skipAnimation ~= nil then
    g_inputBinding:removeActionEvent(self.inputEventIds.skipAnimation)
    self.inputEventIds.skipAnimation = nil
  end

  if self.cinematicAnimation ~= nil then
    self.cinematicAnimation:delete()
    self.cinematicAnimation = nil
  end

  if self.debugAnimation ~= nil then
    self.debugAnimation:delete()
    self.debugAnimation = nil
  end
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

function CabCinematic:onDisableConsoleCommand()
  self.flags.disabled = not self.flags.disabled
  Log:info("Cab cinematic disabled : " .. tostring(self.flags.disabled))
end

function CabCinematic:onDebugConsoleCommand()
  self.flags.debug = not self.flags.debug
  Log:info("Cab cinematic debug is now " .. tostring(self.flags.debug))
  if not self.flags.debug and self.debugAnimation ~= nil then
    self.debugAnimation:delete()
    self.debugAnimation = nil
  end
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

  local vehicle = g_currentMission.interactiveVehicleInRange
  if vehicle == nil then
    return
  end

  if CabCinematic:getIsDisabled() or not CabCinematic:getIsVehicleSupported(vehicle) then
    return superFunc(playerInput, ...)
  end

  if g_time <= g_currentMission.lastInteractionTime + 200 then
    return
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info("enterableActionEventEnter called")

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

  local vehicle = g_localPlayer:getCurrentVehicle()
  if vehicle == nil then
    return
  end

  if CabCinematic:getIsDisabled() or not CabCinematic:getIsVehicleSupported(vehicle) then
    return superFunc(enterable, ...)
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info("enterableActionEventLeave called")

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

  if CabCinematic.inputEventIds.skipAnimation ~= nil then
    return
  end

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

local function init()
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
end


init()
