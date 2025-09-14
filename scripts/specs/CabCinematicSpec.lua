CabCinematicSpec = {}

local function isNear(originNode, targetNode, distance)
  if not originNode or originNode == 0 or not targetNode or targetNode == 0 then
    return false
  end

  local ox, oy, oz = getWorldTranslation(originNode)
  local tx, ty, tz = getWorldTranslation(targetNode)

  local dx = tx - ox
  local dy = ty - oy
  local dz = tz - oz
  local distanceSquared = dx * dx + dy * dy + dz * dz

  return distanceSquared <= (distance * distance)
end

function CabCinematicSpec.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function CabCinematicSpec.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "interact", CabCinematicSpec.interact)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "onPlayerEnterVehicle",
    CabCinematicSpec.onPlayerEnterVehicle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "onPlayerLeaveVehicle",
    CabCinematicSpec.onPlayerLeaveVehicle)
end

function CabCinematicSpec.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "debugCameras", CabCinematicSpec.debugCameras)
end

function CabCinematicSpec.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabCinematicSpec)
end

function CabCinematicSpec:debugCameras()
  local spec = self.spec_enterable
  local function getVehicleInteriorCamera()
    if spec and spec.cameras then
      for _, camera in ipairs(spec.cameras) do
        if camera.isInside then return camera end
      end
    end

    return nil
  end

  local function getPlayerCamera()
    return g_localPlayer.camera
  end

  local vehicleCamera = getVehicleInteriorCamera();
  local playerCamera = getPlayerCamera();

  local rx, ry, rz = getRotation(playerCamera.rotateNode)
  Log:info(string.format("Player camera rotation (rx, ry, rz): (%.2f, %.2f, %.2f)", rx, ry, rz))

  -- -- local orx, ory, orz = playerCamera:getRotation()
  -- -- Log:info(string.format("orx, ory, orz : (%.2f, %.2f, %.2f)", orx, ory, orz))
  -- -- Log:info(string.format("rotX, rotY, rotZ : (%.2f, %.2f, %.2f)", vehicleCamera.rotX, vehicleCamera.rotY,
  -- --   vehicleCamera.rotZ))

  -- -- local worx1, wory1, worz1 = getWorldRotation(playerCamera.cameraRootNode)
  -- -- Log:info(string.format("worx1, wory1, worz1 : (%.2f, %.2f, %.2f)", worx1, wory1, worz1))
  -- -- local wtrx1, wtry1, wrtz1 = getWorldRotation(vehicleCamera.rotateNode)
  -- -- Log:info(string.format("wtrx1, wtry1, wrtz1 : (%.2f, %.2f, %.2f)", wtrx1, wtry1, wrtz1))

  -- -- local trx1, try1, trz1 = localRotationToLocal(playerCamera.cameraRootNode, getCameraId(vehicleCamera), orx, ory, orz)
  -- -- Log:info(string.format("trx1, try1, trz1 : (%.2f, %.2f, %.2f)", trx1, try1, trz1))
  -- -- local trx2, try2, trz2 = worldRotationToLocal(vehicleCamera.rotateNode, worx1, wory1, worz1)
  -- -- Log:info(string.format("trx2, try2, trz2 : (%.2f, %.2f, %.2f)", trx2, try2, trz2))

  -- --local odx, ody, odz = getDirection(playerCamera.cameraRootNode, 0, 0, 1)
  -- local wodx, wody, wodz = localDirectionToWorld(playerCamera.cameraRootNode, 0, 0, 1)

  -- --local tdx, tdy, tdz = getDirection(getCameraId(vehicleCamera), 0, 0, 1)
  -- local wtdx, wtdy, wtdz = localDirectionToWorld(vehicleCamera.rotateNode, 0, 0, 1)

  -- local diroX, _, diroZ = localDirectionToWorld(playerCamera.cameraRootNode, 0, 0, -1)
  -- diroX, _, diroZ = MathUtil.vector3Normalize(diroX, 0, diroZ)
  -- local dirtX, _, dirtZ = localDirectionToWorld(vehicleCamera.rotateNode, 0, 0, -1)
  -- dirtX, _, dirtZ = MathUtil.vector3Normalize(dirtX, 0, dirtZ)

  -- --Log:info(string.format("odx, ody, odz : (%.2f, %.2f, %.2f)", odx, ody, odz))
  -- Log:info(string.format("wodx, wody, wodz : (%.2f, %.2f, %.2f)", wodx, wody, wodz))
  -- --Log:info(string.format("tdx, tdy, tdz : (%.2f, %.2f, %.2f)", tdx, tdy, tdz))
  -- Log:info(string.format("wtdx, wtdy, wtdz : (%.2f, %.2f, %.2f)", wtdx, wtdy, wtdz))
  -- Log:info(string.format("diroX, dirZ : (%.2f, %.2f)", diroX, diroZ))
  -- Log:info(string.format("dirtX, dirtZ : (%.2f, %.2f)", dirtX, dirtZ))
end

function CabCinematicSpec:interact(superFunc, player)
  if CabCinematic:getIsActive() then
    return
  end

  local isPlayerNearVehicleExitNode = isNear(player.rootNode, self:getExitNode(), 0.5)
  Log:info(string.format("CabCinematicSpec:interact called : %s", tostring(isPlayerNearVehicleExitNode)))

  if isPlayerNearVehicleExitNode then
    return superFunc(self, player)
  end
end

function CabCinematicSpec:onPlayerEnterVehicle(superFunc, isControlling, playerStyle, farmId, userId)
  Log:info("CabCinematicSpec:onPlayerEnterVehicle called")
  if CabCinematic:getIsActive() then
    return
  end

  return CabCinematic:startEnterAnimation(self, function()
    return superFunc(self, isControlling, playerStyle, farmId, userId)
  end)
end

function CabCinematicSpec:onPlayerLeaveVehicle(superFunc)
  Log:info("CabCinematicSpec:onPlayerLeaveVehicle called")
  if CabCinematic:getIsActive() then
    return
  end

  superFunc(self)

  return CabCinematic:startLeaveAnimation(self, function()
    return g_localPlayer.camera:makeCurrent()
  end)
end

function CabCinematicSpec:onLoad()
  local spec                 = {}
  self.spec_cabCinematicSpec = spec
end
