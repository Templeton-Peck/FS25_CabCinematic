--[[

ModHelper (Weezls Mod Lib for FS22) - Simplifies the creation of script based mods for FS22

This utility class acts as a wrapper for Farming Simulator script based mods. It hels with setting up the mod up and 
acting as a "bootstrapper" for the main mod class/table. It also add additional utility functions for sourcing additonal files, 
manage user settings, assist debugging etc.

See ModHelper.md (search my GitHub page for it since Giants won't allow "links" in the scripts) for documentation and more details.

Author:     w33zl (https://github.com/w33zl)
Version:    2.2.0
Modified:   2023-08-07

Changelog:
v2.0        FS22 version
v1.0        Initial public release

License:    CC BY-NC-SA 4.0
This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or 
format for noncommercial purposes only, and only so long as attribution is given to the creator.
If you remix, adapt, or build upon the material, you must license the modified material under identical terms. 

]]



--[[

USAGE:

YourModName = Mod:init()

-- Logging and debugging (don't forget to add 'scripts/ModLib/LogHelper.lua' to <extraSourceFiles>)
--* debug(), var() and trace() will only print anything in the log if the file 'scripts/ModLib/DebugHelper.lua' is in your mod folder/zip archive
Log:debug("This is a debug message")
Log:var("name", "value")
Log:trace("This is a trace message")
Log:info("This is an info message")
Log:warning("This is a warning message")
Log:error("This is an error message")

-- Events
function YourModName:beforeLoadMap() end -- Super early event, caution!
function YourModName:loadMap(filename) end -- Executed when the map has finished loading, a good place to begin your mod initialization
function YourModName:beforeStartMission() end -- When user selects "Start" (but as early as possible in that event chain)
function YourModName:startMission() end -- When user selects "Start"
function YourModName:update(dt) end -- Looped as long game is running (CAUTION! Can severely impact performance if not used properly)

]]

local deprecatedMessages = {}
local function deprecated(functionName, replacementMessage, justOnce)
    justOnce = justOnce or false
    if justOnce and deprecatedMessages[functionName] then
        return
    end
    printWarning(string.format("WARNING: [DEPRECATED] Function '%s' is marked as deprecated, please use %s instead", functionName, replacementMessage))
    deprecatedMessages[functionName] = true
end

-- This will create the "Mod" base class (and effectively reset any previous references to other mods) 
Mod = {

    debugMode = false,

    -- printInternal = function(self, category, message, ...)
    --     message = (message ~= nil and message:format(...)) or ""
    --     if category ~= nil and category ~= "" then
    --         category = string.format(" %s:", category)
    --     else
    --         category = ""
    --     end
    --     print(string.format("[%s]%s %s", self.title, category, tostring(message)))
    -- end,

    -- printDebug = function(self, message, ...)
    --     deprecated("Mod:printDebug()", "Log:debug()", true)
    --     printCallstack()
    --     if self.debugMode == true then
    --         self:printInternal("DEBUG", message, ...)
    --     end
    -- end,

    -- printDebugVar = function(self, name, variable)
    --     deprecated("Mod:printDebugVar()", "Log:var()", true)
    --     if self.debugMode ~= true then
    --         return
    --     end

    --     -- local tt1 = (val or "")
    --     local valType = type(variable)
    
    --     if valType == "string" then
    --         variable = string.format( "'%s'", variable )
    --     end
    
    --     local text = string.format( "%s=%s [@%s]", name, tostring(variable), valType )
    --     self:printInternal("DBGVAR", text)
    -- end,
    
    -- printWarning = function(self, message, ...)
    --     deprecated("Mod:printWarning()", "Log:warning()", true)
    --     self:printInternal("Warning", message, ...)
    -- end,

    -- printError = function(self, message, ...)
    --     deprecated("Mod:printError()", "Log:error()", true)
    --     self:printInternal("Error", message, ...)
    -- end,

    -- getIsMultiplayer = function(self) return g_currentMission.missionDynamicInfo.isMultiplayer end,
    getIsServer = function(self) return g_currentMission.getIsServer() end,
    getIsClient = function(self) return g_currentMission.getIsClient() end,
    -- getIsDedicatedServer = function(self) return not self:getIsClient() and self:getIsServer() end, --g_dedicatedServer
    -- getIsMasterUser = function(self) return g_currentMission.isMasterUser end,
    -- getHasFarmAdminAccess = function(self) return g_currentMission:getHasPlayerPermission("farmManager") end,
    -- getIsValidFarmManager = function(self) return g_currentMission.player ~= nil and self:getHasFarmAdminAccess() and g_currentMission.player.farmId ~= FarmManager.SPECTATOR_FARM_ID end,
}
Mod_MT = {
}

-- SubModule = {
--     printInfo = function(message, ...) Mod:printInfo(message, ...) end,
--     printDebug = function(message, ...) Mod:printDebug(message) end,
--     printDebugVar = function(name, variable) Mod:printDebugVar(name, variable) end,
--     printWarning = function(message, ...) Mod:printWarning(message) end,
--     printError = function(message, ...) Mod:printError(message) end,
--     parent = nil,
-- }
-- SubModule_MT = {
-- }

local function getTrueGlobalG()
    return getmetatable(_G).__index
end



-- Set initial values for the global Mod object/"class"
Mod.dir = g_currentModDirectory
Mod.settingsDir = g_currentModSettingsDirectory
Mod.name = g_currentModName
Mod.mod = g_modManager:getModByName(Mod.name)
Mod.env = getfenv()
Mod.__g = getTrueGlobalG() --getfenv(0)  --NOTE: WARNING: USE WITH CAUTION!!
Mod.globalEnv = Mod.__g

-- Wrapper to copy the global (but temporary) g_current* vars into the mod's environment
--TODO: still needed in FS25?
Mod.env.g_currentModSettingsDirectory = Mod.settingsDir
Mod.env.g_currentModName = Mod.name
Mod.env.g_currentModDirectory = Mod.dir



local modDescXML = loadXMLFile("modDesc", Mod.dir .. "modDesc.xml");
Mod.title = getXMLString(modDescXML, "modDesc.title.en");
Mod.author = getXMLString(modDescXML, "modDesc.author");
Mod.version = getXMLString(modDescXML, "modDesc.version");
-- Mod.author = Mod.mod.author
-- Mod.version = Mod.mod.version
delete(modDescXML);

-- function Mod:printInfo(message, ...)
--     deprecated("Mod:printInfo()", "Log:info()", true)

--     self:printInternal("", message, ...)
-- end



-- Local aliases for convinience
-- local function printInfo(message) Mod:printInfo(message) end
-- local function printDebug(message) Mod:printDebug(message) end
-- local function printDebugVar(name, variable) Mod:printDebugVar(name, variable) end
-- local function printWarning(message) Mod:printWarning(message) end
-- local function printError(message) Mod:printError(message) end


-- Helper functions
local function validateParam(value, typeName, message)
    local failed = false
    failed = failed or (value == nil)
    failed = failed or (typeName ~= nil and type(value) ~= typeName)
    failed = failed or (type(value) == string and value == "")

    if failed then print(message) end

    return not failed
end

--TODO: replace with a new way of doing this?
local ModSettings = {};
ModSettings.__index = ModSettings;

function ModSettings:new(mod)
    local newModSettings = {};
    setmetatable(newModSettings, self);
    self.__index = self;
    newModSettings.__mod = mod;
    return newModSettings;
end
function ModSettings:init(name, defaultSettingsFileName, userSettingsFileName)
    if not validateParam(name, "string", "Parameter 'name' (#1) is mandatory and must contain a non-empty string") then
        return;
    end

    if defaultSettingsFileName == nil or type(defaultSettingsFileName) ~= "string" then 
        self.__mod.printError("Parameter 'defaultSettingsFileName' (#2) is mandatory and must contain a filename");
        return;
    end

    --TODO: change to this: g_currentModSettingsDirectory == /Documents/My Games/FarmingSimulator2022/modSettings/MOD_NAME/
    local modSettingsDir = getUserProfileAppPath() .. "modsSettings"

    self._config = {
        xmlNodeName = name,
        modSettingsDir = modSettingsDir,
        defaultSettingsFileName = defaultSettingsFileName,
        defaultSettingsPath = self.__mod.dir .. defaultSettingsFileName,
        userSettingsFileName = userSettingsFileName,
        userSettingsPath = modSettingsDir .. "/" .. userSettingsFileName,
    }


    return self;
end
function ModSettings:load(callback)
    if not validateParam(callback, "function", "Parameter 'callback' (#1) is mandatory and must contain a valid callback function") then
        return;
    end

    local defaultSettingsFile = self._config.defaultSettingsPath;
    local userSettingsFile = self._config.userSettingsPath;
    local xmlNodeName = self._config.xmlNodeName or "settings"

    if defaultSettingsFile == "" or userSettingsFile == "" then
        self.__mod.printError("Cannot load settings, neither a user settings nor a default settings file was supplied. Nothing to read settings from.");
        return;
    end

    local function executeXmlReader(xmlNodeName, fileName, callback)
        local xmlFile = loadXMLFile(xmlNodeName, fileName)

        if xmlFile == nil then
            printError("Failed to open/read settings file '" .. fileName .. "'!")
            return
        end

        local xmlReader = {
            xmlFile = xmlFile,
            xmlNodeName = xmlNodeName,
            
            getKey = function(self, categoryName, valueName)
                local xmlKey = self.xmlNodeName

                
                if categoryName ~= nil and categoryName ~= "" then 
                    xmlKey = xmlKey .. "." .. categoryName
                end

                xmlKey = xmlKey .. "." .. valueName
                
                return xmlKey
            end,

            readBool = function(self, categoryName, valueName, defaultValue)
                return Utils.getNoNil(getXMLBool(self.xmlFile, self:getKey(categoryName, valueName)), defaultValue or false)
            end,
            readFloat = function(self, categoryName, valueName, defaultValue)
                return Utils.getNoNil(getXMLFloat(self.xmlFile, self:getKey(categoryName, valueName)), defaultValue or 0.0)
            end,
            readString = function(self, categoryName, valueName, defaultValue)
                return Utils.getNoNil(getXMLString(self.xmlFile, self:getKey(categoryName, valueName)), defaultValue or "")
            end,

        }
        callback(xmlReader);
    end

    if fileExists(defaultSettingsFile) then
        executeXmlReader(xmlNodeName, defaultSettingsFile, callback);
    end

    if fileExists(userSettingsFile) then
        executeXmlReader(xmlNodeName, userSettingsFile, callback);
    end

end


function ModSettings:save(callback)
    if not validateParam(callback, "function", "Parameter 'callback' (#1) is mandatory and must contain a valid callback function") then
        return;
    end

    local userSettingsFile = self._config.userSettingsPath;
    local xmlNodeName = self._config.xmlNodeName or "settings"

    if userSettingsFile == "" then
        printError("Missing filename for user settings, cannot save mod settings.");
        return;
    end

    if not fileExists(userSettingsFile) then
        createFolder(self._config.modSettingsDir)
    end

    local function executeXmlWriter(xmlNodeName, fileName, callback)
        local xmlFile = createXMLFile(xmlNodeName, fileName, xmlNodeName)

        if xmlFile == nil then
            printError("Failed to create/write to settings file '" .. fileName .. "'!")
            return
        end

        local xmlWriter = {
            xmlFile = xmlFile,
            xmlNodeName = xmlNodeName,
            
            getKey = function(self, categoryName, valueName)
                local xmlKey = self.xmlNodeName

                
                if categoryName ~= nil and categoryName ~= "" then 
                    xmlKey = xmlKey .. "." .. categoryName
                end

                xmlKey = xmlKey .. "." .. valueName
                
                return xmlKey
            end,

            saveBool = function(self, categoryName, valueName, value)
                return setXMLBool(self.xmlFile, self:getKey(categoryName, valueName), Utils.getNoNil(value, false))
            end,

            saveFloat = function(self, categoryName, valueName, value)
                return setXMLFloat(self.xmlFile, self:getKey(categoryName, valueName), Utils.getNoNil(value, 0.0))
            end,

            saveString = function(self, categoryName, valueName, value)
                return setXMLString(self.xmlFile, self:getKey(categoryName, valueName), Utils.getNoNil(value, ""))
            end,

        }
        callback(xmlWriter);

        saveXMLFile(xmlFile)
        delete(xmlFile)
    end

    executeXmlWriter(xmlNodeName, userSettingsFile, callback);

    return self
end


function Mod:source(file)
    source(self.dir .. file);
    return self; -- Return self to keep the "chain" (fluent)
end--function

function Mod:trySource(file, silentFail)
    local filename = self.dir .. file

    silentFail = silentFail or false

    if fileExists(filename) then
        source(filename);
    elseif not silentFail then
        self:printWarning("Failed to load sourcefile '" .. filename .. "'")
    end
    return self; -- Return self to keep the "chain" (fluent)
end--function

function Mod:init()
    local newMod = self:new();

    addModEventListener(newMod);

    print(string.format("Load mod: %s (v%s) by %s", newMod.title, newMod.version, newMod.author))

    return newMod;
end--function


function Mod:isServerAdmin()
    deprecated("isServerAdmin()", "getIsServerAdmin()")

    return self:getIsServerAdmin()
end

function Mod:isFarmAdmin()
    deprecated("isFarmAdmin()", "getIsFarmAdmin()")

    return self:getIsServerAdmin()
end

---Check if the game is in multiplayer mode
---@return boolean "True if the game is in multiplayer mode, otherwise false"
function Mod:getIsMultiplayer()
    return g_currentMission.missionDynamicInfo.isMultiplayer
end

function Mod:getIsDedicatedServer()
    return (not self:getIsClient() and self:getIsServer()) or g_dedicatedServer ~= nil
end

function Mod:getHasFarmAdminAccess()
    deprecated("getHasFarmAdminAccess()", "getIsFarmAdmin()")
    return self:getIsFarmAdmin()
end

function  Mod:getIsValidFarmManager()
    deprecated("getIsValidFarmManager()", "getIsFarmAdmin()")

    return self:getIsFarmAdmin()
end

function Mod:getIsMasterUser()
    return g_currentMission.isMasterUser    
end

---Checks if the player is in spectator mode (i.e. not associated with a farm)
---@return boolean "True if the player is in spectator mode (farmId = 0), otherwise false"
function Mod:getIsSpectatorFarm()
    return g_localPlayer == nil or g_localPlayer.farmId == FarmManager.SPECTATOR_FARM_ID
end

---Checks if the player is a server admin (either the host in self-hosted servers, or a master user in dedicated servers)
---@return boolean "True if the player is a server admin, otherwise false"
function Mod:getIsServerAdmin()
    return (g_currentMission:getIsServer() or g_currentMission.isMasterUser) and g_currentMission:getIsClient()
end

--- Checks if the player is a farm admin
---@return boolean "True if the player is associated with a farm, and the player also has been promoted to farm admin for that farm, otherwise false"
function Mod:getIsFarmAdmin()
    local isSpectatorFarm = self:getIsSpectatorFarm()    
    local currentFarm = not isSpectatorFarm and g_farmManager:getFarmById(g_localPlayer.farmId) or nil
    
    return (not isSpectatorFarm and currentFarm ~= nil and currentFarm:isUserFarmManager(g_localPlayer.userId)) or false
end

--- Checks if the player is a server admin or a farm admin
---@return boolean "True if the player is a server admin or a farm admin, otherwise false"
function Mod:getHasAdminAccess()
    return self:getIsServerAdmin() or self:getIsFarmAdmin()
end

--- Returns the current player (convinient wraper for g_localPlayer, but also serves the purpose to make it easy to change if/when Giants decide to rename this object again)
--- @return table "The current player"
function Mod:getCurrentPlayer()
    return g_localPlayer
    -- return g_currentMission.playerSystem.playersByUserId[g_currentMission.playerUserId]
end


function Mod:getCurrentFarm()
    local farmId = g_localPlayer.farmId or FarmManager.SPECTATOR_FARM_ID
    return g_farmManager:getFarmById(farmId)
end

function Mod:enableDebugMode()
    deprecated("enableDebugMode()", "Log class")

    self.debugMode = true

    self:printDebug("Debug mode enabled")

    return self; -- Return self to keep the "chain" (fluent)
end--function

function Mod:loadSound(name, fileName)
    local newSound = createSample(name)
    loadSample(newSound, self.dir .. fileName, false)
    return newSound
end

function Mod:new()
    local newMod = {}

    setmetatable(newMod, self)
    self.__index = self

    newMod.dir = g_currentModDirectory;
    newMod.name = g_currentModName
    newMod.settings = ModSettings:new(newMod);


    local modDescXML = loadXMLFile("modDesc", newMod.dir .. "modDesc.xml");
    newMod.title = getXMLString(modDescXML, "modDesc.title.en");
    newMod.author = getXMLString(modDescXML, "modDesc.author");
    newMod.version = getXMLString(modDescXML, "modDesc.version");
    delete(modDescXML);

    -- newMod.startMission = function() end -- Dummy function/event

    -- FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, function(...)
    --     newMod.startMission(newMod, ...)
    -- end);

    FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, function(baseMission, ...) 
        if newMod.startMission ~= nil and type(newMod.startMission) == "function" then
            newMod:startMission(baseMission, ...)
        end
    end)

    FSBaseMission.onStartMission = Utils.prependedFunction(FSBaseMission.onStartMission, function(baseMission, ...) 
        if newMod.beforeStartMission ~= nil and type(newMod.beforeStartMission) == "function" then
            newMod:beforeStartMission(baseMission, ...)
        end
    end)

    -- Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission00, ...) 
    --     if newMod.missionLoaded ~= nil and type(newMod.missionLoaded) == "function" then
    --         newMod:missionLoaded(mission00, ...)
    --     end
    -- end)

    FSBaseMission.load = Utils.appendedFunction(FSBaseMission.load, function(baseMission, ...) 
        if newMod.load ~= nil and type(newMod.load) == "function" then
            newMod:load(baseMission, ...)
        end
    end)


    FSBaseMission.initialize = Utils.appendedFunction(FSBaseMission.initialize, function(baseMission, ...) 
        if newMod.initMission ~= nil and type(newMod.initMission) == "function" then
            newMod:initMission(baseMission, ...)
        end
    end)

    FSBaseMission.loadMap = Utils.prependedFunction(FSBaseMission.loadMap, function(baseMission, ...) 
        if newMod.beforeLoadMap ~= nil and type(newMod.beforeLoadMap) == "function" then
            newMod:beforeLoadMap(baseMission, ...)
        end
    end)

    FSBaseMission.loadMap = Utils.appendedFunction(FSBaseMission.loadMap, function(baseMission, ...) 
        if newMod.afterLoadMap ~= nil and type(newMod.afterLoadMap) == "function" then
            newMod:afterLoadMap(baseMission, ...)
        end
    end)


    FSBaseMission.loadMapFinished = Utils.prependedFunction(FSBaseMission.loadMapFinished, function(baseMission, ...) 
        if newMod.loadMapFinished ~= nil and type(newMod.loadMapFinished) == "function" then
            newMod:loadMapFinished(baseMission, ...)
        end
    end)

    FSBaseMission.loadMapFinished = Utils.appendedFunction(FSBaseMission.loadMapFinished, function(baseMission, ...) 
        if newMod.afterLoadMapFinished ~= nil and type(newMod.afterLoadMapFinished) == "function" then
            newMod:afterLoadMapFinished(baseMission, ...)
        end
    end)

    FSBaseMission.onMinuteChanged = Utils.appendedFunction(FSBaseMission.onMinuteChanged, function(baseMission, ...)
        if newMod.onMinuteChanged ~= nil and type(newMod.onMinuteChanged) == "function" then
            newMod:onMinuteChanged(baseMission, ...)
        end
    end)

    FSBaseMission.onHourChanged = Utils.appendedFunction(FSBaseMission.onHourChanged, function(baseMission, ...)
        if newMod.onHourChanged ~= nil and type(newMod.onHourChanged) == "function" then
            newMod:onHourChanged(baseMission, ...)
        end
    end)

    FSBaseMission.onDayChanged = Utils.appendedFunction(FSBaseMission.onDayChanged, function(baseMission, ...)
        if newMod.onDayChanged ~= nil and type(newMod.onDayChanged) == "function" then
            newMod:onDayChanged(baseMission, ...)
        end
    end)

    return newMod;
