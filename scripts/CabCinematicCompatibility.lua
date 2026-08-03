--- @class CabCinematicCompatibility
--- Registry of third-party mod adapters hooked into cinematic enter/leave lifecycle.
CabCinematicCompatibility = {}
local CabCinematicCompatibility_mt = Class(CabCinematicCompatibility)

CabCinematicCompatibility.HOOKS = {
  "onEnterAnimationBeforeStart",
  "onLeaveAnimationBeforeStart",
  "onEnterAnimationEnd",
  "onLeaveAnimationEnd",
}

--- Creates a new compatibility registry.
--- @return CabCinematicCompatibility
function CabCinematicCompatibility.new()
  local self = setmetatable({}, CabCinematicCompatibility_mt)
  self.registered = {}
  self.active = {}
  return self
end

--- Deletes the registry and clears adapter lists.
function CabCinematicCompatibility:delete()
  self.registered = nil
  self.active = nil
end

--- Registers an adapter. Availability is resolved later in load().
--- @param adapter table Adapter with modName, isAvailable(), and optional lifecycle hooks
--- @return CabCinematicCompatibility self for chaining
function CabCinematicCompatibility:register(adapter)
  if adapter == nil or adapter.modName == nil then
    return self
  end

  table.insert(self.registered, adapter)
  return self
end

--- Resolves which registered adapters are available for the current session.
function CabCinematicCompatibility:load()
  self.active = {}

  for _, adapter in ipairs(self.registered) do
    local available = false
    if adapter.isAvailable ~= nil then
      available = adapter.isAvailable() == true
    end

    if available then
      table.insert(self.active, adapter)
      Log:info("Compatibility adapter active: %s", adapter.modName)
    end
  end
end

--- Dispatches a lifecycle hook to all active adapters that implement it.
--- @param hookName string Hook name from CabCinematicCompatibility.HOOKS
--- @param vehicle table Vehicle instance
local function dispatch(self, hookName, vehicle)
  if self.active == nil or vehicle == nil then
    return
  end

  for _, adapter in ipairs(self.active) do
    local hook = adapter[hookName]
    if hook ~= nil then
      hook(vehicle)
    end
  end
end

--- @param vehicle table
function CabCinematicCompatibility:onEnterAnimationBeforeStart(vehicle)
  dispatch(self, "onEnterAnimationBeforeStart", vehicle)
end

--- @param vehicle table
function CabCinematicCompatibility:onLeaveAnimationBeforeStart(vehicle)
  dispatch(self, "onLeaveAnimationBeforeStart", vehicle)
end

--- @param vehicle table
function CabCinematicCompatibility:onEnterAnimationEnd(vehicle)
  dispatch(self, "onEnterAnimationEnd", vehicle)
end

--- @param vehicle table
function CabCinematicCompatibility:onLeaveAnimationEnd(vehicle)
  dispatch(self, "onLeaveAnimationEnd", vehicle)
end
