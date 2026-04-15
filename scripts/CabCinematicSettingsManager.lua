--- Manage Cab Cinematic mod settings
--- @class CabCinematicSettingsManager
--- @field public modName string
--- @field public settingsById table<string, table>
--- @field public settingsCreated boolean
--- @field public settingsFilePath string
CabCinematicSettingsManager = {}

local cabCinematicSettingsManager_mt = Class(CabCinematicSettingsManager)

-- Input types for settings
CabCinematicSettingsManager.INPUT_TYPES = {
    SCALE = 0
}

-- Clone references for each input type
CabCinematicSettingsManager.CLONE_REFS = {
    [CabCinematicSettingsManager.INPUT_TYPES.SCALE] = "multiTimeScale"
}

-- Settings definition: describes all available settings
-- Format: SETTING_KEY = { id, type, name, tooltip, default value, options }
CabCinematicSettingsManager.SETTINGS = {
    BASE_SPEED_FACTOR = {
        id = "baseSpeedFactor",
        type = CabCinematicSettingsManager.INPUT_TYPES.SCALE,
        name = g_i18n:getText("cc_settings_base_speed_factor_title"),
        tooltip = g_i18n:getText("cc_settings_base_speed_factor_tooltip"),
        defaultValue = 1.0,
        callback = "onSettingChangedScale",
        options = CabCinematicUtil.generateScaleOptions(0.1, 2.0, 0.1, "%.1fx")
    }
}

--- Create new instance of CabCinematicSettingsManager
--- @param modName string The name of the mod
--- @param modSettingsDir string The directory for mod settings
--- @return CabCinematicSettingsManager
function CabCinematicSettingsManager.new(modName, modSettingsDir)
    local self = setmetatable({}, cabCinematicSettingsManager_mt)

    self.modName = modName
    self.settingsById = {}
    self.settingsCreated = false
    self.settingsFilePath = modSettingsDir .. "settings.xml"

    createFolder(modSettingsDir)

    -- Initialize settings from descriptions
    self:initializeSettings()

    return self
end

---  Delete the settings manager and its resources
function CabCinematicSettingsManager:delete()
    self.modName = nil
    self.settingsById = nil
    self.settingsCreated = nil
    self.settingsFilePath = nil
end

--- Initialize settings from the SETTINGS description table
function CabCinematicSettingsManager:initializeSettings()
    for _, settingDesc in pairs(CabCinematicSettingsManager.SETTINGS) do
        self.settingsById[settingDesc.id] = {
            id = settingDesc.id,
            value = settingDesc.defaultValue,
            desc = settingDesc,
        }
    end
end

--- Load settings from XML file
function CabCinematicSettingsManager:loadFromXML()
    local xmlFile = XMLFile.loadIfExists("CabCinematicSettingsXML", self.settingsFilePath, CabCinematicSettingsManager.xmlSchema)

    if xmlFile == nil then
        return
    end

    xmlFile:iterate("settings.setting", function(_, settingKey)
        local id = xmlFile:getValue(settingKey .. "#id")
        local value = xmlFile:getValue(settingKey .. "#value")

        local setting = self.settingsById[id]
        if setting ~= nil and value ~= nil then
            if setting.desc.type == CabCinematicSettingsManager.INPUT_TYPES.SCALE then
                setting.value = tonumber(value)
            else
                setting.value = value
            end
        end
    end)

    xmlFile:delete()
end

--- Save settings to XML file
function CabCinematicSettingsManager:saveToXMLFile()
    local xmlFile = XMLFile.create("CabCinematicSettingsXML", self.settingsFilePath, "settings", CabCinematicSettingsManager.xmlSchema)

    if xmlFile == nil then
        return
    end

    local baseKey = "settings.setting"
    local i = 0

    for _, setting in pairs(self.settingsById) do
        local settingKey = ("%s(%d)"):format(baseKey, i)

        xmlFile:setValue(settingKey .. "#id", setting.id)
        xmlFile:setValue(settingKey .. "#value", tostring(setting.value))

        i = i + 1
    end

    xmlFile:save(false, false)
    xmlFile:delete()
end

--- Load settings
--- @return CabCinematicSettingsManager self for chaining
function CabCinematicSettingsManager:load()
    self:loadFromXML()
    return self
end

--- Save settings--- @return CabCinematicSettingsManager self for chaining
function CabCinematicSettingsManager:save()
    self:saveToXMLFile()
    return self
end

--- Get the value of a setting by id
--- @param settingId string The setting id
--- @return any The setting value
function CabCinematicSettingsManager:getSettingValue(settingId)
    local setting = self.settingsById[settingId]

    if setting == nil then
        Log:warning("CabCinematicSettingsManager.getSettingValue: Invalid setting id: %s", tostring(settingId))
        return nil
    end

    return setting.value
end

