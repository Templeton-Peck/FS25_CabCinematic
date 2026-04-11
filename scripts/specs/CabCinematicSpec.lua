CabCinematicSpec = {}

function CabCinematicSpec.prerequisitesPresent(specializations)
  return true
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getStoreCategory", CabCinematicSpec.getStoreCategory)
  SpecializationUtil.registerFunction(vehicleType, "getIsCabCinematicSupported", CabCinematicSpec.getIsCabCinematicSupported)
  SpecializationUtil.registerFunction(vehicleType, "getIndoorCamera", CabCinematicSpec.getIndoorCamera)
  SpecializationUtil.registerFunction(vehicleType, "setIndoorCameraActive", CabCinematicSpec.setIndoorCameraActive)
  SpecializationUtil.registerFunction(vehicleType, "setCameraResetProtectState", CabCinematicSpec.setCameraResetProtectState)
  SpecializationUtil.registerFunction(vehicleType, "setEnterAnimationProtectState", CabCinematicSpec.setEnterAnimationProtectState)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicAnalysis", CabCinematicSpec.getCabCinematicAnalysis)
  SpecializationUtil.registerFunction(vehicleType, "invalidateCabCinematicAnalysisCache", CabCinematicSpec.invalidateCabCinematicAnalysisCache)
  SpecializationUtil.registerFunction(vehicleType, "getIsCabCinematicAnimationOngoing", CabCinematicSpec.getIsCabCinematicAnimationOngoing)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicPrerequisiteAnimation", CabCinematicSpec.getCabCinematicPrerequisiteAnimation)
  SpecializationUtil.registerFunction(vehicleType, "drawCabCinematicDebug", CabCinematicSpec.drawCabCinematicDebug)
end

function CabCinematicSpec.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "onPlayerEnterVehicle", CabCinematicSpec.onPlayerEnterVehicle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "doLeaveVehicle", CabCinematicSpec.doLeaveVehicle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getExitNode", CabCinematicSpec.getExitNode)

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
end

--- Initializes the spec when the vehicle is pre loading
function CabCinematicSpec:onPreLoad()
  local spec                        = {}
  spec.camera                       = nil
  spec.vehicleAnalyzer              = nil
  spec.storeCategory                = nil
  spec.indoorCamera                 = nil
  spec.analysis                     = nil
  spec.animation                    = nil
  spec.playerEnterPosition          = nil
  spec.allowStartAnimation          = false
  spec.lastInteractionTime          = -1
  spec.accessNode                   = nil
  spec.inputComponent               = nil
  spec.protectedResetCameraState    = nil
  spec.protectedEnterAnimationState = nil
  self.spec_cabCinematic            = spec
end

--- Initializes the spec when the vehicle is loaded
function CabCinematicSpec:onLoad()
  local spec           = self.spec_cabCinematic
  spec.camera          = CabCinematicCamera.new(self)
  spec.vehicleAnalyzer = CabCinematicVehicleAnalyzer.new(self)
  spec.inputComponent  = CabCinematicInputComponent.new(self)
  spec.accessNode      = createTransformGroup("cc_accessNode")
  link(self.rootNode, spec.accessNode)
  setTranslation(spec.accessNode, 0, 0, 0)
  setRotation(spec.accessNode, 0, 0, 0)

  g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.FOV_Y], CabCinematicSpec.onFovYSettingChanged, self)
  g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.FOV_Y_PLAYER_FIRST_PERSON], CabCinematicSpec.onFovYSettingChanged, self)

  CabCinematicSpec.onFovYSettingChanged(self)
end

--- Deletes the spec and its resources when the vehicle is deleted
function CabCinematicSpec:onDelete()
  local spec = self.spec_cabCinematic

  g_messageCenter:unsubscribeAll(self)

  if spec.inputComponent ~= nil then
    spec.inputComponent:delete()
  end

  if spec.accessNode ~= nil then
    delete(spec.accessNode)
  end

  if spec.camera ~= nil then
    spec.camera:delete()
  end

  if spec.vehicleAnalyzer ~= nil then
    spec.vehicleAnalyzer:delete()
  end

  if spec.animation ~= nil then
    spec.animation:delete()
  end

  spec.camera = nil
  spec.storeCategory = nil
  spec.indoorCamera = nil
  spec.analysis = nil
  spec.animation = nil
  spec.playerEnterPosition = nil
  spec.allowStartAnimation = nil
  spec.lastInteractionTime = nil
  spec.accessNode = nil
  spec.inputComponent = nil
  spec.protectedResetCameraState = nil
  spec.protectedEnterAnimationState = nil
end

