CabCinematicSpec = {}

function CabCinematicSpec.prerequisitesPresent(specializations)
  return true
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getStoreCategory", CabCinematicSpec.getStoreCategory)
  SpecializationUtil.registerFunction(vehicleType, "getIsCabCinematicSupported", CabCinematicSpec.getIsCabCinematicSupported)
  SpecializationUtil.registerFunction(vehicleType, "getIndoorCamera", CabCinematicSpec.getIndoorCamera)
  SpecializationUtil.registerFunction(vehicleType, "setIndoorCameraActive", CabCinematicSpec.setIndoorCameraActive)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicFeatures", CabCinematicSpec.getCabCinematicFeatures)
  SpecializationUtil.registerFunction(vehicleType, "invalidateCabCinematicFeaturesCache", CabCinematicSpec.invalidateCabCinematicFeaturesCache)
  SpecializationUtil.registerFunction(vehicleType, "getIsCabCinematicAnimationOngoing", CabCinematicSpec.getIsCabCinematicAnimationOngoing)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicPrerequisiteAnimation", CabCinematicSpec.getCabCinematicPrerequisiteAnimation)
  SpecializationUtil.registerFunction(vehicleType, "drawCabCinematicDebug", CabCinematicSpec.drawCabCinematicDebug)
end

function CabCinematicSpec.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "onPlayerEnterVehicle", CabCinematicSpec.onPlayerEnterVehicle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "doLeaveVehicle", CabCinematicSpec.doLeaveVehicle)

  -- Entering/leaving overwriting
  PlayerInputComponent.onInputEnter = Utils.overwrittenFunction(PlayerInputComponent.onInputEnter, CabCinematicSpec.onPlayerActionInputEnter)
  Enterable.actionEventLeave = Utils.overwrittenFunction(Enterable.actionEventLeave, CabCinematicSpec.onPlayerActionInputLeave)

  -- Noop overwriting
  Enterable.actionEventCameraSwitch = Utils.overwrittenFunction(Enterable.actionEventCameraSwitch, CabCinematicSpec.ignoreWhenActive)
  Combine.onEnterVehicle = Utils.overwrittenFunction(Combine.onEnterVehicle, CabCinematicSpec.ignoreWhenActive)
  Combine.onLeaveVehicle = Utils.overwrittenFunction(Combine.onLeaveVehicle, CabCinematicSpec.ignoreWhenActive)
  Foldable.actionEventFold = Utils.overwrittenFunction(Foldable.actionEventFold, CabCinematicSpec.ignoreWhenActive)
  Foldable.actionEventFoldMiddle = Utils.overwrittenFunction(Foldable.actionEventFoldMiddle, CabCinematicSpec.ignoreWhenActive)
  Foldable.actionEventFoldAll = Utils.overwrittenFunction(Foldable.actionEventFoldAll, CabCinematicSpec.ignoreWhenActive)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onPreLoad", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onDraw", CabCinematicSpec)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CabCinematicSpec)
end

---Initializes the spec when the vehicle is pre loading
function CabCinematicSpec:onPreLoad()
  local spec               = {}
  spec.actionEvents        = {}
  spec.camera              = nil
  spec.vehicleAnalyzer     = nil
  spec.storeCategory       = nil
  spec.indoorCamera        = nil
  spec.features            = nil
  spec.animation           = nil
  spec.debugAnimation      = nil
  spec.allowStartAnimation = false
  spec.lastInteractionTime = -1
  self.spec_cabCinematic   = spec
end

---Initializes the spec when the vehicle is loaded
function CabCinematicSpec:onLoad()
  local spec           = self.spec_cabCinematic
  spec.camera          = CabCinematicCamera.new(self)
  spec.vehicleAnalyzer = CabCinematicVehicleAnalyzer.new(self)

  g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.FOV_Y], CabCinematicSpec.onFovYSettingChanged, self)
  g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON], CabCinematicSpec.onFovYSettingChanged, self)

  CabCinematicSpec.onFovYSettingChanged(self)
end

