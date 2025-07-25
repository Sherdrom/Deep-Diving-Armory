Deep_Lua.APS = {
    defaultAPS = {
        minVelocity = 5,
        maxVelocity = 30,
        minsize = 0,
        probability = 0.95,
        action = function(activeapsdata)
            if activeapsdata.triggered == nil then activeapsdata.triggered = false end
            Game.Explode(activeapsdata.apstarget.WorldPosition, 50, 30, 50, 50, 50, 0, 0)
            local light = activeapsdata.apsitem.GetComponentString("LightComponent")
            light.pulseAmount = 1.0
            light.pulseFrequency = 2.5
            if SERVER then
                local pulseAmount = light.SerializableProperties[Identifier("pulseAmount")]
                local pulseFrequency = light.SerializableProperties[Identifier("pulseFrequency")]
                Networking.CreateEntityEvent(activeapsdata.apsitem, Item.ChangePropertyEventData(pulseAmount, light))
                Networking.CreateEntityEvent(activeapsdata.apsitem, Item.ChangePropertyEventData(pulseFrequency, light))
            end
            if Deep_Lua.HF.DoChance(activeapsdata.probability) then
                Entity.Spawner.AddItemToRemoveQueue(activeapsdata.apstarget)
            end
            if activeapsdata.triggered ~= true then
                activeapsdata.triggered = true
                Timer.Wait(function()
                    activeapsdata.apsitem.Condition = 0
                    light.pulseAmount = 0.0
                    light.pulseFrequency = 0
                    if SERVER then
                        pulseAmount = light.SerializableProperties[Identifier("pulseAmount")]
                        pulseFrequency = light.SerializableProperties[Identifier("pulseFrequency")]
                        Networking.CreateEntityEvent(activeapsdata.apsitem, Item.ChangePropertyEventData(pulseAmount, light))
                        Networking.CreateEntityEvent(activeapsdata.apsitem, Item.ChangePropertyEventData(pulseFrequency, light))
                    end
                end,5000)
                Timer.Wait(function()
                    activeapsdata.apsitem.Condition = 100
                    activeapsdata.triggered = false
                end,20000)
            end
        end
    }
}