--- Updates the cab cinematic animation and camera if an animation is ongoing
--- @param dt number Delta time since last update
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

  --- Always update camera to let player look around freely
  if spec.camera ~= nil then
    local indoorCamera = self:getIndoorCamera()
    if indoorCamera ~= nil then
      spec.camera:setRotation(indoorCamera.rotX, indoorCamera.rotY, indoorCamera.rotZ)
    end

    spec.camera:setPosition(unpack(spec.animation.currentPosition))
    spec.camera:update(dt)
  end
end

--- Draws debug information for the cab cinematic
function CabCinematicSpec:onDraw()
  if CabCinematic.debugLevel > 0 then
    self:drawCabCinematicDebug()
  end
end

--- Get vehicle store category (in lowercase), or "unknown" if it cannot be determined
--- @return string
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

--- Tells whether the vehicle is supported for cab cinematics
--- @return boolean
function CabCinematicSpec:getIsCabCinematicSupported()
  if self:getIndoorCamera() == nil then
    -- Example case : wood logs trailer
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

--- Finds and returns the indoor camera, or nil if it cannot be found
--- @return table|nil indoorCamera (VehicleCamera)
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

--- Sets the indoor camera as active vehicle camera
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

--- Protects or restores the indoor camera reset on vehicle switch state
--- to prevent the camera from resetting to default position during the cinematic animation and breaking the immersion
--- @param protect boolean Whether to protect or restore the reset camera state
function CabCinematicSpec:setCameraResetProtectState(protect)
  local indoorCamera = self:getIndoorCamera()
  if indoorCamera ~= nil then
    if protect then
      self.spec_cabCinematic.protectedResetCameraState = indoorCamera.resetCameraOnVehicleSwitch
      indoorCamera.resetCameraOnVehicleSwitch = false
    else
      indoorCamera.resetCameraOnVehicleSwitch = self.spec_cabCinematic.protectedResetCameraState or false
    end
  end
end

function CabCinematicSpec:setEnterAnimationProtectState(protect)
  if self.spec_enterable ~= nil then
    if protect then
      self.spec_cabCinematic.protectedEnterAnimationState = self.spec_enterable.enterAnimation
      self.spec_enterable.enterAnimation = nil
    else
      self.spec_enterable.enterAnimation = self.spec_cabCinematic.protectedEnterAnimationState or nil
    end
  end
end

--- Overrides base method to ignore call when cinematic animation is ongoing
function CabCinematicSpec.ignoreWhenActive(vehicle, superFunc, ...)
  local attacherVehicle = vehicle.getAttacherVehicle ~= nil and vehicle:getAttacherVehicle() or nil
  local targetVehicle = attacherVehicle or vehicle.rootVehicle or vehicle
  if targetVehicle ~= nil and targetVehicle.spec_cabCinematic and targetVehicle:getIsCabCinematicAnimationOngoing() then
    return
  end

  return superFunc(vehicle, ...)
end

--- Overwrites PlayerInputComponent.onInputEnter to catch player vehicle entering
--- @param playerInputComponent table The PlayerInputComponent instance
--- @param superFunc function The original onInputEnter function
--- @param ... any additional arguments
function CabCinematicSpec.onPlayerActionInputEnter(playerInputComponent, superFunc, ...)
  local player = playerInputComponent.player
  local vehicle = playerInputComponent.player.targetedVehicle
  if vehicle ~= nil and vehicle.spec_cabCinematic ~= nil then
    local spec = vehicle.spec_cabCinematic
    spec.playerEnterPosition = nil
    spec.allowStartAnimation = false

    if not vehicle:getIsCabCinematicSupported() then
      return superFunc(playerInputComponent, ...)
    end

    if vehicle:getIsCabCinematicAnimationOngoing() then
      return
    end

    if not CabCinematicUtil.isOnFootPlayerInFirstPerson(player) then
      return superFunc(playerInputComponent, ...)
    end

    if not CabCinematicUtil.isPlayerInVehicleAccessRange(player, vehicle, CabCinematicUtil.VEHICLE_INTERACT_DISTANCE) then
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

      vehicle:invalidateCabCinematicAnalysisCache()
    end

    -- We capture player positions to adapt (shortcut or expand) the animation based on where the player is entering from.
    spec.playerEnterPosition = { localToLocal(player.camera.cameraRootNode, vehicle.rootNode, getTranslation(player.camera.cameraRootNode)) }
    spec.lastInteractionTime = g_time
    spec.allowStartAnimation = true
  end

  return superFunc(playerInputComponent, ...)
end

