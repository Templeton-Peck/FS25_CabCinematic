CabCinematic = Mod:init({
  camera = CabCinematicCamera.new(),
  cinematicAnimation = nil,
  lastTargetedVehicle = nil,
  inputStates = {
    skipAnimation = false,
  },
  flags = {
    bobbing = true,
    skipAnimation = false,
    disabled = false,
    debug = false
  },
  debugAnimation = nil,
  VEHICLE_INTERACT_DISTANCE = 4.0,
  SUPPORTED_VEHICLE_CATEGORIES = {
    'tractorss',
    'tractorsm',
    'tractorsl',
    'harvesters',
    'forageharvesters',
    'beetharvesters',
    'teleloadervehicles'
  },
})

function CabCinematic:isPlayerInFirstPerson()
  local currentVehicle = g_localPlayer:getCurrentVehicle()
  if currentVehicle ~= nil then
    return g_cameraManager:getActiveCamera() == currentVehicle:getVehicleIndoorCamera().cameraNode
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
  local vehicleCategory = vehicle:getVehicleCategory()

  for _, category in ipairs(self.SUPPORTED_VEHICLE_CATEGORIES) do
    if vehicleCategory == category then
      return true
    end
  end

  if self.flags.debug then
    Log:info("Vehicle category '%s' is not supported for cab cinematic", tostring(vehicleCategory))
  end
  return false
end

function CabCinematic:setSkipAnimationInputState(state)
  self.inputStates.skipAnimation = state
end

function CabCinematic:startCurrentAnimation()
  if self.flags.debug then
    self.debugAnimation = self.cinematicAnimation
  end

  self.cinematicAnimation:start()
end

function CabCinematic:stopCurrentAnimation()
  g_currentMission.isPlayerFrozen = false
  self.cinematicAnimation.vehicle:setCabCinematicSkipAnimationAllowed(false)
  self.cinematicAnimation:stop()

  if not self.flags.debug then
    self.cinematicAnimation:delete()
  end

  self.cinematicAnimation = nil

  self:setSkipAnimationInputState(false)
end

function CabCinematic:update(dt)
  if self.cinematicAnimation ~= nil then
    local vehicle = self.cinematicAnimation.vehicle

    if self:getIsReadyToStop() then
      g_currentMission.isPlayerFrozen = false
      vehicle:setCabCinematicSkipAnimationAllowed(false)
      self:setSkipAnimationInputState(false)

      self.cinematicAnimation:stop()
      self:prepareCamerasForAnimationStop()

      self.cinematicAnimation = nil
    elseif self:getIsActive() then
      self.cinematicAnimation:update(dt)
      local x, y, z = unpack(self.cinematicAnimation.currentPosition)
      self.camera:setPosition(x, y, z)
    else
      local requiredAnimation = vehicle:getVehicleCabCinematicRequiredAnimation()
      self:prepareCamerasForAnimationStart()

      if not requiredAnimation.isPlaying() then
        self:setSkipAnimationInputState(false)
        vehicle:setCabCinematicSkipAnimationAllowed(true)
        g_currentMission.isPlayerFrozen = true

        if not requiredAnimation.isFinished() then
          requiredAnimation.play()
        elseif self:getIsReadyToStart() then
          self.cinematicAnimation:start()
        end
      end
    end

    local vehicleCamera = vehicle:getVehicleIndoorCamera()
    self.camera:setRotation(vehicleCamera.rotX, vehicleCamera.rotY, vehicleCamera.rotZ)
    self.camera:update(dt)
  end
end

