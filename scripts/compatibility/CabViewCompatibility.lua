--- Compatibility adapter for FS25_CabView.
--- Suppresses CabView's one-shot enter view reset during cinematic enter animations.
CabViewCompatibility = {
  modName = "FS25_CabView",

  isAvailable = function()
    return ModHelper.getModClass("FS25_CabView", "CabView") ~= nil
  end,

  --- Clears CabView resetView before Enterable:onPostUpdate consumes it.
  --- @param vehicle table
  onEnterAnimationBeforeStart = function(vehicle)
    local CabView = ModHelper.getModClass("FS25_CabView", "CabView")
    if CabView == nil or CabView.specName == nil then
      return
    end

    local spec = vehicle[CabView.specName]
    if spec ~= nil then
      spec.resetView = false
    end
  end,
}
