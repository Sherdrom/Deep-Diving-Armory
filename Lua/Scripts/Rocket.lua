local ActiveRocket = {}
Hook.Add("Deep_RocketEngine", "Deep_RocketEngine",
    function(effect, deltaTime, item, targets, worldPosition)
        local identifier = item.Prefab.Identifier.Value
        if Deep_Lua.RocketConfig[identifier] == nil then return end
        ActiveRocket[item] = Deep_Lua.RocketConfig[identifier]
        ActiveRocket[item].Launchtime = Timer.GetTime()
        item.body.FarseerBody.AngularVelocity = 0
        item.body.FarseerBody.GravityScale  = 0
    end
)

Hook.Add("think", "Deep_Engine", function()
    for item,info in pairs(ActiveRocket) do
        if (not item.removed) and info ~= nil then
            local force = Vector2.Normalize(item.body.LinearVelocity) * info.EngineForce
            item.body.ApplyLinearImpulse(force,info.MaxSpeed)
            if Timer.GetTime() > (info.burntime + info.Launchtime) then
                ActiveRocket[item] = nil
            end
        end
    end
end)