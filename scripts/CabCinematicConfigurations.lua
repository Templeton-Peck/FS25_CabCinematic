--- @class CabCinematicConfigurations
--- Handle cinematic camera travel, keyframes and animation
CabCinematicConfigurations = {}
local CabCinematicConfigurations_mt = Class(CabCinematicConfigurations)

local XML_CONFIGURATION_KEY = "Configurations.Configuration"

function CabCinematicConfigurations.new()
  local self = setmetatable({}, CabCinematicConfigurations_mt)
  self.configurations = {}
  return self
end

function CabCinematicConfigurations:registerXmlSchema()
  self.xmlSchema = XMLSchema.new("configurations")
  self.xmlSchema:register(XMLValueType.STRING, XML_CONFIGURATION_KEY .. "(?)#vehicleName", "Configuration vehicle name")
end

function CabCinematicConfigurations:loadFromXml()
  self.configurations = {}
  self.xmlFileName = Utils.getFilename('resources/Configurations.xml', CabCinematic.dir)
  self:registerXmlSchema()
  self.xmlFile = self:loadXmlFile(self.xmlFileName)
end

function CabCinematicConfigurations:loadPosition(xmlFile, element)
  return {
    name = xmlFile:getValue(element .. "#name"),
    x = xmlFile:getValue(element .. "(?)#x"),
    y = xmlFile:getValue(element .. "(?)#y"),
    z = xmlFile:getValue(element .. "(?)#z"),
    xOffset = xmlFile:getValue(element .. "(?)#xOffset"),
    yOffset = xmlFile:getValue(element .. "(?)#yOffset"),
    zOffset = xmlFile:getValue(element .. "(?)#zOffset"),
  }
end

function CabCinematicConfigurations:loadKeyframeWaypoint(xmlFile, element)
  return {
    name = xmlFile:getValue(element .. "#name"),
    x = xmlFile:getValue(element .. "#x"),
    y = xmlFile:getValue(element .. "#y"),
    z = xmlFile:getValue(element .. "#z"),
  }
end

function CabCinematicConfigurations:loadConfiguration(xmlFile, element)
  local vehicleName = xmlFile:getValue(element .. "#vehicleName")
  local configuration = {
    positions = {},
    keyframeWaypointsAfter = nil,
    keyframeWaypoints = {}
  }

  -- Load configuration <Positions>
  local positionsElement = element .. ".Positions"
  if xmlFile:hasProperty(positionsElement) then
    xmlFile:iterate(positionsElement .. ".Position", function(ix, positionElement)
      local position = self:loadPosition(xmlFile, positionElement)
      table.insert(configuration.positions, position)
    end)
  end

  -- Load configuration <KeyframeWaypoints>
  local keyframeWaypointsElement = element .. ".KeyframeWaypoints"
  if xmlFile:hasProperty(keyframeWaypointsElement) then
    configuration.keyframeWaypointsAfter = xmlFile:getValue(keyframeWaypointsElement .. "#after")
    xmlFile:iterate(keyframeWaypointsElement .. ".KeyframeWaypoint", function(ix, keyframeWaypointElement)
      local keyframeWaypoint = self:loadKeyframeWaypoint(xmlFile, keyframeWaypointElement)
      table.insert(configuration.keyframeWaypoints, keyframeWaypoint)
    end)
  end

  self.configurations[vehicleName] = configuration
end

function CabCinematicConfigurations:loadXmlFile(fileName)
  local xmlFile = XMLFile.loadIfExists("configurationsXmlFile", fileName, self.xmlSchema)
  if xmlFile then
    xmlFile:iterate(XML_CONFIGURATION_KEY, function(ix, key)
      self:loadConfiguration(xmlFile, key)
    end)
    xmlFile:delete()
  else
    Log.error('Vehicle configuration file %s does not exist.', fileName)
  end
end

function CabCinematicConfigurations:get(vehicleName)
  return self.configurations[vehicleName]
end
