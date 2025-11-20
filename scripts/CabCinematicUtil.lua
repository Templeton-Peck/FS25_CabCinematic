CabCinematicUtil = {}

function CabCinematicUtil.getNodeDistance2D(nodeA, nodeB)
  local xA, zA = getWorldTranslation(nodeA)
  local xB, zB = getWorldTranslation(nodeB)
  return MathUtil.vector2Length(xA - xB, zA - zB)
end

function CabCinematicUtil.getNodeDistance3D(nodeA, nodeB)
  local xA, yA, zA = getWorldTranslation(nodeA)
  local xB, yB, zB = getWorldTranslation(nodeB)
  return MathUtil.vector3Length(xA - xB, yA - yB, zA - zB)
end

function CabCinematicUtil.raycastVehicle(vehicle, sx, sy, sz, vx, vy, vz, dist)
  local dx, dy, dz = MathUtil.vector3Normalize(vx - sx, vy - sy, vz - sz)

  local raycast = {
    hit = false,
    hitX = sx,
    hitY = sy,
    hitZ = sz,
    callback = function(self, hitObjectId, x, y, z)
      if hitObjectId == vehicle.rootNode then
        self.hitX = x
        self.hitY = y
        self.hitZ = z
        return false
      end

      return true
    end
  };

  raycastAll(sx, sy, sz, dx, dy, dz, dist, "callback", raycast, CollisionFlag.VEHICLE)

  return raycast.hit, raycast.hitX, raycast.hitY, raycast.hitZ
end