--- Overwrites Enterable.actionEventLeave to catch player vehicle leaving
--- @param vehicle table The vehicle instance
--- @param superFunc function The original actionEventLeave function
--- @param ... any additional arguments
function CabCinematicSpec.onPlayerActionInputLeave(vehicle, superFunc, ...)
  if vehicle.spec_cabCinematic ~= nil then
    local spec = vehicle.spec_cabCinematic
    spec.allowStartAnimation = false
    spec.playerEnterPosition = nil

    if not vehicle:getIsCabCinematicSupported() then
      return superFunc(vehicle, ...)
    end

    if vehicle:getIsCabCinematicAnimationOngoing() then
      return
    end

    if not CabCinematicUtil.isVehicleInFirstPerson(vehicle) then
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

      vehicle:invalidateCabCinematicAnalysisCache()
    end

    spec.lastInteractionTime = g_time
    spec.allowStartAnimation = true
  end

  return superFunc(vehicle, ...)
end

--- Overwrites base method to provide cinematic animation when entering the vehicle
--- @param superFunc function The original onPlayerEnterVehicle function
--- @param ... any additional arguments
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

  local keyframeListBuilder = CabCinematicKeyframeListBuilder.prepareBuilderForVehicle(vehicle)
  if keyframeListBuilder == nil then
    return superFunc(vehicle, unpack(args))
  end

  if vehicle.spec_cabCinematic.playerEnterPosition ~= nil then
    keyframeListBuilder:adaptFromPosition(vehicle.spec_cabCinematic.playerEnterPosition)
  end

  vehicle.spec_cabCinematic.allowStartAnimation = false
  vehicle.spec_cabCinematic.playerEnterPosition = nil

  vehicle:setCameraResetProtectState(true)
  vehicle:setEnterAnimationProtectState(true)

  CabCinematicUtil.applyPlayerCameraRotationToVehicleCameraRotation(player, vehicle)

  local animation = CabCinematicAnimation.new(vehicle, keyframeListBuilder:build())
  keyframeListBuilder:delete()

  animation:onBeforeStart(function()
    g_currentMission.isPlayerFrozen = true

    vehicle:setIndoorCameraActive()
    vehicle.spec_cabCinematic.camera:activate()
    vehicle.spec_cabCinematic.inputComponent:activate()

    g_soundManager:setIsIndoor(false)
    g_currentMission.ambientSoundSystem:setIsIndoor(false)
    g_currentMission.environment.environmentMaskSystem:setIsIndoor(false)

    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:deleteVehicleCharacter()
    end
  end)

  animation:onEnd(function()
    vehicle:setIndoorCameraActive()
    vehicle:setEnterAnimationProtectState(false)
    vehicle.spec_cabCinematic.inputComponent:deactivate()

    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:restoreVehicleCharacter()
      if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
        vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, 1, nil, true)
      end
    end

    g_currentMission.isPlayerFrozen = false
    vehicle:setCameraResetProtectState(false)
  end)

  vehicle.spec_cabCinematic.animation = animation

  superFunc(vehicle, unpack(args))
end

--- Overwrites base method to provide cinematic animation when leaving the vehicle
--- @param superFunc function The original doLeaveVehicle function
--- @param ... any additional arguments
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

  local keyframeListBuilder = CabCinematicKeyframeListBuilder.prepareBuilderForVehicle(vehicle)
  if keyframeListBuilder == nil then
    return superFunc(vehicle, unpack(args))
  end

  self:setCameraResetProtectState(true)

  local animation = CabCinematicAnimation.new(vehicle, keyframeListBuilder:reverse():build())

  keyframeListBuilder:delete()

  animation:onBeforeStart(function()
    g_currentMission.isPlayerFrozen = true

    vehicle.spec_cabCinematic.camera:setPosition(unpack(animation.currentPosition))
    vehicle.spec_cabCinematic.camera:activate()
    vehicle.spec_cabCinematic.inputComponent:activate()

    g_soundManager:setIsIndoor(false)
    g_currentMission.ambientSoundSystem:setIsIndoor(false)
    g_currentMission.environment.environmentMaskSystem:setIsIndoor(false)

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
    vehicle.spec_cabCinematic.inputComponent:deactivate()

    superFunc(vehicle, unpack(args))

    CabCinematicUtil.applyVehicleCameraRotationToPlayerCameraRotation(vehicle, player)

    g_currentMission.isPlayerFrozen = false
    -- g_cameraManager:setActiveCamera(player.camera.firstPersonCamera)
    self:setCameraResetProtectState(false)
  end)

  vehicle.spec_cabCinematic.animation = animation
end

--- Overwrites base method to provide custom exit node when cinematic animation is ongoing, to prevent the player from exiting too far from the vehicle and breaking the immersion
function CabCinematicSpec:getExitNode(superFunc, ...)
  if self:getIsCabCinematicAnimationOngoing() then
    local analysis = self:getCabCinematicAnalysis()
    if analysis ~= nil then
      setTranslation(self.spec_cabCinematic.accessNode, analysis.positions.preferredAccess[1], analysis.positions.exit[2], analysis.positions.preferredAccess[3])
      return self.spec_cabCinematic.accessNode
    end
  end

  return superFunc(self, ...)