function CabCinematic:prepareCamerasForAnimationStart()
  if self.cinematicAnimation ~= nil then
    local vehicle = self.cinematicAnimation.vehicle
    self.camera:link(vehicle.rootNode)

    local vehicleCamera = vehicle:getVehicleIndoorCamera();

    if self.cinematicAnimation.type == CabCinematicAnimation.TYPES.ENTER then
      local playerCamera = g_localPlayer.camera.cameraRootNode
      local dirX, dirY, dirZ = localDirectionToWorld(playerCamera, 0, 0, 1)
      local lX, lY, lZ = worldDirectionToLocal(getParent(vehicleCamera.rotateNode), dirX, dirY, dirZ)
      local pitch, yaw = MathUtil.directionToPitchYaw(lX, lY, lZ)

      vehicleCamera.rotX = pitch
      vehicleCamera.rotY = yaw
      vehicleCamera.rotZ = 0
      vehicleCamera:updateRotateNodeRotation()

      local x, y, z = localToLocal(playerCamera, vehicle.rootNode, getTranslation(playerCamera))
      self.camera:setPosition(x, y, z)
      vehicle:setVehicleIndoorCameraActive()
    elseif self.cinematicAnimation.type == CabCinematicAnimation.TYPES.LEAVE then
      local x, y, z = getTranslation(vehicleCamera.cameraPositionNode)
      self.camera:setPosition(x, y, z)
    end

    self.camera:setRotation(vehicleCamera.rotX, vehicleCamera.rotY, vehicleCamera.rotZ)
    self.camera:syncPosition()
    self.camera:syncRotation()
    self.camera:activate()
  end
end

function CabCinematic:prepareCamerasForAnimationStop()
  if self.cinematicAnimation ~= nil then
    local vehicle = self.cinematicAnimation.vehicle
    if self.cinematicAnimation.type == CabCinematicAnimation.TYPES.ENTER then
      self.camera:deactivate()
      self.camera:unlink()
      vehicle:setActiveCameraIndex(vehicle.spec_enterable.camIndex)
    elseif self.cinematicAnimation.type == CabCinematicAnimation.TYPES.LEAVE then
      local dirX, dirY, dirZ = localDirectionToWorld(self.camera.cameraNode, 0, 0, -1)
      local pitch, yaw = MathUtil.directionToPitchYaw(dirX, dirY, dirZ)
      g_localPlayer.camera:setRotation(pitch, yaw, 0)
      self.camera:deactivate()
      self.camera:unlink()
      g_cameraManager:setActiveCamera(g_localPlayer.camera.firstPersonCamera)
    end
  end
end

function CabCinematic:draw()
  if self.flags.debug then
    if self.debugAnimation ~= nil then
      self.debugAnimation:drawDebug()
    end

    local vehicle = self.debugAnimation ~= nil and self.debugAnimation.vehicle or self.lastTargetedVehicle or nil
    if vehicle ~= nil then
      if vehicle.spec_cabCinematic ~= nil then
        local features = vehicle:getCabCinematicFeatures()
        -- CabCinematicUtil.drawDebugNodeRelativePositions(vehicle.rootNode, features.positions)
        -- CabCinematicUtil.drawDebugNodeRelativePositions(vehicle.rootNode, features.debugPositions)
        -- CabCinematicUtil.drawDebugNodeRelativeHitResults(vehicle.rootNode, features.debugHits)
        -- CabCinematicUtil.drawDebugBoundingBox(vehicle.rootNode, features.positions)

        local nodesParents = vehicle:getCabCinematicNodesParents()
        for _, parentNode in pairs(nodesParents) do
          DebugUtil.drawDebugNode(parentNode, getName(parentNode));
        end

        for _, node in pairs(features.nodes) do
          node:drawDebug()
        end
      end
    end
  end
end

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccPauseAnimation", "Pause animation", "onPauseAnimationConsoleCommand", self)
  addConsoleCommand("ccSkipAnimation", "Skip animation", "onSkipAnimationConsoleCommand", self)
  addConsoleCommand("ccDisable", "Disable animation", "onDisableConsoleCommand", self)
  addConsoleCommand("ccDebug", "Debug animation", "onDebugConsoleCommand", self)
end

function CabCinematic:startMission()
  g_localPlayer.targeter:addTargetType(CabCinematic, CollisionFlag.VEHICLE, 0.1, CabCinematic.VEHICLE_INTERACT_DISTANCE)
  g_localPlayer.targeter:addFilterToTargetType(CabCinematic, function(hitNode)
    if hitNode ~= nil and hitNode ~= 0 and CollisionFlag.getHasGroupFlagSet(hitNode, CollisionFlag.VEHICLE) then
      local vehicle = g_currentMission:getNodeObject(hitNode)
      if vehicle ~= nil then
        vehicle = vehicle.rootVehicle or vehicle
        CabCinematic.lastTargetedVehicle = vehicle
      end
    end

    return true
  end)
end

