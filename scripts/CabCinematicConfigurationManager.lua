--- @class CabCinematicConfigurationManager
--- Load and manage cinematic configurations for vehicles from XML files.
CabCinematicConfigurationManager = {}
local CabCinematicConfigurationManager_mt = Class(CabCinematicConfigurationManager)

local XML_CONFIGURATION_KEY = "Configurations.Configuration"

function CabCinematicConfigurationManager.new()
  local self = setmetatable({}, CabCinematicConfigurationManager_mt)
  self.configurations = {}
  return self
end

function CabCinematicConfigurationManager:registerXmlSchema()
  self.xmlSchema = XMLSchema.new("configurations")
  self.xmlSchema:register(XMLValueType.STRING, XML_CONFIGURATION_KEY .. "(?)#vehicleName", "Configuration vehicle name")
  self.xmlSchema:register(XMLValueType.STRING, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#name", "Position name")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#x", "Position x coordinate")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#y", "Position y coordinate")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#z", "Position z coordinate")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#xOffset", "Position x offset")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#yOffset", "Position y offset")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).Positions.Position(?)#zOffset", "Position z offset")
  self.xmlSchema:register(XMLValueType.STRING, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints#after", "Keyframe waypoints after position")
  self.xmlSchema:register(XMLValueType.STRING, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#name", "Keyframe waypoint name")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#x", "Keyframe waypoint x coordinate")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#y", "Keyframe waypoint y coordinate")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#z", "Keyframe waypoint z coordinate")
end

function CabCinematicConfigurationManager:loadPosition(xmlFile, element)
  return {
    name = xmlFile:getValue(element .. "#name"),
    x = xmlFile:getValue(element .. "#x"),
    y = xmlFile:getValue(element .. "#y"),
    z = xmlFile:getValue(element .. "#z"),
    xOffset = xmlFile:getValue(element .. "#xOffset"),
    yOffset = xmlFile:getValue(element .. "#yOffset"),
    zOffset = xmlFile:getValue(element .. "#zOffset"),
  }
end

function CabCinematicConfigurationManager:loadKeyframeWaypoint(xmlFile, element)
  return {
    name = xmlFile:getValue(element .. "#name"),
    x = xmlFile:getValue(element .. "#x"),
    y = xmlFile:getValue(element .. "#y"),
    z = xmlFile:getValue(element .. "#z"),
  }
end

function CabCinematicConfigurationManager:loadConfiguration(xmlFile, element)
  local vehicleName = xmlFile:getValue(element .. "#vehicleName")
  local configuration = CabCinematicConfiguration.new()

  -- Load configuration <Positions>
  local positionsElement = element .. ".Positions"
  if xmlFile:hasProperty(positionsElement) then
    xmlFile:iterate(positionsElement .. ".Position", function(ix, positionElement)
      local position = self:loadPosition(xmlFile, positionElement)
      configuration:addPosition(position.name, position)
    end)
  end

  -- Load configuration <KeyframeWaypoints>
  local keyframeWaypointsElement = element .. ".KeyframeWaypoints"
  if xmlFile:hasProperty(keyframeWaypointsElement) then
    local keyframeWaypointsAfter = xmlFile:getValue(keyframeWaypointsElement .. "#after")
    local waypoints = {}
    xmlFile:iterate(keyframeWaypointsElement .. ".KeyframeWaypoint", function(ix, keyframeWaypointElement)
      local keyframeWaypoint = self:loadKeyframeWaypoint(xmlFile, keyframeWaypointElement)
      table.insert(waypoints, keyframeWaypoint)
    end)

    configuration:setKeyframeWaypoints(keyframeWaypointsAfter, waypoints)
  end

  self.configurations[vehicleName] = configuration
end

function CabCinematicConfigurationManager:loadXmlFile(fileName)
  local xmlFile = XMLFile.loadIfExists("configurationsXmlFile", fileName, self.xmlSchema)
  if xmlFile then
    xmlFile:iterate(XML_CONFIGURATION_KEY, function(ix, key)
      self:loadConfiguration(xmlFile, key)
    end)
    xmlFile:delete()
  else
    Log:error('Vehicle configuration file %s does not exist.', fileName)
  end
end

function CabCinematicConfigurationManager:load()
  self.configurations = {}
  self.xmlFileName = Utils.getFilename('resources/Configurations.xml', CabCinematic.dir)
  self:registerXmlSchema()
  self.xmlFile = self:loadXmlFile(self.xmlFileName)
end

function CabCinematicConfigurationManager:reload()
  self:load()
end

function CabCinematicConfigurationManager:get(vehicle)
  Log:info("Getting configuration for vehicle (configFileName: %s, configFileNameClean: %s, custom environment: %s)", vehicle.configFileName, vehicle.configFileNameClean, vehicle.customEnvironment)
  return self.configurations[vehicle.configFileNameClean]
end