end

--- Get analyzed vehicle positions and flags, using cached value if available unless force is true
--- @return table|nil analysis
function CabCinematicSpec:getCabCinematicAnalysis()
  if self.spec_cabCinematic.analysis ~= nil then
    return self.spec_cabCinematic.analysis
  end

  if self:getIsCabCinematicSupported() then
    self.spec_cabCinematic.analysis = self.spec_cabCinematic.vehicleAnalyzer:analyze()
    return self.spec_cabCinematic.analysis
  end

  return nil
end

--- Invalidates the cached vehicle analysis, forcing them to be re-analyzed when next requested
function CabCinematicSpec:invalidateCabCinematicAnalysisCache()
  self.spec_cabCinematic.analysis = nil
end

--- Tells whether a cinematic animation is currently ongoing
--- @return boolean
function CabCinematicSpec:getIsCabCinematicAnimationOngoing()
  return self.spec_cabCinematic and self.spec_cabCinematic.animation ~= nil
end

--- Get the prerequisite animation that needs to be completed before starting a new animation, or nil if there are no prerequisites
--- @return table|nil prerequisiteAnimation
function CabCinematicSpec:getCabCinematicPrerequisiteAnimation()
  if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil then
    local ladder = self.spec_combine.ladder
    if ladder ~= nil and ladder.animName ~= nil then
      return {
        play = function()
          self:playAnimation(ladder.animName, ladder.animSpeedScale, self:getAnimationTime(ladder.animName), true)
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

--- Draws debug information for the cab cinematic spec
function CabCinematicSpec:drawCabCinematicDebug()
  local textX, textY = 0.005, 0.75

  if CabCinematic.debugLevel > 1 then
    textY = DebugUtil.renderTextLine(textX, textY, 0.02, string.format("configFileNameClean: %s", self.configFileNameClean))
    textY = DebugUtil.renderTextLine(textX, textY, 0.02, string.format("storeCategory: %s", self:getStoreCategory()))
  end

  local analysis = self:getCabCinematicAnalysis()
  if analysis ~= nil then
    CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, analysis.positions)

    if CabCinematic.debugLevel > 1 then
      CabCinematicUtil.drawDebugCabBoundingBox(self.rootNode, analysis.positions)

      if analysis.flags.isPlatformEquipped then
        CabCinematicUtil.drawDebugPlatformBoundingBox(self.rootNode, analysis.positions)
      end

      local alphaSortedFlags = {}
      for text, state in pairs(analysis.flags) do
        table.insert(alphaSortedFlags, { text = text, state = state })
      end
      table.sort(alphaSortedFlags, function(a, b) return a.text < b.text end)

      for _, flag in ipairs(alphaSortedFlags) do
        textY = DebugUtil.renderTextLine(textX, textY, 0.02, string.format("%s: %s", flag.text, tostring(flag.state)))
      end
    end

    if CabCinematic.debugLevel > 2 then
      if self.spec_cabCinematic.accessNode ~= nil then
        DebugUtil.drawDebugNode(self.spec_cabCinematic.accessNode, getName(self.spec_cabCinematic.accessNode))
      end

      CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, analysis.debugPositions)
      CabCinematicUtil.drawDebugNodeRelativeHitResults(self.rootNode, analysis.debugHits)

      if analysis.debugPositions.focusRight then
        CabCinematicUtil.drawDebugShadowFocusBoxNode(self.rootNode, analysis.debugPositions)
      end
    end

    if CabCinematic.debugLevel > 3 then
      if self.spec_combine ~= nil and self.spec_combine.ladder ~= nil then
        local nodes = CabCinematicUtil.getVehicleAnimationNodes(self, self.spec_combine.ladder.animName)
        for _, node in pairs(nodes) do
          DebugUtil.drawDebugNode(node, getName(node))
        end
      end

      if self.spec_enterable ~= nil and self.spec_enterable.enterAnimation ~= nil then
        local nodes = CabCinematicUtil.getVehicleAnimationNodes(self, self.spec_enterable.enterAnimation)
        for _, node in pairs(nodes) do
          DebugUtil.drawDebugNode(node, getName(node))
        end
      end
    end

    if self.spec_cabCinematic.animation then
      self.spec_cabCinematic.animation:drawDebug()
    else
      local keyframeListBuilder = CabCinematicKeyframeListBuilder.prepareBuilderForVehicle(self)
      if keyframeListBuilder ~= nil then
        local animation = CabCinematicAnimation.new(self, keyframeListBuilder:build())
        animation:drawDebug()
        animation:delete()
        keyframeListBuilder:delete()
      end
    end
  end


  if self.spec_cabCinematic.camera ~= nil then
    self.spec_cabCinematic.camera:drawDebug()
  end
end