function CabCinematic:delete()
  removeConsoleCommand("ccPauseAnimation")
  removeConsoleCommand("ccSkipAnimation")
  removeConsoleCommand("ccDisable")
  removeConsoleCommand("ccDebug")

  if self.lastTargetedVehicle ~= nil then
    self.lastTargetedVehicle = nil
  end

  if self.camera ~= nil then
    self.camera:delete()
    self.camera = nil
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

function CabCinematic.onPlayerEnterVehicle(playerInput, superFunc, ...)
  if CabCinematic:getIsActive() then
    return
  end

  if CabCinematic.lastTargetedVehicle == nil then
    return
  end

  if g_currentMission.interactiveVehicleInRange ~= nil then
    g_currentMission.interactiveVehicleInRange.interactionFlag = Vehicle.INTERACTION_FLAG_NONE
  end

  local vehicle = CabCinematic.lastTargetedVehicle
  g_currentMission.interactiveVehicleInRange = vehicle
  g_currentMission.interactiveVehicleInRange.interactionFlag = Vehicle.INTERACTION_FLAG_ENTERABLE

  if CabCinematic:getIsDisabled() or not CabCinematic:getIsVehicleSupported(vehicle) then
    return superFunc(playerInput, ...)
  end

  if g_time <= g_currentMission.lastInteractionTime + 200 then
    return
  end

  if CabCinematicUtil.isPlayerInVehicleEnterRange(g_localPlayer, vehicle, CabCinematic.VEHICLE_INTERACT_DISTANCE) == false then
    return
  end

  pcall(function()
    executeConsoleCommand("cls")
  end)

  Log:info("enterableActionEventEnter called")

  CabCinematic.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.ENTER, vehicle,
    function()
      if (not vehicle:getIsAIActive()) then
        vehicle.spec_enterable:restoreVehicleCharacter()

        if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
          vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, 1, nil, true, true)
        end
      end
    end)
  CabCinematic.cinematicAnimation.playerSnapshot = CabCinematicPlayerSnapshot.new(g_localPlayer)

  superFunc(playerInput, ...)

  if (not vehicle:getIsAIActive()) then
    vehicle.spec_enterable:deleteVehicleCharacter()

    if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
      vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true, false)
    end
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

    if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
      vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true, true)
    end
  end

  CabCinematic.cinematicAnimation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.LEAVE, vehicle,
    function()
      if (not vehicle:getIsAIActive()) then
        vehicle.spec_enterable:restoreVehicleCharacter()
      end

      g_localPlayer.camera:switchToPerspective(true)

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

function CabCinematic.onEnterOrLeaveCombine(combine, superFunc, ...)
  if CabCinematic:getIsActive() or CabCinematic:getIsReadyToStart() then
    return
  end

  return superFunc(combine, ...)
end

function CabCinematic.onVehicleCameraFovySettingChanged(vehicleCamera)
  CabCinematicUtil.syncVehicleCameraFovY(vehicleCamera)
end

function CabCinematic.onPlayerCameraFovySettingChanged(playerCamera, superFunc, ...)
  local currentVehicle = g_localPlayer:getCurrentVehicle()
  if currentVehicle ~= nil then
    CabCinematicUtil.syncVehicleCameraFovY(currentVehicle:getVehicleIndoorCamera())
    CabCinematic.camera:syncFovY()
  end

  return superFunc(playerCamera, ...)
end

function CabCinematic.onPlayerCameraMakeCurrent(playerCamera, superFunc, ...)
  if CabCinematic:getIsActive() then
    return
  end

  return superFunc(playerCamera, ...)
end

local function init()
  VehicleCamera.onFovySettingChanged = Utils.overwrittenFunction(VehicleCamera.onFovySettingChanged,
    CabCinematic.onVehicleCameraFovySettingChanged)
  PlayerCamera.onFovySettingChanged = Utils.overwrittenFunction(PlayerCamera.onFovySettingChanged,
    CabCinematic.onPlayerCameraFovySettingChanged)
  PlayerCamera.makeCurrent = Utils.overwrittenFunction(PlayerCamera.makeCurrent, CabCinematic.onPlayerCameraMakeCurrent)
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
        Log:info("[CabCinematicSpec] Add spec to '%s'", typeName)
        g_vehicleTypeManager:addSpecialization(typeName, CabCinematic.name .. ".cabCinematicSpec")
      end
    end
  end
end

init()
