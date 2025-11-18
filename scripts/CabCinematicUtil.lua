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
