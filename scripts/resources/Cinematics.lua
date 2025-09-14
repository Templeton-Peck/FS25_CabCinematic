Cinematics = {}

local bobbing = {
  walk = {
    amp = { x = 0.001, y = 0.01, z = 0.001 },
    freq = 0.8,
    phase = { x = 0, y = math.pi / 4, z = math.pi / 2 }
  },
  climb = {
    amp = { x = 0.002, y = 0.020, z = 0.0015 },
    freq = 1.1,
    phase = { x = 0, y = math.pi / 6, z = math.pi / 3 }
  },
  seat = {
    amp = { x = 0.002, y = 0.010, z = 0.001 },
    freq = 1.0,
    phase = { x = 0, y = math.pi / 8, z = math.pi / 4 }
  }
}

local profiles = {
  default = {
    segments = {
      {
        duration = 5000,
        axes = { x = 1, y = 1, z = 1 },
        bob = bobbing.climb,
        offset = nil
      },
    },
  },
  tractor = {
    segments = {
      {
        duration = 2600,
        axes = { x = 0.25, y = 0.7, z = 0.20 },
        bob = bobbing.climb,
        offset = nil
      },
      {
        duration = 3300,
        axes = { x = 0.71, y = 0.3, z = 0.76 },
        bob = bobbing.walk,
        offset = { x = 0, y = 0.075, z = 0.4 },
      },
      {
        duration = 1000,
        axes = { x = 0.04, y = 0, z = 0.04 },
        bob = bobbing.seat,
        offset = { x = 0, y = -0.075, z = -0.4 },
      }
    }
  },
  combineDrivable = {
    segments = {
      {
        duration = 1800,
        axes = { x = 0.15, y = 0.8, z = 0.15 },
        bob = bobbing.climb,
        offset = nil
      },
      {
        duration = 2000,
        axes = { x = 0.50, y = 0.3, z = 0.50 },
        bob = bobbing.walk,
        offset = nil
      },
      {
        duration = 1000,
        axes = { x = 0.31, y = 0, z = 0.31 },
        bob = bobbing.walk,
        offset = { x = 0, y = 0, z = 0.2 },
      },
      {
        duration = 675,
        axes = { x = 0.04, y = 0, z = 0.04 },
        bob = bobbing.seat,
        offset = { x = 0, y = 0, z = -0.2 },
      },
    }
  },
}

local reversedProfiles = {}

