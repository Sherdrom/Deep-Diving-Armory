local ActiveRocket = {}
Hook.Add("Deep_RocketEngine", "Deep_RocketEngine",
    function(effect, deltaTime, item, targets, worldPosition)
        local identifier = item.Prefab.Identifier.Value
        if Deep_Lua.RocketConfig[identifier] == nil then return end
        ActiveRocket[item] = Deep_Lua.RocketConfig[identifier]
    end
)

Hook.Add("think", "Deep_Engine", function()
    for item,info in ActiveRocket do
        if not item.removed and not info.isDead then
            local force = item.body.LinearVelocity.Normalize() * info.EngineForce
            item.body.ApplyForce(force,info.MaxSpeed)
        end
    end
end)