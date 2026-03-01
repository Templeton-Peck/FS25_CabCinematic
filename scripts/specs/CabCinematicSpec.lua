CabCinematicSpec = {}

function CabCinematicSpec.prerequisitesPresent(specializations)
  return true
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getStoreCategory", CabCinematicSpec.getStoreCategory)
  SpecializationUtil.registerFunction(vehicleType, "getIsCabCinematicSupported", CabCinematicSpec.getIsCabCinematicSupported)
  SpecializationUtil.registerFunction(vehicleType, "getIndoorCamera", CabCinematicSpec.getIndoorCamera)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicFeatures", CabCinematicSpec.getCabCinematicFeatures)
  SpecializationUtil.registerFunction(vehicleType, "getIsCabCinematicAnimationOngoing", CabCinematicSpec.getIsCabCinematicAnimationOngoing)
  SpecializationUtil.registerFunction(vehicleType, "getCabCinematicPrerequisiteAnimation", CabCinematicSpec.getCabCinematicPrerequisiteAnimation)
  SpecializationUtil.registerFunction(vehicleType, "drawCabCinematicDebug", CabCinematicSpec.drawCabCinematicDebug)
end

function CabCinematicSpec.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "interact", CabCinematicSpec.interact)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "onPlayerEnterVehicle", CabCinematicSpec.onPlayerEnterVehicle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "doLeaveVehicle", CabCinematicSpec.doLeaveVehicle)
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
  spec.animation         = nil
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

  if spec.animation ~= nil then
    spec.animation:delete()
  end

  spec.camera = nil
  spec.storeCategory = nil
  spec.indoorCamera = nil
  spec.features = nil
  spec.animation = nil
end

function CabCinematicSpec:onUpdate(dt)
  if not self:getIsCabCinematicAnimationOngoing() then
    return
  end

  local spec = self.spec_cabCinematic

  if spec.animation:getIsIdle() then
    spec.animation:update(dt)
  elseif spec.animation:getIsRunning() then
    spec.animation:update(dt)
  elseif spec.animation:getIsFinished() then
    spec.animation:update(dt)
  elseif spec.animation:getIsStale() then
    spec.animation:delete()
    spec.animation = nil
    return
  end

  ---Always update camera to let player look around freely
  if spec.camera ~= nil then
    local x, y, z = unpack(spec.animation.currentPosition)
    spec.camera:setPosition(x, y, z)
    spec.camera:update(dt)
  end
end

function CabCinematicSpec:onDraw()
  self:drawCabCinematicDebug()
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

---Overwrite base methods to provide better vehicle interaction
function CabCinematicSpec:interact(superFunc, player)
  if self.interactionFlag == Vehicle.INTERACTION_FLAG_ENTERABLE then
    if self:getIsCabCinematicSupported() then
      local prerequisiteAnimation = self:getCabCinematicPrerequisiteAnimation()
      if prerequisiteAnimation ~= nil and not prerequisiteAnimation.getIsFinished() then
        if not prerequisiteAnimation.getIsPlaying() then
          prerequisiteAnimation.play()
        end

        return
      end

      if CabCinematicUtil.isPlayerInVehicleEnterRange(player, self, CabCinematicUtil.VEHICLE_INTERACT_DISTANCE) == false then
        return
      end
    end
  end

  superFunc(self, player)
end

---Overwrite base method to provide cinematic animation when entering the vehicle
function CabCinematicSpec:onPlayerEnterVehicle(superFunc, ...)
  local args = { ... }
  local vehicle = self

  if vehicle:getIsCabCinematicAnimationOngoing() then
    return
  end

  if not vehicle:getIsCabCinematicSupported() then
    return superFunc(vehicle, unpack(args))
  end

  Log:info("onPlayerEnterVehicle called")

  superFunc(vehicle, unpack(args))

  local animation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.ENTER, vehicle)
  animation:onBeforeStart(function()
    -- CabCinematic.cinematicAnimation.playerSnapshot = CabCinematicPlayerSnapshot.new(g_localPlayer)
    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:deleteVehicleCharacter()

      if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
        vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true, false)
      end
    end
  end)

  animation:onEnd(function()
    if (not vehicle:getIsAIActive()) then
      vehicle.spec_enterable:restoreVehicleCharacter()

      if vehicle.spec_enterable.enterAnimation ~= nil and vehicle.playAnimation ~= nil then
        vehicle:playAnimation(vehicle.spec_enterable.enterAnimation, -1, nil, true)
      end
    end
  end)

  vehicle.spec_cabCinematic.animation = animation
end

---Overwrite base method to provide cinematic animation when leaving the vehicle
function CabCinematicSpec:doLeaveVehicle(superFunc, ...)
  local args = { ... }
  local vehicle = self

  if not vehicle:getIsCabCinematicSupported() then
    return superFunc(vehicle, unpack(args))
  end

  if self:getIsCabCinematicAnimationOngoing() then
    return
  end

  local prerequisiteAnimation = self:getCabCinematicPrerequisiteAnimation()
  if prerequisiteAnimation ~= nil and not prerequisiteAnimation.getIsFinished() then
    if not prerequisiteAnimation.getIsPlaying() then
      prerequisiteAnimation.play()
    end

    return
  end

  Log:info("doLeaveVehicle called")

  local animation = CabCinematicAnimation.new(CabCinematicAnimation.TYPES.LEAVE, vehicle);

  animation:onBeforeStart(function()
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

    g_localPlayer.camera:switchToPerspective(true)

    return superFunc(vehicle, unpack(args))
  end)

  vehicle.spec_cabCinematic.animation = animation
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

---Tells whether a cinematic animation is currently ongoing
---@return boolean
function CabCinematicSpec:getIsCabCinematicAnimationOngoing()
  return self.spec_cabCinematic and self.spec_cabCinematic.animation ~= nil
end

---Get the prerequisite animation type that needs to be completed before starting a new animation, or nil if there are no prerequisites
---@return table|nil prerequisiteAnimationType
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

---Draws debug information for the cab cinematic spec
function CabCinematicSpec:drawCabCinematicDebug()
  local features = self:getCabCinematicFeatures()
  CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, features.positions)
  CabCinematicUtil.drawDebugBoundingBox(self.rootNode, features.positions)
  -- CabCinematicUtil.drawDebugNodeRelativePositions(self.rootNode, features.debugPositions)
  -- CabCinematicUtil.drawDebugNodeRelativeHitResults(self.rootNode, features.debugHits)

  local x, y = 0.01, 0.5
  local alphaSortedFlags = {}
  for text, state in pairs(features.flags) do
    table.insert(alphaSortedFlags, { text = text, state = state })
  end
  table.sort(alphaSortedFlags, function(a, b) return a.text < b.text end)

  for _, flag in ipairs(alphaSortedFlags) do
    y = DebugUtil.renderTextLine(x, y, 0.02, string.format("%s: %s", flag.text, tostring(flag.state)))
  end
end
