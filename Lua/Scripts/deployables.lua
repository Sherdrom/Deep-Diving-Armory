LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Controller"], "targetRotation")

Hook.Add("Deep_DeployableControl", "Deep_DeployableControl",
    function(effect, deltaTime, item, targets, worldPosition)
        local Controller = item.GetComponentString("Controller")
        if Controller == nil then return end
        local displayitem = item.OwnInventory.GetItemsAt(1)[1]  --this slot should be hidden
        if displayitem == nil then return end

        displayitem.Rotation = Controller.targetRotation
        Controller.State = true
        if Controller.State then
            displayitem.Use(deltaTime, Controller.user, nil, nil, Controller.user)
        end
        local ammoitem = item.OwnInventory.GetItemsAt(0)[1]
        local ammo = ammoitem.OwnInventory.GetItemsAt(0)[1]
        local ammoslot = displayitem.OwnInventory
        ammoslot.TryPutItem(ammo,1,false,false,Controller.user,true,false)
        ammoitem.Use(deltaTime, nil, nil, nil, nil)
    end
)


Hook.Add("Deep_APS", "Deep_APS",
    function(effect, deltaTime, item, targets, worldPosition)
        local apsinfo = Deep_Lua.APS[item.Prefab.Identifier.Value] or Deep_Lua.APS.defaultAPS
        for target in targets do
            if LuaUserData.IsTargetType(target, "Barotrauma.Item") and target.Condition > 0 then
                if target.GetComponentString("Throwable") or target.GetComponentString("Projectile") then
                    if target.body.Height * target.body.Width >= apsinfo.minsize and (target.body.LinearVelocity.Length() >= apsinfo.minVelocity and target.body.LinearVelocity.Length() <= apsinfo.maxVelocity) then                    --Ah fuck those explosion based detection. We only care about speed and size
                        if Submarine.CheckVisibility(item.SimPosition,target.SimPosition,false,false,true,true,true) == nil then
                            apsinfo.action(item,target,apsinfo.probability)
                        end
                    end
                end
            end
        end
    end
)