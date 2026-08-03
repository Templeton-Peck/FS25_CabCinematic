--- Compatibility adapter for FS25_CabView.
--- Suppresses CabView's one-shot enter view reset during cinematic enter.
--- Free look until the seat keyframe, then soft-clamps yaw to 90deg so CabView
--- auto-lean does not shift the seat on handoff.
CabViewCompatibility = {
  modName = "FS25_CabView",

  --- Radians per second toward the 90deg cabin look limit
  YAW_CLAMP_RATE = 1.2,

  --- Vehicles currently soft-clamping cabin yaw (enter seat phase / post-handoff)
  yawClampVehicles = {},

  isAvailable = function()
    return ModHelper.getModClass("FS25_CabView", "CabView") ~= nil
  end,

  --- @param vehicle table
  --- @return table|nil
  getSpec = function(vehicle)
    local CabView = ModHelper.getModClass("FS25_CabView", "CabView")
    if CabView == nil or CabView.specName == nil or vehicle == nil then
      return nil
    end

    return vehicle[CabView.specName]
  end,

  --- @param vehicle table
  --- @param enabled boolean
  setYawClampActive = function(vehicle, enabled)
    if vehicle == nil then
      return
    end

    if enabled then
      CabViewCompatibility.yawClampVehicles[vehicle] = true
    else
      CabViewCompatibility.yawClampVehicles[vehicle] = nil
    end
  end,

  --- @param vehicle table
  --- @return boolean
  isYawClampActive = function(vehicle)
    return vehicle ~= nil and CabViewCompatibility.yawClampVehicles[vehicle] == true
  end,

  --- CabView look angle in [-pi, pi], 0 = facing cabin forward
  --- @param camera table VehicleCamera
  --- @param cabViewSpec table
  --- @return number|nil
  getLookAngle = function(camera, cabViewSpec)
    if camera == nil or camera.rotY == nil or cabViewSpec == nil then
      return nil
    end

    return math.clamp(camera.rotY - (math.pi + (cabViewSpec.rotationOffset or 0)), -math.pi, math.pi)
  end,

  --- Soft-clamps indoor camera yaw toward 90deg from cabin forward.
  --- @param vehicle table
  --- @param dt number
  --- @return boolean isWithinLimit true when yaw is already inside 90deg
  applyYawClamp = function(vehicle, dt)
    local cabViewSpec = CabViewCompatibility.getSpec(vehicle)
    local indoorCamera = vehicle.getIndoorCamera ~= nil and vehicle:getIndoorCamera() or nil
    if cabViewSpec == nil or indoorCamera == nil then
      return true
    end

    local angle = CabViewCompatibility.getLookAngle(indoorCamera, cabViewSpec)
    if angle == nil then
      return true
    end

    local maxAngle = math.pi * 0.5
    if math.abs(angle) <= maxAngle then
      return true
    end

    local targetAngle = angle > 0 and maxAngle or -maxAngle
    local maxStep = CabViewCompatibility.YAW_CLAMP_RATE * (dt / 1000.0)
    local delta = targetAngle - angle
    if math.abs(delta) <= maxStep then
      angle = targetAngle
    else
      angle = angle + maxStep * (delta > 0 and 1 or -1)
    end

    indoorCamera.rotY = angle + math.pi + (cabViewSpec.rotationOffset or 0)
    indoorCamera:updateRotateNodeRotation()

    return math.abs(angle) <= maxAngle + 0.001
  end,

  --- @param vehicle table
  onEnterAnimationBeforeStart = function(vehicle)
    local spec = CabViewCompatibility.getSpec(vehicle)
    if spec ~= nil then
      spec.resetView = false
    end

    CabViewCompatibility.setYawClampActive(vehicle, false)
  end,

  --- Fired when the enter animation reaches the SIT keyframe.
  --- @param vehicle table
  onEnterAnimationSeat = function(vehicle)
    CabViewCompatibility.setYawClampActive(vehicle, true)
  end,

  --- Called every frame; no-ops unless this vehicle has an active yaw clamp.
  --- @param vehicle table
  --- @param dt number
  onEnterAnimationUpdate = function(vehicle, dt)
    if not CabViewCompatibility.isYawClampActive(vehicle) then
      return
    end

    local withinLimit = CabViewCompatibility.applyYawClamp(vehicle, dt)
    local animationOngoing = vehicle.getIsCabCinematicAnimationOngoing ~= nil and vehicle:getIsCabCinematicAnimationOngoing()
    if withinLimit and not animationOngoing then
      CabViewCompatibility.setYawClampActive(vehicle, false)
    end
  end,

  --- Keep clamping after sit handoff if the player still looks past 90deg.
  --- @param vehicle table
  onEnterAnimationEnd = function(vehicle)
    local cabViewSpec = CabViewCompatibility.getSpec(vehicle)
    local indoorCamera = vehicle.getIndoorCamera ~= nil and vehicle:getIndoorCamera() or nil
    local angle = CabViewCompatibility.getLookAngle(indoorCamera, cabViewSpec)
    CabViewCompatibility.setYawClampActive(vehicle, angle ~= nil and math.abs(angle) > math.pi * 0.5)
  end,

  --- @param vehicle table
  onLeaveAnimationBeforeStart = function(vehicle)
    CabViewCompatibility.setYawClampActive(vehicle, false)
  end,
}
