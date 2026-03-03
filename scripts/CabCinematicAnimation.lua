---@class CabCinematicAnimation
---Handle cinematic camera travel, keyframes and animation
CabCinematicAnimation = {}
local CabCinematicAnimation_mt = Class(CabCinematicAnimation)

CabCinematicAnimation.STATES = {
  IDLE = "idle",
  BEFORE_START = "beforeStart",
  STARTED = "started",
  PAUSED = "paused",
  BEFORE_END = "beforeEnd",
  ENDED = "ended",
  STALE = "stale",
}

---Creates a new animation
---@param vehicle table The vehicle the animation is associated with
---@param keyframes table The keyframes defining the animation
---@return CabCinematicAnimation
function CabCinematicAnimation.new(vehicle, keyframes)
  local self = setmetatable({}, CabCinematicAnimation_mt)
  self.vehicle = vehicle
  self.state = CabCinematicAnimation.STATES.IDLE
  self.callbacks = {
    onBeforeStart = function() end,
    onStart = function() end,
    onPause = function() end,
    onBeforeEnd = function() end,
    onEnd = function() end,
  }
  self.keyframes = keyframes or {}
  self.currentKeyFrameIndex = 1
  self.timer = 0.0
  self.currentPosition = { 0, 0, 0 }

  self.duration = 0.0
  for _, keyframe in ipairs(self.keyframes) do
    self.duration = self.duration + keyframe:getDuration()
  end

  return self
end

---Deletes the animation and its resources
function CabCinematicAnimation:delete()
  self.type = nil
  self.vehicle = nil
  self.state = nil
  self.callbacks = nil
  self.keyframes = nil
  self.currentKeyFrameIndex = nil
  self.timer = nil
  self.duration = nil
  self.currentPosition = nil
end

---Sets "onBeforeStart" callback executed during the animation lifecycle
---@param callback function The callback function
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:onBeforeStart(callback)
  self.callbacks.onBeforeStart = callback
  return self
end

---Sets "onStart" callback executed during the animation lifecycle
---@param callback function The callback function
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:onStart(callback)
  self.callbacks.onStart = callback
  return self
end

---Sets "onPause" callback executed during the animation lifecycle
---@param callback function The callback function
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:onPause(callback)
  self.callbacks.onPause = callback
  return self
end

---Sets "onBeforeEnd" callback executed during the animation lifecycle
---@param callback function The callback function
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:onBeforeEnd(callback)
  self.callbacks.onBeforeEnd = callback
  return self
end

---Sets "onEnd" callback executed during the animation lifecycle
---@param callback function The callback function
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:onEnd(callback)
  self.callbacks.onEnd = callback
  return self
end

---Pauses the animation if it's currently started
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:pause()
  if self.state == CabCinematicAnimation.STATES.STARTED then
    self.state = CabCinematicAnimation.STATES.PAUSED
    self.callbacks.onPause(0, self.vehicle)
  end

  return self
end

---Resumes the animation if it's currently paused
---@return CabCinematicAnimation self for chaining
function CabCinematicAnimation:resume()
  if self.state == CabCinematicAnimation.STATES.PAUSED then
    self.state = CabCinematicAnimation.STATES.STARTED
  end

  return self
end

---Tells whether the animation is currently idle (not started yet)
---@return boolean
function CabCinematicAnimation:getIsIdle()
  return self.state == CabCinematicAnimation.STATES.IDLE
end

---Tells whether the animation is currently in a running state
---@return boolean
function CabCinematicAnimation:getIsRunning()
  return self.state == CabCinematicAnimation.STATES.BEFORE_START
      or self.state == CabCinematicAnimation.STATES.STARTED
end

---Tells whether the animation is currently paused
---@return boolean
function CabCinematicAnimation:getIsPaused()
  return self.state == CabCinematicAnimation.STATES.PAUSED
end

