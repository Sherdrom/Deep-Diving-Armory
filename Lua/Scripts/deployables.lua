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

local function CheckValidExplosion(item)                                                        --bloody hell this is shit i am sorry
    for _, component in pairs(item.Components) do
        if component.statusEffectLists then
            for __, statusEffectList in pairs(component.statusEffectLists) do
                for ___, statusEffect in pairs(statusEffectList) do
                    local SEs = Util.ConvertIEnumerableToDictionary(statusEffect)
                    for _____, explosion in pairs(SEs) do
                        if explosion and explosion.Attack and explosion.Attack.Range >= 50 then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

Hook.Add("Deep_APS", "Deep_APS",
    function(effect, deltaTime, item, targets, worldPosition)
        for target in targets do
            if target.GetComponentString("Throwable") or target.GetComponentString("Projectile") then
                if CheckValidExplosion(target) then
                    target.Health = -100
                    item.Health = 0
                end
            end
        end
    end
)