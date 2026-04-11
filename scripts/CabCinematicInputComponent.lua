--- @class CabCinematicInputComponent
--- Component responsible for managing input action events for cab cinematic animations.
CabCinematicInputComponent = {}
local CabCinematicInputComponent_mt = Class(CabCinematicInputComponent)

CabCinematicInputComponent.INPUT_CONTEXT_NAME = "CAB_CINEMATIC"

--- Creates a new CabCinematicInputComponent for the given vehicle.
--- @param vehicle table The vehicle instance to which this input component belongs.
function CabCinematicInputComponent.new(vehicle)
  local self = setmetatable({}, CabCinematicInputComponent_mt)
  self.vehicle = vehicle
  self.actionEvents = {}
  self.isContextActive = false
  return self
end

--- Deletes the input component, deactivating the input context and clearing references.
--- This should be called when the vehicle is deleted to ensure proper cleanup.
function CabCinematicInputComponent:delete()
  self:deactivate()
  self.vehicle = nil
  self.actionEvents = nil
  self.isContextActive = nil
end

--- Clears all registered action events
function CabCinematicInputComponent:clearActionEvents()
  for key, actionEvent in pairs(self.actionEvents) do
    if actionEvent ~= nil and actionEvent.actionEventId ~= nil then
      g_inputBinding:removeActionEvent(actionEvent.actionEventId)
    end

    self.actionEvents[key] = nil
  end
end

--- Adds an action event to the input context
--- @param inputAction string Input action name
--- @param callback function Callback function for the action event
--- @param options table Options for the action event
---   - target table | nil Target object for the callback (default: self)
---   - triggerUp boolean | nil Trigger on input release (default: false)
---   - triggerDown boolean | nil Trigger on input press (default: false)
---   - triggerAlways boolean | nil Trigger every frame while active (default: false)
---   - startActive boolean | nil Activate immediately after registration (default: true)
---   - textPriority integer | nil Priority for displaying the action event text (nil to hide text)
---   - ignoreCollisions boolean | nil Trigger even if there are input collisions with other contexts (default: false)
--- @return integer | nil actionEventId of the registered action event, or nil if registration failed
function CabCinematicInputComponent:addActionEvent(inputAction, callback, options)
  -- g_inputBinding:registerActionEvent parameters : inputAction, target, callback, triggerUp, triggerDown, triggerAlways, startActive, callbackState, customIconName, ignoreCollisions
  local _, actionEventId = g_inputBinding:registerActionEvent(inputAction, options.target or self, callback, options.triggerUp or false, options.triggerDown or false, options.triggerAlways or false, options.startActive or true, nil, nil, options.ignoreCollisions or false)
  if actionEventId ~= nil then
    if options.textPriority ~= nil and options.textPriority >= GS_PRIO_LOW then
      g_inputBinding:setActionEventTextPriority(actionEventId, options.textPriority)
      g_inputBinding:setActionEventTextVisibility(actionEventId, true)
    else
      g_inputBinding:setActionEventTextVisibility(actionEventId, false)
    end

    self.actionEvents[inputAction] = { actionEventId = actionEventId }

    return actionEventId
  end
end

--- Activates the cab cinematic input context and registers the necessary action events
function CabCinematicInputComponent:activate()
  local vehicle = self.vehicle
  if vehicle == nil or vehicle.spec_cabCinematic == nil or self.isContextActive then
    return
  end

  g_inputBinding:setContext(CabCinematicInputComponent.INPUT_CONTEXT_NAME, true, false)
  g_inputBinding:beginActionEventsModification(CabCinematicInputComponent.INPUT_CONTEXT_NAME)
  self:clearActionEvents()

  g_localPlayer.inputComponent:registerGlobalPlayerActionEvents(CabCinematicInputComponent.INPUT_CONTEXT_NAME)

  self:addActionEvent(InputAction.CAB_CINEMATIC_PAUSE, CabCinematicInputComponent.onPauseAction, { triggerUp = true, triggerDown = true, textPriority = GS_PRIO_HIGH })
  self:addActionEvent(InputAction.AXIS_RUN, CabCinematicInputComponent.onRunAction, { triggerUp = true, triggerDown = true })
  self:addActionEvent(InputAction.ENTER, CabCinematicInputComponent.onEnterAction, { triggerUp = true })

  local indoorCamera = vehicle:getIndoorCamera()
  if indoorCamera ~= nil then
    self:addActionEvent(InputAction.AXIS_LOOK_UPDOWN_VEHICLE, VehicleCamera.actionEventLookUpDown, { triggerAlways = true, target = indoorCamera })
    self:addActionEvent(InputAction.AXIS_LOOK_LEFTRIGHT_VEHICLE, VehicleCamera.actionEventLookLeftRight, { triggerAlways = true, target = indoorCamera })
  end

  g_inputBinding:endActionEventsModification()

  self.isContextActive = true
end

--- Deactivates the cab cinematic input context and clears the registered action events
function CabCinematicInputComponent:deactivate()
  if not self.isContextActive then
    return
  end

  g_inputBinding:beginActionEventsModification(CabCinematicInputComponent.INPUT_CONTEXT_NAME)
  self:clearActionEvents()
  g_inputBinding:endActionEventsModification()
  g_inputBinding:revertContext()

  self.isContextActive = false
end

function CabCinematicInputComponent:onPauseAction(actionName, inputValue, callbackState, isAnalog)
  local vehicle = self.vehicle
  if vehicle ~= nil and vehicle:getIsCabCinematicAnimationOngoing() then
    local animation = vehicle.spec_cabCinematic.animation
    if inputValue == 0 then
      animation:resume()
    else
      animation:pause()
    end
  end
end

function CabCinematicInputComponent:onRunAction(actionName, inputValue, callbackState, isAnalog)
  local vehicle = self.vehicle
  if vehicle == nil or vehicle.spec_cabCinematic == nil then
    return
  end

  if vehicle:getIsCabCinematicAnimationOngoing() then
    local speedFactor = inputValue ~= 0 and 1.6 or 1.0
    vehicle.spec_cabCinematic.animation:setSpeedFactor(speedFactor)
  end
end

function CabCinematicInputComponent:onEnterAction(actionName, inputValue, callbackState, isAnalog)
  local vehicle = self.vehicle
  if vehicle == nil or vehicle.spec_cabCinematic == nil then
    return
  end

  if vehicle:getIsCabCinematicAnimationOngoing() then
    vehicle.spec_cabCinematic.animation:stop()
    local indoorCamera = vehicle:getIndoorCamera()
    if indoorCamera ~= nil then
      indoorCamera:resetCamera()
    end
  end
end