---Tells whether the animation is currently finished
---@return boolean
function CabCinematicAnimation:getIsFinished()
  return self.state == CabCinematicAnimation.STATES.BEFORE_END
      or self.state == CabCinematicAnimation.STATES.ENDED
end

---Tells whether the animation is currently in a stale state, meaning it has finished and is waiting to be deleted
---@return boolean
function CabCinematicAnimation:getIsStale()
  return self.state == CabCinematicAnimation.STATES.STALE
end

---Runs the current animation tick
---@param dt number Delta time since last update
---@return boolean isFinished whether the animation has finished
function CabCinematicAnimation:tick(dt)
  self.timer = self.timer + (dt / 1000.0)

  local accumulatedDuration = 0.0
  for i = 1, self.currentKeyFrameIndex - 1 do
    accumulatedDuration = accumulatedDuration + self.keyframes[i]:getDuration()
  end

  local currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  if currentKeyFrame == nil then
    Log:info("No current keyframe found at index %d, total keyframes: %d", self.currentKeyFrameIndex, #self.keyframes)
    return true
  end

  local keyframeEndTime = accumulatedDuration + currentKeyFrame:getDuration()
  if self.timer > keyframeEndTime and self.currentKeyFrameIndex < #self.keyframes then
    self.currentKeyFrameIndex = self.currentKeyFrameIndex + 1
    accumulatedDuration = keyframeEndTime
    currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  end

  local keyframeTime = self.timer - accumulatedDuration
  self.currentPosition = currentKeyFrame:getInterpolatedPositionAtTime(keyframeTime)

  Log:info("Animation tick: timer=%.2f, currentKeyFrameIndex=%d, keyframeTime=%.2f, currentPosition=(%.2f, %.2f, %.2f)",
    self.timer, self.currentKeyFrameIndex, keyframeTime, self.currentPosition[1], self.currentPosition[2], self.currentPosition[3])

  return self.timer >= self.duration
end

---Update main animation lifecycle, should be called by the vehicle spec
---@param dt number Delta time since last update
function CabCinematicAnimation:update(dt)
  if self.state == CabCinematicAnimation.STATES.IDLE then
    self:printDebug()

    self.callbacks.onBeforeStart(dt, self.vehicle)
    self.state = CabCinematicAnimation.STATES.BEFORE_START
    Log:info("Animation entering BEFORE_START state")
    return
  end

  if self.state == CabCinematicAnimation.STATES.BEFORE_START then
    self.callbacks.onStart(dt, self.vehicle)
    self.state = CabCinematicAnimation.STATES.STARTED
    Log:info("Animation entering STARTED state")
    return
  end

  if self.state == CabCinematicAnimation.STATES.STARTED then
    local isFinished = self:tick(dt)
    if isFinished then
      self.state = CabCinematicAnimation.STATES.BEFORE_END
      Log:info("Animation entering BEFORE_END state")
    end

    return
  end

  if self.state == CabCinematicAnimation.STATES.PAUSED then
    return
  end

  if self.state == CabCinematicAnimation.STATES.BEFORE_END then
    self.callbacks.onBeforeEnd(dt, self.vehicle)
    self.state = CabCinematicAnimation.STATES.ENDED
    Log:info("Animation entering ENDED state")
    return
  end

  if self.state == CabCinematicAnimation.STATES.ENDED then
    self.callbacks.onEnd(dt, self.vehicle)
    self.state = CabCinematicAnimation.STATES.STALE
    Log:info("Animation entering STALE state")
    return
  end
end

---Prints debug information about the animation and its keyframes
function CabCinematicAnimation:printDebug()
  Log:info(string.format("Animation state: %s, duration: %.2f, keyframes: %d", self.state, self.duration, #self.keyframes))

  for i, keyframe in ipairs(self.keyframes) do
    keyframe:printDebug()
  end
end

---Draw debug
function CabCinematicAnimation:drawDebug()
  if self.keyframes ~= nil then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:drawDebug(self.vehicle.rootNode)
    end
  end
end
