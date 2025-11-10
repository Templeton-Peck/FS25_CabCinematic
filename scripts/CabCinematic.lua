CabCinematic = Mod:init()
CabCinematic.initialized = false
CabCinematic.camera = CabCinematicCamera.new()
CabCinematic.cinematicAnimation = nil
CabCinematic.vehicle = nil
CabCinematic.finishCallback = nil
CabCinematic.flags = {
  skipAnimation = false,
  debugAnimation = false
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
      if not self.flags.debugAnimation then
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
  if self.flags.debugAnimation and self.cinematicAnimation ~= nil then
    self.cinematicAnimation:drawDebug()
  end
end

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccSkipAnimation", "Skip animation", "consoleCommandSkipAnimation", self)
  addConsoleCommand("ccDebugAnimation", "Debug animation", "consoleCommandDebugAnimation", self)
  addConsoleCommand("ccDebugCameras", "Debug cameras", "consoleCommandDebugCameras", self)
  addConsoleCommand("ccPrintPresets", "Print current animation presets", "consoleCommandPrintPresets", self)
  addConsoleCommand("ccSetHotPreset",
    "Update animation preset: ccUpdateAnimation <typeName> <category> <keyframe1> ... (keyframe format: type,weightXZ,weightY,angle)",
    "consoleCommandSetHotPreset", self)
end

function CabCinematic:consoleCommandSkipAnimation()
  self.flags.skipAnimation = not self.flags.skipAnimation
  Log:info("Cab cinematic animation skip is now " .. tostring(self.flags.skipAnimation))
end

function CabCinematic:consoleCommandDebugAnimation()
  self.flags.debugAnimation = not self.flags.debugAnimation
  Log:info("Cab cinematic animation debug is now " .. tostring(self.flags.debugAnimation))
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

function CabCinematic:consoleCommandPrintPresets()
  for typeName, categories in pairs(CabCinematicAnimation.PRESETS) do
    for category, keyframes in pairs(categories) do
      local keyframeStrings = {}
      for _, keyframe in ipairs(keyframes) do
        local keyframeString = string.format("%s,%.2f,%.2f", keyframe.type, keyframe.weightXZ, keyframe.weightY)
        if keyframe.angle ~= nil then
          keyframeString = keyframeString .. string.format(",%.2f", keyframe.angle)
        end
        table.insert(keyframeStrings, keyframeString)
      end
      Log:info(string.format("Preset: %s %s %s", typeName, category, table.concat(keyframeStrings, " ")))
    end
  end
end

function CabCinematic:consoleCommandSetHotPreset(typeName, category, ...)
  local keyframeStrings = { ... }

  if not typeName or not category or #keyframeStrings == 0 then
    Log:warning(
      "Usage: ccSetHotPreset <typeName> <category> <keyframe1> ... (keyframe format: type,weightXZ,weightY,angle)")
    return
  end

  local keyframes = {}

  for i, keyframeString in ipairs(keyframeStrings) do
    local parts = {}
    for part in string.gmatch(keyframeString, "[^,]+") do
      table.insert(parts, string.match(part, "^%s*(.-)%s*$"))
    end

    if #parts < 3 then
      Log:warning(string.format("Invalid keyframe format '%s' (expected at least 3 parts: type,weightXZ,weightY)",
        keyframeString))
      return
    end

    local keyframe = {
      type = parts[1],
      weightXZ = tonumber(parts[2]),
      weightY = tonumber(parts[3])
    }

    if parts[4] then
      keyframe.angle = tonumber(parts[4])
    end

    if not keyframe.weightXZ or not keyframe.weightY then
      Log:warning(string.format("Invalid numeric values in keyframe '%s'", keyframeString))
      return
    end

    table.insert(keyframes, keyframe)
  end

  local sumWeightXZ = 0
  local sumWeightY = 0
  for _, kf in ipairs(keyframes) do
    sumWeightXZ = sumWeightXZ + kf.weightXZ
    sumWeightY = sumWeightY + kf.weightY
  end

  if sumWeightXZ ~= 1.0 then
    Log:warning(string.format("Total weightXZ %.2f differs from 1.0", sumWeightXZ))
  end

  if sumWeightY ~= 1.0 then
    Log:warning(string.format("Total weightY %.2f differs from 1.0", sumWeightY))
  end

  CabCinematicAnimation.PRESETS[typeName] = CabCinematicAnimation.PRESETS[typeName] or {}
  CabCinematicAnimation.PRESETS[typeName][category] = keyframes
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