---Deletes the spec and its resources when the vehicle is deleted
function CabCinematicSpec:onDelete()
  local spec = self.spec_cabCinematic

  g_messageCenter:unsubscribeAll(self)
  self:clearActionEventsTable(spec.actionEvents)

  if spec.camera ~= nil then
    spec.camera:delete()
  end

  if spec.vehicleAnalyzer ~= nil then
    spec.vehicleAnalyzer:delete()
  end

  if spec.animation ~= nil then
    spec.animation:delete()
  end

  if spec.debugAnimation ~= nil then
    spec.debugAnimation:delete()
  end

  spec.camera = nil
  spec.storeCategory = nil
  spec.indoorCamera = nil
  spec.features = nil
  spec.animation = nil
  spec.debugAnimation = nil
  spec.allowStartAnimation = nil
  spec.lastInteractionTime = nil
end

---Updates the cab cinematic animation and camera if an animation is ongoing
---@param dt number Delta time since last update
function CabCinematicSpec:onUpdate(dt)
  if not self:getIsCabCinematicAnimationOngoing() then
    return
  end

  local spec = self.spec_cabCinematic

  if spec.animation:getIsStale() then
    spec.animation:delete()
    spec.animation = nil
    return
  else
    spec.animation:update(dt)
  end

  ---Always update camera to let player look around freely
  if spec.camera ~= nil then
    local indoorCamera = self:getIndoorCamera()
    if indoorCamera ~= nil then
      spec.camera:setRotation(indoorCamera.rotX, indoorCamera.rotY, indoorCamera.rotZ)
    end

    spec.camera:setPosition(unpack(spec.animation.currentPosition))
    spec.camera:update(dt)
  end
end

---Draws debug information for the cab cinematic
function CabCinematicSpec:onDraw()
  if CabCinematic.debugLevel > 0 then
    self:drawCabCinematicDebug()
  end
end

function CabCinematicSpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  if self.isClient then
    local spec = self.spec_cabCinematic
    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection then
      local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CAB_CINEMATIC_PAUSE, self, CabCinematicSpec.onPlayerPauseCabCinematic, true, true, false, false, nil)
      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
      g_inputBinding:setActionEventTextVisibility(actionEventId, false)
    end
  end
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
function CabCinematicSpec:getIsCabCinematicSupported()
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

---Sets the indoor camera as active vehicle camera
function CabCinematicSpec:setIndoorCameraActive()
  local indoorCamera = self:getIndoorCamera()
  if indoorCamera ~= nil then
    for i, camera in pairs(self.spec_enterable.cameras) do
      if camera == indoorCamera then
        self:setActiveCameraIndex(i)
        break
      end
    end
  end
end

---Overrides base method to ignore call when cinematic animation is ongoing
function CabCinematicSpec.ignoreWhenActive(vehicle, superFunc, ...)
  if vehicle:getIsCabCinematicAnimationOngoing() then
    return
  end

  return superFunc(vehicle, ...)
end

---Overwrites PlayerInputComponent.onInputEnter to catch player vehicle entering
---@param playerInputComponent table The PlayerInputComponent instance
---@param superFunc function The original onInputEnter function
---@param ... any additional arguments
function CabCinematicSpec.onPlayerActionInputEnter(playerInputComponent, superFunc, ...)
  local vehicle = playerInputComponent.player.targetedVehicle
  if vehicle ~= nil and vehicle.spec_cabCinematic ~= nil then
    local spec = vehicle.spec_cabCinematic

    -- if vehicle.spec_combine ~= nil and vehicle.spec_combine.ladder ~= nil and vehicle.spec_animatedVehicle ~= nil then
    --   local animation = vehicle.spec_animatedVehicle.animations[vehicle.spec_combine.ladder.animName]
    --   CabCinematicUtil.printTableRecursively(animation, " ", 0, 5, { "modifierTargetObject", "i3dMappings" })
    -- end


    if not vehicle:getIsCabCinematicSupported() then
      return superFunc(playerInputComponent, ...)
    end

    if vehicle:getIsCabCinematicAnimationOngoing() then
      return
    end

    if not CabCinematicUtil.isOnFootPlayerInFirstPerson(playerInputComponent.player) then
      spec.allowStartAnimation = false
      return superFunc(playerInputComponent, ...)
    end

    if not CabCinematicUtil.isPlayerInVehicleEnterRange(playerInputComponent.player, vehicle, CabCinematicUtil.VEHICLE_INTERACT_DISTANCE) then
      return
    end

    local prerequisiteAnimation = vehicle:getCabCinematicPrerequisiteAnimation()
    if prerequisiteAnimation ~= nil then
      if not prerequisiteAnimation.getIsFinished() then
        if not prerequisiteAnimation.getIsPlaying() then
          prerequisiteAnimation.play()
        end

        return
      end

      vehicle:invalidateCabCinematicFeaturesCache()
    end

    spec.lastInteractionTime = g_time
    spec.allowStartAnimation = true
  end

  return superFunc(playerInputComponent, ...)
