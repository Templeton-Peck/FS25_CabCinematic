--- @class CabCinematicConfigurationManager
--- Load and manage cinematic configurations for vehicles from XML files.
CabCinematicConfigurationManager = {}
local CabCinematicConfigurationManager_mt = Class(CabCinematicConfigurationManager)

local XML_CONFIGURATION_KEY = "Configurations.Configuration"

--- Create a new instance of CabCinematicConfigurationManager.
--- @return CabCinematicConfigurationManager
function CabCinematicConfigurationManager.new()
  local self = setmetatable({}, CabCinematicConfigurationManager_mt)
  self.configurations = {}
  return self
end

--- Deletes the configuration manager, clearing all configurations and XML schema.
function CabCinematicConfigurationManager:delete()
  self:deleteConfigurations()
  self.configurations = nil
end

--- Deletes all configurations, clearing the configurations table.
function CabCinematicConfigurationManager:deleteConfigurations()
  for vehicleName, configuration in pairs(self.configurations) do
    configuration:delete()
    self.configurations[vehicleName] = nil
  end
end

--- Registers the XML schema for loading configurations, defining the expected structure and types of the XML file.
--- This method should be called before loading any XML files to ensure proper validation and parsing of the configuration data.
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
  self.xmlSchema:register(XMLValueType.STRING, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#type", "Keyframe waypoint type")
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#xOffset", "Keyframe waypoint x offset", 0)
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#yOffset", "Keyframe waypoint y offset", 0)
  self.xmlSchema:register(XMLValueType.FLOAT, XML_CONFIGURATION_KEY .. "(?).KeyframeWaypoints.KeyframeWaypoint(?)#zOffset", "Keyframe waypoint z offset", 0)
end

--- Loads a position from the XML file, extracting the relevant attributes and returning a position table.
--- @param xmlFile XMLFile The XML file to load the position from.
--- @param element string The XML element path to the position.
--- @return table Table containing the position's name, coordinates, and offsets.
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

--- Loads a keyframe waypoint from the XML file, extracting the relevant attributes and returning a keyframe waypoint table.
--- @param xmlFile XMLFile The XML file to load the keyframe waypoint from.
--- @param element string The XML element path to the keyframe waypoint.
--- @return table Table containing the keyframe waypoint's type and offsets.
function CabCinematicConfigurationManager:loadKeyframeWaypoint(xmlFile, element)
  return {
    type = xmlFile:getValue(element .. "#type"),
    offsets = {
      xmlFile:getValue(element .. "#xOffset"),
      xmlFile:getValue(element .. "#yOffset"),
      xmlFile:getValue(element .. "#zOffset"),
    }
  }
end

--- Loads a configuration for a vehicle from the XML file, including its named positions and keyframe waypoints, and stores it in the configurations table.
--- @param xmlFile XMLFile The XML file to load the configuration from.
--- @param element string The XML element path to the configuration.
function CabCinematicConfigurationManager:loadConfiguration(xmlFile, element)
  local vehicleName = xmlFile:getValue(element .. "#vehicleName")
  local configuration = CabCinematicConfiguration.new()

  -- Load configuration <Positions>
  local positionsElement = element .. ".Positions"
  if xmlFile:hasProperty(positionsElement) then
    xmlFile:iterate(positionsElement .. ".Position", function(ix, positionElement)
      local position = self:loadPosition(xmlFile, positionElement)
      configuration:addPosition(position)
    end)
  end

  -- Load configuration <KeyframeWaypoints>
  local keyframeWaypointsElement = element .. ".KeyframeWaypoints"
  if xmlFile:hasProperty(keyframeWaypointsElement) then
    xmlFile:iterate(keyframeWaypointsElement .. ".KeyframeWaypoint", function(ix, keyframeWaypointElement)
      local keyframeWaypoint = self:loadKeyframeWaypoint(xmlFile, keyframeWaypointElement)
      configuration:addKeyframeWaypoint(keyframeWaypoint)
    end)
  end

  self.configurations[vehicleName] = configuration
end

--- Loads the XML file containing the configurations, iterating through each configuration element and loading it into the configurations table.
--- @param fileName string The path to the XML file to load.
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

--- Loads the configurations from the XML file, first deleting any existing configurations and then registering the XML schema before loading the file.
function CabCinematicConfigurationManager:load()
  self:deleteConfigurations()
  self.xmlFileName = Utils.getFilename('resources/configurations.xml', CabCinematic.dir)
  self:registerXmlSchema()
  self.xmlFile = self:loadXmlFile(self.xmlFileName)
end

--- Reloads the configurations allowing for dynamic updates to the configurations without restarting the game.
function CabCinematicConfigurationManager:reload()
  self:load()
end

--- Retrieves the configuration for the given vehicle based on its cleaned config file name, returning the corresponding configuration from the configurations table.
--- @param vehicle table The vehicle to retrieve the configuration for, expected to have a configFileNameClean field.
--- @return CabCinematicConfiguration | nil The configuration for the given vehicle, or nil if not found.
function CabCinematicConfigurationManager:get(vehicle)
  if vehicle.configFileNameClean == nil then
    return nil
  end

  return self.configurations[vehicle.configFileNameClean]
end