--- Set the value of a setting by id
--- @param settingId string The setting id
--- @param value any The value to set
function CabCinematicSettingsManager:setSettingValue(settingId, value)
    local setting = self.settingsById[settingId]

    if setting == nil then
        Log:warning("CabCinematicSettingsManager.setSettingValue: Invalid setting id: %s", tostring(settingId))
        return
    end

    setting.value = value

    -- Trigger any registered callbacks for this setting
    local callback = self["onSettingChanged_" .. settingId:lower()]
    if callback ~= nil and type(callback) == "function" then
        callback(self, value)
    end
end

--- Create a GUI element for a setting
--- @param settingsFrame table The settings frame GUI element
--- @param setting table The setting to create GUI for
--- @return GuiElement | nil The created GUI element or nil
function CabCinematicSettingsManager:createGuiElement(settingsFrame, setting)
    local cloneRef = CabCinematicSettingsManager.CLONE_REFS[setting.desc.type]

    if cloneRef == nil then
        Log:warning("CabCinematicSettingsManager.createGuiElement: No clone reference for type %s", tostring(setting.desc.type))
        return nil
    end

    cloneRef = settingsFrame[cloneRef]

    if cloneRef == nil then
        Log:warning("CabCinematicSettingsManager.createGuiElement: Clone reference not found: %s", tostring(cloneRef))
        return nil
    end

    local element = cloneRef.parent:clone()
    element.id = setting.id .. "Box"

    local settingElement = element.elements[1]
    local settingTitle = element.elements[2]
    local toolTip = settingElement.elements[1]

    settingTitle:setText(setting.desc.name)
    toolTip:setText(setting.desc.tooltip)
    settingElement.id = setting.id
    settingElement.target = self
    settingElement:setCallback("onClickCallback", setting.desc.callback)
    settingElement:setDisabled(false)

    if setting.desc.type == CabCinematicSettingsManager.INPUT_TYPES.SCALE then
        -- Find the current state based on value
        local currentState = 1
        local texts = {}
        for i, option in ipairs(setting.desc.options) do
            table.insert(texts, option.text)
            if option.value == setting.value then
                currentState = option.state
            end
        end
        settingElement:setTexts(texts)
        settingElement:setState(currentState, false)
    end

    element:reloadFocusHandling(true)

    return element
end

--- Initialize GUI by injecting settings into the InGameMenuSettingsFrame
--- @param settingsFrame table The settings frame GUI element
function CabCinematicSettingsManager:initGui(settingsFrame)
    local settingsElements = settingsFrame["cabCinematicSettings"]

    if settingsElements == nil and not self.settingsCreated then
        -- Copy header by name reference
        local headerRef
        for _, element in ipairs(settingsFrame.generalSettingsLayout.elements) do
            if element.name == 'sectionHeader' then
                headerRef = element
                break
            end
        end

        if headerRef ~= nil then
            local headerElement = headerRef:clone()
            headerElement.id = "cabCinematicSettings"
            headerElement:setText(self.modName)
            settingsFrame.generalSettingsLayout:addElement(headerElement)
        end

        -- Create setting elements
        settingsElements = {}

        for _, setting in pairs(self.settingsById) do
            local createdElement = self:createGuiElement(settingsFrame, setting)

            if createdElement ~= nil then
                settingsElements[setting.id] = createdElement
                settingsFrame.generalSettingsLayout:addElement(createdElement)
            end
        end

        settingsFrame.generalSettingsLayout:invalidateLayout()
        self.settingsCreated = true
    end
end

--- Update GUI to reflect current setting values
--- @param settingsFrame table The settings frame GUI element
function CabCinematicSettingsManager:updateGui(settingsFrame)
    local settingsElements = settingsFrame["cabCinematicSettings"]

    if settingsElements ~= nil then
        for _, setting in pairs(self.settingsById) do
            local element = settingsElements[setting.id]

            if element ~= nil then
                if setting.desc.type == CabCinematicSettingsManager.INPUT_TYPES.SCALE then
                    -- Find the state for current value
                    local currentState = 1
                    for i, option in ipairs(setting.desc.options) do
                        if option.value == setting.value then
                            currentState = option.state
                            break
                        end
                    end

                    element:setState(currentState)
                end
            end
        end
    end
end

--- Called when a scale setting changes
--- @param state integer The new state
--- @param element GuiElement The GUI element that changed
function CabCinematicSettingsManager:onSettingChangedScale(state, element)
    -- Find the setting by ID
    local setting = self.settingsById[element.id]

    if setting ~= nil then
        -- Find the value for this state
        for _, option in ipairs(setting.desc.options) do
            if option.state == state then
                self:setSettingValue(setting.id, option.value)
                break
            end
        end
    end
end

-- XML Schema registration
g_xmlManager:addCreateSchemaFunction(function()
    CabCinematicSettingsManager.xmlSchema = XMLSchema.new("settings")
end)

g_xmlManager:addInitSchemaFunction(function()
    local schema = CabCinematicSettingsManager.xmlSchema
    local settingKey = "settings.setting(?)"

    schema:register(XMLValueType.STRING, settingKey .. "#id", "ID of setting", nil, true)
    schema:register(XMLValueType.STRING, settingKey .. "#value", "Value of setting", nil, true)
end)
