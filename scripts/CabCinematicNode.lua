CabCinematicNode = {
  vehicle = nil,
  node = nil,
}

local CabCinematicNode_mt = Class(CabCinematicNode)
function CabCinematicNode.new(name, vehicle, parentNode)
  local self = setmetatable({}, CabCinematicNode_mt)
  self.vehicle = vehicle
  self.node = createTransformGroup("cc_" .. name .. "Node")
  link(parentNode, self.node)
  setTranslation(self.node, 0, 0, 0)
  setRotation(self.node, 0, 0, 0)
  return self
end

function CabCinematicNode.newFrameNode(name, vehicle)
  local nodesParents = vehicle:getCabCinematicNodesParents()
  return CabCinematicNode.new(name, vehicle, nodesParents.frameRoot)
end

function CabCinematicNode.newCabNode(name, vehicle)
  local nodesParents = vehicle:getCabCinematicNodesParents()
  return CabCinematicNode.new(name, vehicle, nodesParents.cabRoot)
end

function CabCinematicNode:delete()
  unlink(self.node)
  delete(self.node)
  self.node = nil
  self.vehicle = nil
end

function CabCinematicNode:setTranslation(translation)
  setTranslation(self.node, unpack(translation))
  return self
end

function CabCinematicNode:setRotation(rotation)
  setRotation(self.node, unpack(rotation))
  return self
end

function CabCinematicNode:setVehicleTranslation(translation)
  local parentNode = getParent(self.node)
  if parentNode ~= self.vehicle.rootNode then
    translation = { localToLocal(self.vehicle.rootNode, parentNode, unpack(translation)) }
  end

  setTranslation(self.node, unpack(translation))
  return self
end

function CabCinematicNode:setVehicleRotation(rotation)
  local parentNode = getParent(self.node)
  if parentNode ~= self.vehicle.rootNode then
    rotation = { localRotationToLocal(self.vehicle.rootNode, parentNode, unpack(rotation)) }
  end

  setRotation(self.node, unpack(rotation))
  return self
end

function CabCinematicNode:getTranslation()
  return { getTranslation(self.node) }
end

function CabCinematicNode:getRotation()
  return { getRotation(self.node) }
end

function CabCinematicNode:getVehicleTranslation()
  local x, y, z = getTranslation(self.node)

  local parentNode = getParent(self.node)
  if parentNode ~= self.vehicle.rootNode then
    return { localToLocal(parentNode, self.vehicle.rootNode, x, y, z) }
  end

  return { x, y, z }
end

function CabCinematicNode:getVX()
  return self:getVehicleTranslation()[1]
end

function CabCinematicNode:getVY()
  return self:getVehicleTranslation()[2]
end

function CabCinematicNode:getVZ()
  return self:getVehicleTranslation()[3]
end

function CabCinematicNode:getVehicleRotation()
  local rx, ry, rz = getRotation(self.node)

  local parentNode = getParent(self.node)
  if parentNode ~= self.vehicle.rootNode then
    return { localRotationToLocal(parentNode, self.vehicle.rootNode, rx, ry, rz) }
  end

  return { rx, ry, rz }
end

function CabCinematicNode:drawDebug()
  DebugUtil.drawDebugNode(self.node, getName(self.node));
end
