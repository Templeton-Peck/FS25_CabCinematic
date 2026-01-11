TimerHelper = {
  timers = {},
  nextTimerId = 1
}

function TimerHelper.setTimeout(callback, delayMS)
  local timerId = TimerHelper.nextTimerId
  TimerHelper.nextTimerId = TimerHelper.nextTimerId + 1

  TimerHelper.timers[timerId] = {
    callback = callback,
    remainingTime = delayMS,
    isActive = true
  }

  return timerId
end

function TimerHelper.clearTimeout(timerId)
  if TimerHelper.timers[timerId] ~= nil then
    TimerHelper.timers[timerId].isActive = false
    TimerHelper.timers[timerId] = nil
  end
end

function TimerHelper:update(dt)
  for timerId, timer in pairs(self.timers) do
    if timer.isActive then
      timer.remainingTime = timer.remainingTime - dt

      if timer.remainingTime <= 0 then
        timer.isActive = false
        if timer.callback ~= nil then
          timer.callback()
        end
        self.timers[timerId] = nil
      end
    end
  end
end

function TimerHelper.clear()
  for timerId, _ in pairs(TimerHelper.timers) do
    TimerHelper.clearTimeout(timerId)
  end
  TimerHelper.timers = {}
end

addModEventListener(TimerHelper);