end

---Overwrites Enterable.actionEventLeave to catch player vehicle leaving
---@param vehicle table The vehicle instance
---@param superFunc function The original actionEventLeave function
---@param ... any additional arguments
function CabCinematicSpec.onPlayerActionInputLeave(vehicle, superFunc, ...)
  if vehicle.spec_cabCinematic ~= nil then
    local spec = vehicle.spec_cabCinematic

    if not vehicle:getIsCabCinematicSupported() then
      return superFunc(vehicle, ...)
    end

    if vehicle:getIsCabCinematicAnimationOngoing() then
      if g_time - spec.lastInteractionTime > 300 then
        spec.animation:stop()
      end
      return
    end

    if not CabCinematicUtil.isVehicleInFirstPerson(vehicle) then
      spec.allowStartAnimation = false
      return superFunc(vehicle, ...)
    end

    local prerequisiteAnimation = vehicle:getCabCinematicPrerequisiteAnimation()
    if prerequisiteAnimation ~= nil then
      if not prerequisiteAnimation.getIsFinished() then
        if not prerequisiteAnimation.getIsPlaying() then
          prerequisiteAnimation.play()
        end

        return
      end

      vehicle:invalidateCabCinematicFeaturesCache()
    end

    spec.lastInteractionTime = g_time
    spec.allowStartAnimation = true
  end

  return superFunc(vehicle, ...)
end

---Overwrites base method to provide cinematic animation when entering the vehicle
---@param superFunc function The original onPlayerEnterVehicle function
---@param ... any additional arguments
function CabCinematicSpec:onPlayerEnterVehicle(superFunc, ...)
  local args = { ... }
  local vehicle = self
  local player = g_localPlayer

  if vehicle:getIsCabCinematicAnimationOngoing() then
    return
  end

  if not vehicle.spec_cabCinematic.allowStartAnimation then
    return superFunc(vehicle, unpack(args))
  end

  vehicle.spec_cabCinematic.allowStartAnimation = false

  -- We capture player positions to adapt (shortcut or expand) the animation based on where the player is entering from.
  local playerPosition = { localToLocal(player.camera.cameraRootNode, vehicle.rootNode, getTranslation(player.camera.cameraRootNode)) }
  local keyframes = CabCinematicKeyframe.build(vehicle, false)
  local adaptedKeyframes = CabCinematicKeyframe.adaptKeyframesFromPosition(keyframes, playerPosition)

  CabCinematicUtil.applyPlayerCameraRotationToVehicleCameraRotation(player, vehicle)

  local animation = CabCinematicAnimation.new(vehicle, adaptedKeyframes)

  animation:onBeforeStart(function()
    g_currentMission.isPlayerFrozen = true

    vehicle:setIndoorCameraActive()
    vehicle.spec_cabCinematic.camera:activate()
    CabCinematicUtil.setVehiclePauseInputActiveState(vehicle, true)

    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:deleteVehicleCharacter()

      if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
        vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true, false)
      end
    end
  end)

  animation:onEnd(function()
    vehicle:setIndoorCameraActive()
    CabCinematicUtil.setVehiclePauseInputActiveState(vehicle, false)

    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:restoreVehicleCharacter()

      if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
        vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true)
      end
    end

    g_currentMission.isPlayerFrozen = false
  end)

  vehicle.spec_cabCinematic.animation = animation
  if CabCinematic.debugLevel > 0 then
    local debugKeyframes = CabCinematicKeyframe.build(vehicle, false)
    debugKeyframes = CabCinematicKeyframe.adaptKeyframesFromPosition(debugKeyframes, playerPosition)
    vehicle.spec_cabCinematic.debugAnimation = CabCinematicAnimation.new(vehicle, debugKeyframes)
  end

  superFunc(vehicle, unpack(args))
