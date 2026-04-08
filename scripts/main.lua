CabCinematic = Mod:init({
  debugLevel = 0,
  configurationManager = CabCinematicConfigurationManager.new()
})

CabCinematic:addSpecialization("cabCinematic", function(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end)

function CabCinematic:beforeLoadMap()
  addConsoleCommand("ccDebug", "Toggle cab cinematic debug and set level (default: 1)", "onDebugConsoleCommand", self)
  addConsoleCommand("ccInvalidateAnalysis", "Invalidate the current vehicle analysis", "onInvalidateAnalysisConsoleCommand", self)
  addConsoleCommand("ccReloadConfigurations", "Reload the vehicle configurations", "onReloadConfigurationsConsoleCommand", self)
end

function CabCinematic:loadMap()
  self.configurationManager:load()
end

function CabCinematic:startMission()
  g_localPlayer.targeter:addTargetType(CabCinematic, CollisionFlag.VEHICLE, 0.1, CabCinematicUtil.VEHICLE_TARGET_DISTANCE)
  g_localPlayer.targeter:addFilterToTargetType(CabCinematic, function(hitNode)
    if hitNode ~= nil and hitNode ~= 0 and CollisionFlag.getHasGroupFlagSet(hitNode, CollisionFlag.VEHICLE) then
      local vehicle = g_currentMission:getNodeObject(hitNode)
      if vehicle ~= nil then
        vehicle = vehicle.spec_enterable ~= nil and vehicle or vehicle:getRootVehicle()

        if g_currentMission.interactiveVehicleInRange ~= nil then
          g_currentMission.interactiveVehicleInRange.interactionFlag = Vehicle.INTERACTION_FLAG_NONE
        end

        g_currentMission.interactiveVehicleInRange = vehicle
        g_currentMission.interactiveVehicleInRange.interactionFlag = Vehicle.INTERACTION_FLAG_ENTERABLE
        g_localPlayer.targetedVehicle = vehicle
      end
    end

    return true
  end)
end

function CabCinematic:draw()
  if self.debugLevel > 0 then
    local vehicle = g_localPlayer.targetedVehicle
    if vehicle ~= nil and vehicle.drawCabCinematicDebug ~= nil then
      vehicle:drawCabCinematicDebug()
    end
  end
end

function CabCinematic:delete()
  removeConsoleCommand("ccDebug")
  removeConsoleCommand("ccInvalidateAnalysis")
  removeConsoleCommand("ccReloadConfigurations")

  self.configurationManager:delete()
end

function CabCinematic:onDebugConsoleCommand(level)
  if level == nil then
    self.debugLevel = self.debugLevel > 0 and 0 or 1
  else
    self.debugLevel = tonumber(level) or 0
  end
end

function CabCinematic:onInvalidateAnalysisConsoleCommand()
  local vehicle = g_localPlayer.targetedVehicle or g_localPlayer:getCurrentVehicle()
  if vehicle ~= nil and vehicle.spec_cabCinematic ~= nil then
    self:onReloadConfigurationsConsoleCommand()
    vehicle:invalidateCabCinematicAnalysisCache()
    Log:info("Invalidated analysis for targeted vehicle: %s", vehicle:getFullName())
  else
    Log:info("No targeted or current vehicle")
  end
end

function CabCinematic:onReloadConfigurationsConsoleCommand()
  self.configurationManager:reload()
  Log:info("Reloaded vehicle configurations")
end

PlayerCamera.makeCurrent = Utils.overwrittenFunction(PlayerCamera.makeCurrent, function(playerCamera, superFunc, ...)
  local vehicle = playerCamera.player:getCurrentVehicle()
  if vehicle ~= nil and vehicle.spec_cabCinematic ~= nil and vehicle:getIsCabCinematicAnimationOngoing() then
    return
  end

  return superFunc(playerCamera, ...)
end)