end--function

-- function SubModule:new(parent, table)
--     local newSubModule = table or {}

--     setmetatable(newSubModule, self)
--     self.__index = self
--     newSubModule.parent = parent
--     return newSubModule
-- end


-- function Mod:newSubModule(table)
--     return SubModule:new(self, table)
-- end


--- Check if the third party mod is loaded
---@param modName string The name of the mod/zip-file
---@param envName string (Optional)The environment name to check for
function Mod:getIsModActive(modName, envName)

    if modName == nil and envName == nil then
        return false
    end

    local testMod = g_modManager:getModByName(modName)
    if testMod == nil then
        return false
    end

    local modNameCheck = false
    local envCheck = false


    modNameCheck = (modName == nil) or (g_modIsLoaded[modName] ~= nil)
    envCheck = (envName == nil) or (getfenv(0)[envName] ~= nil)

    return modNameCheck and envCheck

end

-- function Mod:getIsSeasonsActive()
--     --TODO: fix check basegame option
--     return false -- Mod:getIsModActive(nil, "g_seasons")
-- end

ModHelper = {}

function ModHelper.isModInstalled(name)
    return g_modManager:getModByName(name) ~= nil
end

function ModHelper.isModActive(name)
    return g_modIsLoaded[name] == true
end

function ModHelper.getMod(name)
    return g_modManager:getModByName(name)
end

function ModHelper.getModEnvironment(name)
    return getTrueGlobalG()[name]
end

function ModHelper.getIsMaizePlusActive()
    return ModHelper.isModActive("FS22_MaizePlus")
end

function ModHelper.isMaizePlusForageActive()
    return ModHelper.isModActive("FS22_MaizePlus_forageExtension")
end

function ModHelper.isMaizePlusAnimalFoodAdditionsActive()
    return ModHelper.isModActive("FS22_maizePlus_animalFoodAdditions")
end

---comment
---@param scope integer|string
---@param trueG boolean
---@return table
function ModHelper.getfenv(scope, trueG)
    if not trueG or scope == nil then
        return getfenv(scope) -- Use default (nerfed) getfenv
    else
        local __g = getTrueGlobalG()
        local tempObject = __g ~= nil and __g[scope]
        if tempObject == nil and type(scope) == "string" then
            tempObject = __g ~= nil and __g["FS22_" .. scope]
        end
        return tempObject
    end
end

