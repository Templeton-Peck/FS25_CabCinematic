CabCinematicAnimation = {
  timer = 0,
  isActive = false,
  isPaused = false,
  isEnded = false,
  type = nil,
  vehicle = nil,
  finishCallback = nil,
  keyframes = nil,
  playerSnapshot = nil,
  duration = 0.0,
  currentKeyFrameIndex = 1,
  currentPosition = { 0, 0, 0 }
}

CabCinematicAnimation.TYPES = {
  ENTER = "enter",
  LEAVE = "leave",
}

CabCinematicAnimation.PRE_MOVEMENT_DISTANCE = 0.5
CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_PLAYER_SPEED = 6.9
CabCinematicAnimation.PRE_MOVEMENT_RUN_MIN_VEHICLE_SPEED = 8.0

local CabCinematicAnimation_mt = Class(CabCinematicAnimation)

function CabCinematicAnimation.new(type, vehicle, finishCallback)
  Log:info("Created CabCinematicAnimation of type %s for vehicle %s", type, vehicle.typeName)

  local self = setmetatable({}, CabCinematicAnimation_mt)
  self.type = type
  self.vehicle = vehicle
  self.finishCallback = finishCallback
  return self
end

function CabCinematicAnimation:delete()
  if self.keyframes then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:delete()
    end
  end

  self.timer = 0
  self.isActive = false
  self.isPaused = false
  self.isEnded = false
  self.type = nil
  self.vehicle = nil
  self.finishCallback = nil
  self.keyframes = nil
  self.playerSnapshot = nil
  self.duration = 0.0
  self.currentKeyFrameIndex = 1
  self.currentPosition = { 0, 0, 0 }
end

function CabCinematicAnimation:getIsActive()
  return self.isActive
end

function CabCinematicAnimation:getIsEnded()
  return self.isEnded
end

function CabCinematicAnimation:getIsPaused()
  return self.isPaused
end

function CabCinematicAnimation:buildEnterAdjustmentKeyframe(keyframes)
  if self.playerSnapshot == nil then
    return nil
  end

  local playerPosition = self.playerSnapshot:getLocalPosition(self.vehicle.rootNode)
  local animationPosition = keyframes[1].startPosition;

  local playerDistance = MathUtil.vector3Length(playerPosition[1] - animationPosition[1],
    playerPosition[2] - animationPosition[2], playerPosition[3] - animationPosition[3])

  if playerDistance > CabCinematicAnimation.PRE_MOVEMENT_DISTANCE then
    Log:info(
      "Calculating pre-movement keyframe - Player position (%.2f, %.2f, %.2f), ExitNode position (%.2f, %.2f, %.2f) - Distance: %.2f",
      playerPosition[1], playerPosition[2], playerPosition[3], animationPosition[1], animationPosition[2],
      animationPosition[3], playerDistance)

    return CabCinematicAnimationKeyframe.new(
      CabCinematicAnimationKeyframe.TYPES.WALK,
      playerPosition,
      animationPosition
    )
  else
    Log:info("No pre-movement keyframe needed - distance: %.2f", playerDistance)
  end
end

function CabCinematicAnimation:buildKeyframes()
  local keyframes = CabCinematicAnimationKeyframe.build(g_localPlayer, self.vehicle)

  if self.type == CabCinematicAnimation.TYPES.ENTER then
    local enterAdjustmentKeyframe = self:buildEnterAdjustmentKeyframe(keyframes)
    if enterAdjustmentKeyframe ~= nil then
      table.insert(keyframes, 1, enterAdjustmentKeyframe)
    end
  elseif self.type == CabCinematicAnimation.TYPES.LEAVE then
    local reversedKeyframes = {}
    for _, keyframe in ipairs(keyframes) do
      keyframe:reverse()
      table.insert(reversedKeyframes, 1, keyframe)
    end

    return reversedKeyframes
  end


  return keyframes
end

function CabCinematicAnimation:prepare()
  self.keyframes = self:buildKeyframes()
  self.duration = 0
  for _, keyframe in ipairs(self.keyframes) do
    self.duration = self.duration + keyframe:getDuration()
    keyframe:printDebug()
  end
end

function CabCinematicAnimation:start()
  self:prepare()

  self.timer = 0
  self.currentKeyFrameIndex = 1
  self.isActive = true
end

function CabCinematicAnimation:stop()
  if self.finishCallback ~= nil then
    self.finishCallback()
  end

  self.timer          = 0
  self.finishCallback = nil
  self.isActive       = false
  self.isEnded        = true
end

function CabCinematicAnimation:pause()
  self.isPaused = true
end

function CabCinematicAnimation:update(dt)
  if not self.isActive or self.isPaused then
    return
  end

  self.timer = self.timer + (dt / 1000.0)

  local accumulatedDuration = 0.0
  for i = 1, self.currentKeyFrameIndex - 1 do
    accumulatedDuration = accumulatedDuration + self.keyframes[i]:getDuration()
  end

  local currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  if currentKeyFrame == nil then
    Log:error("No current keyframe found during update")
    self.isEnded = true
    return
  end

  local keyframeEndTime = accumulatedDuration + currentKeyFrame:getDuration()
  if self.timer > keyframeEndTime and self.currentKeyFrameIndex < #self.keyframes then
    self.currentKeyFrameIndex = self.currentKeyFrameIndex + 1
    accumulatedDuration = keyframeEndTime
    currentKeyFrame = self.keyframes[self.currentKeyFrameIndex]
  end

  local keyframeTime = self.timer - accumulatedDuration
  self.currentPosition = currentKeyFrame:getInterpolatedPositionAtTime(keyframeTime)

  -- Log:info("CabCinematicAnimation progress=%.2f, timer=%.2f, keyframeTime=%.2f, pos=(%.2f, %.2f, %.2f)",
  --   progress, self.timer, keyframeTime, self.currentPosition[1], self.currentPosition[2], self.currentPosition[3])

  if self.timer >= self.duration then
    self.isEnded = true
  end
end

function CabCinematicAnimation:drawDebug()
  if self.keyframes ~= nil then
    for _, keyframe in ipairs(self.keyframes) do
      keyframe:drawDebug(self.vehicle.rootNode)
    end
  end
end
