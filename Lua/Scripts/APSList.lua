local function IsOBJApproaching(pos1, pos2, velocity1, velocity2)
    local deltaPos = pos2 - pos1
    local relativeVel = velocity2 - velocity1
    return deltaPos.X * relativeVel.X + deltaPos.Y * relativeVel.Y < 0
end

Deep_Lua.APS = {
    defaultAPS = {
        minVelocity = 5,
        maxVelocity = 30,
        minsize = 0,
        probability = 0.95,
        range = 300,
        action = function(activeapsdata)
            if activeapsdata.prevtarget == nil then activeapsdata.prevtarget = {} end
            if not IsOBJApproaching(activeapsdata.apstarget.WorldPosition, activeapsdata.apsitem.WorldPosition, activeapsdata.apstarget.body.LinearVelocity, activeapsdata.apsitem.body.LinearVelocity) then return end
            if not activeapsdata.prevtarget[activeapsdata.apstarget] == true then
                activeapsdata.prevtarget[activeapsdata.apstarget] = true
                Explosion(50, 30, 50, 50, 50, 0, 0).Explode(activeapsdata.apstarget.WorldPosition, nil)
            end
            if Deep_Lua.HF.DoChance(activeapsdata.probability) then
                Entity.Spawner.AddItemToRemoveQueue(activeapsdata.apstarget)
            end
            activeapsdata.apsitem.Condition = 0
        end
    },
    deep_APS = {
        minVelocity = 5,
        maxVelocity = 30,
        minsize = 0,
        probability = 0.95,
        range = 300,
        action = function(activeapsdata)
            if activeapsdata.triggered == nil then activeapsdata.triggered = false end
            if activeapsdata.prevtarget == nil then activeapsdata.prevtarget = {} end
            if not IsOBJApproaching(activeapsdata.apstarget.WorldPosition, activeapsdata.apsitem.WorldPosition, activeapsdata.apstarget.body.LinearVelocity, activeapsdata.apsitem.body.LinearVelocity) then return end
            local light = activeapsdata.apsitem.GetComponentString("LightComponent")
            light.pulseAmount = 1.0
            light.pulseFrequency = 2.5
            if SERVER then
                local pulseAmount = light.SerializableProperties[Identifier("pulseAmount")]
                local pulseFrequency = light.SerializableProperties[Identifier("pulseFrequency")]
                Networking.CreateEntityEvent(activeapsdata.apsitem, Item.ChangePropertyEventData(pulseAmount, light))
                Networking.CreateEntityEvent(activeapsdata.apsitem, Item.ChangePropertyEventData(pulseFrequency, light))
            end
            if not activeapsdata.prevtarget[activeapsdata.apstarget] == true then
                activeapsdata.prevtarget[activeapsdata.apstarget] = true
                Explosion(50, 30, 50, 50, 50, 0, 0).Explode(activeapsdata.apstarget.WorldPosition, nil)
            end
            if Deep_Lua.HF.DoChance(activeapsdata.probability) then
                Entity.Spawner.AddItemToRemoveQueue(activeapsdata.apstarget)
            end
            if activeapsdata.triggered ~= true then
                activeapsdata.triggered = true
                Timer.Wait(function()
                    activeapsdata.prevtarget = {}
                    activeapsdata.apsitem.Condition = 0
                    light.pulseAmount = 0.0
                    light.pulseFrequency = 0
                    if SERVER then
                        local pulseAmount = light.SerializableProperties[Identifier("pulseAmount")]
                        local pulseFrequency = light.SerializableProperties[Identifier("pulseFrequency")]
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