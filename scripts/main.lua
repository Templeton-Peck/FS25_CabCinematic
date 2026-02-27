CabCinematic = Mod:init({})

CabCinematic:addSpecialization("cabCinematic", function(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end)

function CabCinematic:startMission()
  g_localPlayer.targeter:addTargetType(CabCinematic, CollisionFlag.VEHICLE, 0.1, CabCinematicUtil.VEHICLE_INTERACT_DISTANCE)
  g_localPlayer.targeter:addFilterToTargetType(CabCinematic, function(hitNode)
    if hitNode ~= nil and hitNode ~= 0 and CollisionFlag.getHasGroupFlagSet(hitNode, CollisionFlag.VEHICLE) then
      local vehicle = g_currentMission:getNodeObject(hitNode)
      if vehicle ~= nil then
        vehicle = vehicle.rootVehicle or vehicle

        if g_currentMission.interactiveVehicleInRange ~= nil then
          g_currentMission.interactiveVehicleInRange.interactionFlag = Vehicle.INTERACTION_FLAG_NONE
        end

        g_currentMission.interactiveVehicleInRange = vehicle
        g_currentMission.interactiveVehicleInRange.interactionFlag = Vehicle.INTERACTION_FLAG_ENTERABLE
      end
    end

    return true
  end)
end

function CabCinematic:delete()
end