end

---Overwrites base method to provide cinematic animation when leaving the vehicle
---@param superFunc function The original doLeaveVehicle function
---@param ... any additional arguments
function CabCinematicSpec:doLeaveVehicle(superFunc, ...)
  local args = { ... }
  local vehicle = self
  local player = g_localPlayer

  if vehicle:getIsCabCinematicAnimationOngoing() then
    return
  end

  if not vehicle.spec_cabCinematic.allowStartAnimation then
    return superFunc(vehicle, unpack(args))
  end

  vehicle.spec_cabCinematic.allowStartAnimation = false

  local keyframes = CabCinematicKeyframe.build(vehicle, true)
  local animation = CabCinematicAnimation.new(vehicle, keyframes)

  animation:onBeforeStart(function()
    g_currentMission.isPlayerFrozen = true

    vehicle.spec_cabCinematic.camera:setPosition(unpack(animation.currentPosition))
    vehicle.spec_cabCinematic.camera:activate()
    CabCinematicUtil.setVehiclePauseInputActiveState(vehicle, true)

    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:deleteVehicleCharacter()

      if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
        vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true, true)
      end
    end
  end)

  animation:onEnd(function()
    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:restoreVehicleCharacter()
    end

    player.camera:switchToPerspective(true)
    CabCinematicUtil.setVehiclePauseInputActiveState(vehicle, false)

    superFunc(vehicle, unpack(args))

    CabCinematicUtil.applyVehicleCameraRotationToPlayerCameraRotation(vehicle, player)

    g_currentMission.isPlayerFrozen = false
    -- g_cameraManager:setActiveCamera(player.camera.firstPersonCamera)
  end)

  vehicle.spec_cabCinematic.animation = animation
  if CabCinematic.debugLevel > 0 then
    local debugKeyframes = CabCinematicKeyframe.build(vehicle, true)
    vehicle.spec_cabCinematic.debugAnimation = CabCinematicAnimation.new(vehicle, debugKeyframes)
  end
end

---Callback used to toggle cab cinematic pause state when the corresponding input is triggered
---@param vehicle table The vehicle instance
function CabCinematicSpec.onPlayerPauseCabCinematic(vehicle, actionName, inputValue, callbackState, isAnalog)
  if vehicle:getIsCabCinematicAnimationOngoing() then
    local animation = vehicle.spec_cabCinematic.animation
    if inputValue == 0 then
      animation:resume()
    else
      animation:pause()
    end
  end
end

---Get analyzed vehicle features, using cached value if available unless force is true
---@return table|nil features
function CabCinematicSpec:getCabCinematicFeatures()
  if self.spec_cabCinematic.features ~= nil then
    return self.spec_cabCinematic.features
  end

  if self:getIsCabCinematicSupported() then
    self.spec_cabCinematic.features = self.spec_cabCinematic.vehicleAnalyzer:analyze()
    return self.spec_cabCinematic.features
  end

  return nil
end

---Invalidates the cached vehicle features, forcing them to be re-analyzed when next requested
function CabCinematicSpec:invalidateCabCinematicFeaturesCache()
  self.spec_cabCinematic.features = nil
end

---Tells whether a cinematic animation is currently ongoing
---@return boolean
function CabCinematicSpec:getIsCabCinematicAnimationOngoing()
  return self.spec_cabCinematic and self.spec_cabCinematic.animation ~= nil
end

