local ActiveAPS = {}
local ActiveProjectiles = {}

Hook.Patch("Barotrauma.Items.Components.Projectile", "Shoot", function(instance, ptable)
    if instance.Hitscan then return end
    if ActiveProjectiles[instance.item] then return end
    ActiveProjectiles[instance.item] = true
end, Hook.HookMethodType.After)

Hook.Patch("Barotrauma.Items.Components.Throwable", "Use", function(instance, ptable)
    if ActiveProjectiles[instance.item] then return end
    ActiveProjectiles[instance.item] = true
end, Hook.HookMethodType.After)

Hook.Add("item.removed", "APSRemoveProjectile", function(item)
   if ActiveProjectiles[item] then
       ActiveProjectiles[item] = nil
   end
end)

Hook.Add("Deep_APS", "Deep_APS",
    function(effect, deltaTime, item, targets, worldPosition)
        local apsinfo = Deep_Lua.APS[item.Prefab.Identifier.Value] or Deep_Lua.APS.defaultAPS
        if ActiveAPS[item] == nil then ActiveAPS[item] = {} end
        for target, value in pairs(ActiveProjectiles) do
            if not target.Removed and not target.IsContained then
                if (target.WorldPosition - item.WorldPosition).Length() <= apsinfo.range then
                    if target.body.Height * target.body.Width >= apsinfo.minsize and (target.body.LinearVelocity.Length() >= apsinfo.minVelocity and target.body.LinearVelocity.Length() <= apsinfo.maxVelocity) then
                        if Submarine.CheckVisibility(item.SimPosition,target.SimPosition,false,false,true,true,true) == nil then
                            if ActiveAPS[item] == nil then
                                ActiveAPS[item] = {
                                    apsitem = item,
                                    apstarget = target,
                                    probability = apsinfo.probability
                                }
                            else
                                ActiveAPS[item].apsitem = item
                                ActiveAPS[item].apstarget = target
                                ActiveAPS[item].probability = apsinfo.probability
                            end
                            apsinfo.action(ActiveAPS[item])
                        end
                    end
                end
            else
                if ActiveProjectiles[target] then
                    ActiveProjectiles[item] = nil
                end
            end
        end
    end
)


Hook.Add("roundEnd", "roundEndReset", function()
    ActiveAPS = {}
    ActiveProjectiles = {}
end)