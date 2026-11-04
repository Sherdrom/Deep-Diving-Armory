Hook.Add("DEEP_APS_USE", "DEEP_APS_USE", function(effect, deltaTime, item, targets, worldPosition)
      local light = item.GetComponentString("LightComponent")
      light.pulseAmount = 1.0
      light.pulseFrequency = 2.5
      if SERVER then
        local pulseAmount = light.SerializableProperties[Identifier("pulseAmount")]
        local pulseFrequency = light.SerializableProperties[Identifier("pulseFrequency")]
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(pulseAmount, light))
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(pulseFrequency, light))
      end
      Timer.Wait(function()
        item.Condition = 0
        light.pulseAmount = 0.0
        light.pulseFrequency = 0
        if SERVER then
          local pulseAmount = light.SerializableProperties[Identifier("pulseAmount")]
          local pulseFrequency = light.SerializableProperties[Identifier("pulseFrequency")]
          Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(pulseAmount, light))
          Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(pulseFrequency, light))
        end
      end,5000)
      Timer.Wait(function()
          item.Condition = 100
      end,20000)
end)