local function addCinematicMethods(profile, isReversed)
  local totalDuration = 0
  for _, segment in ipairs(profile.segments) do
    totalDuration = totalDuration + segment.duration
  end

  profile.totalDuration = totalDuration
  profile.isReversed = isReversed or false

  Log:info(string.format("Created cinematic profile (reversed: %s) with total duration %d ms", tostring(isReversed),
    totalDuration))

  function profile:getAxisProgressAtTime(t)
    local currentTime = t * self.totalDuration
    local accumulatedTime = 0
    local accumulatedProgress = { x = 0, y = 0, z = 0 }

    local totalContribution = { x = 0, y = 0, z = 0 }
    for _, segment in ipairs(self.segments) do
      local segmentWeight = segment.duration / self.totalDuration
      totalContribution.x = totalContribution.x + (segment.axes.x * segmentWeight)
      totalContribution.y = totalContribution.y + (segment.axes.y * segmentWeight)
      totalContribution.z = totalContribution.z + (segment.axes.z * segmentWeight)
    end

    local normX = totalContribution.x > 0 and (1.0 / totalContribution.x) or 1.0
    local normY = totalContribution.y > 0 and (1.0 / totalContribution.y) or 1.0
    local normZ = totalContribution.z > 0 and (1.0 / totalContribution.z) or 1.0

    for i, segment in ipairs(self.segments) do
      if currentTime <= accumulatedTime + segment.duration then
        local segmentT = (currentTime - accumulatedTime) / segment.duration

        local segmentWeight = segment.duration / self.totalDuration

        local segmentContribution = {
          x = segmentT * segment.axes.x * segmentWeight * normX,
          y = segmentT * segment.axes.y * segmentWeight * normY,
          z = segmentT * segment.axes.z * segmentWeight * normZ
        }

        return {
          x = accumulatedProgress.x + segmentContribution.x,
          y = accumulatedProgress.y + segmentContribution.y,
          z = accumulatedProgress.z + segmentContribution.z
        }
      end

      accumulatedTime = accumulatedTime + segment.duration
      local segmentWeight = segment.duration / self.totalDuration
      accumulatedProgress.x = accumulatedProgress.x + (segment.axes.x * segmentWeight * normX)
      accumulatedProgress.y = accumulatedProgress.y + (segment.axes.y * segmentWeight * normY)
      accumulatedProgress.z = accumulatedProgress.z + (segment.axes.z * segmentWeight * normZ)
    end

    return { x = 1.0, y = 1.0, z = 1.0 }
  end

  function profile:getOffsetAtTime(t)
    local currentTime = t * self.totalDuration
    local accumulatedTime = 0
    local accumulatedOffset = { x = 0, y = 0, z = 0 }

    for i, segment in ipairs(self.segments) do
      if currentTime <= accumulatedTime + segment.duration then
        local segmentT = (currentTime - accumulatedTime) / segment.duration

        if segment.offset then
          return {
            x = accumulatedOffset.x + segment.offset.x * segmentT,
            y = accumulatedOffset.y + segment.offset.y * segmentT,
            z = accumulatedOffset.z + segment.offset.z * segmentT
          }
        else
          return accumulatedOffset
        end
      end

      accumulatedTime = accumulatedTime + segment.duration
      if segment.offset then
        accumulatedOffset.x = accumulatedOffset.x + segment.offset.x
        accumulatedOffset.y = accumulatedOffset.y + segment.offset.y
        accumulatedOffset.z = accumulatedOffset.z + segment.offset.z
      end
    end

    return accumulatedOffset
  end

  function profile:getBobbingAtTime(t)
    local currentTime = t * self.totalDuration
    local accumulatedTime = 0

    for _, segment in ipairs(self.segments) do
      if currentTime <= accumulatedTime + segment.duration then
        if segment.bob and segment.bob.amp then
          local bobbing = segment.bob
          local globalTime = t * self.totalDuration / 1000

          return {
            x = bobbing.amp.x * math.sin(globalTime * bobbing.freq * 2 * math.pi + bobbing.phase.x),
            y = bobbing.amp.y * math.sin(globalTime * bobbing.freq * 2 * math.pi + bobbing.phase.y) *
                (1 + 0.3 * math.sin(globalTime * bobbing.freq * 0.7 * math.pi)),
            z = bobbing.amp.z * math.sin(globalTime * bobbing.freq * 2 * math.pi + bobbing.phase.z)
          }
        end
      end
      accumulatedTime = accumulatedTime + segment.duration
    end

    return { x = 0, y = 0, z = 0 }
  end

  return profile
end

local function createReversedProfile(originalProfile)
  local reversedProfile = {}

  reversedProfile.segments = {}

  for i = #originalProfile.segments, 1, -1 do
    local originalSegment = originalProfile.segments[i]
    local reversedSegment = {
      duration = originalSegment.duration,
      axes = {
        x = originalSegment.axes.x,
        y = originalSegment.axes.y,
        z = originalSegment.axes.z
      },
      bob = originalSegment.bob,
      offset = nil
    }

    if originalSegment.offset then
      reversedSegment.offset = {
        x = -originalSegment.offset.x,
        y = -originalSegment.offset.y,
        z = -originalSegment.offset.z
      }
    end

    table.insert(reversedProfile.segments, reversedSegment)
  end

  return reversedProfile
end

for name, profile in pairs(profiles) do
  local reversedProfile = createReversedProfile(profile)
  profiles[name] = addCinematicMethods(profile, false)
  reversedProfiles[name] = addCinematicMethods(reversedProfile, true)
end

function Cinematics.getCinematic(typeName, reverse)
  Log:info(string.format("Get cinematic called (reversed: %s): %s", tostring(reverse), typeName))

  if typeName ~= nil then
    local profileName = typeName
    local profile = reverse and reversedProfiles[profileName] or profiles[profileName]
    if profile ~= nil then
      return profile
    end
  end

  return reverse and reversedProfiles["default"] or profiles["default"]
end