---Get the prerequisite animation that needs to be completed before starting a new animation, or nil if there are no prerequisites
---@return table|nil prerequisiteAnimation
function CabCinematicSpec:getCabCinematicPrerequisiteAnimation()
  if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil then
    local ladder = self.spec_combine.ladder
    if ladder ~= nil and ladder.animName ~= nil then
      return {
        play = function()
          self:playAnimation(ladder.animName, ladder.animSpeedScale, nil, true)
        end,
        getIsPlaying = function()
          if self:getIsAIActive() then
            return false
          end

          return self:getIsAnimationPlaying(ladder.animName)
        end,
        getIsFinished = function()
          if self:getIsAIActive() then
            return true
          end

          local time = self:getAnimationTime(ladder.animName)
          local logicalTime = (ladder.foldDirection == 1) and time or (1 - time)
          return logicalTime >= (1 - 0.001)
        end
      }
    end
  end

  if self.spec_foldable ~= nil and self.spec_foldable.hasFoldingParts then
    if self:getStoreCategory() == CabCinematicUtil.SUPPORTED_VEHICLE_CATEGORIES.TELELOADERS then
      return {
        play = function()
          self:setFoldDirection(-self.spec_foldable.turnOnFoldDirection)
        end,
        getIsPlaying = function()
          if self:getIsAIActive() then
            return false
          end

          return self.spec_foldable.foldMoveDirection ~= 0
              and self.spec_foldable.foldMoveDirection == -self.spec_foldable.turnOnFoldDirection
        end,
        getIsFinished = function()
          if self:getIsAIActive() then
            return true
          end

          return self.spec_foldable.foldMoveDirection == 0 and not self:getIsUnfolded()
        end
      }
    end
  end

  return {
    play = function()
    end,
    getIsPlaying = function()
      return false
    end,
    getIsFinished = function()
      return true
    end
  }
end

--- Callback for when the player's FOV Y setting changes, to sync the cinematic camera's FOV Y value
function CabCinematicSpec.onFovYSettingChanged(vehicle)
  CabCinematicUtil.syncVehicleCameraFovY(vehicle:getIndoorCamera())
end

---Draws debug information for the cab cinematic spec
function CabCinematicSpec:drawCabCinematicDebug()
  local features = self:getCabCinematicFeatures()
  if features ~= nil then
    CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, features.positions)
    -- CabCinematicUtil.drawDebugCabBoundingBox(self.rootNode, features.positions)

    -- if features.flags.isPlatformEquipped then
    --   CabCinematicUtil.drawDebugPlatformBoundingBox(self.rootNode, features.positions)
    -- end

    if CabCinematic.debugLevel > 1 then
      CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, features.debugPositions)
      CabCinematicUtil.drawDebugNodeRelativeHitResults(self.rootNode, features.debugHits)
    end

    -- if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil and self.spec_animatedVehicle ~= nil then
    --   local animation = self.spec_animatedVehicle.animations[self.spec_combine.ladder.animName]
    --   if animation ~= nil then
    --     if animation.parts ~= nil then
    --       for _, part in ipairs(animation.parts) do
    --         for _, av in ipairs(part.animationValues) do
    --           DebugUtil.drawDebugNode(av.node, getName(av.node))
    --         end
    --       end
    --     end
    --   end
    -- end

    local x, y = 0.005, 0.5
    local alphaSortedFlags = {}
    for text, state in pairs(features.flags) do
      table.insert(alphaSortedFlags, { text = text, state = state })
    end
    table.sort(alphaSortedFlags, function(a, b) return a.text < b.text end)

    for _, flag in ipairs(alphaSortedFlags) do
      y = DebugUtil.renderTextLine(x, y, 0.02, string.format("%s: %s", flag.text, tostring(flag.state)))
    end
  end

  local animation = self.spec_cabCinematic.debugAnimation or self.spec_cabCinematic.animation
  if animation ~= nil then
    animation:drawDebug()
  end

  if self.spec_cabCinematic.camera ~= nil then
    self.spec_cabCinematic.camera:drawDebug()
  end
end
