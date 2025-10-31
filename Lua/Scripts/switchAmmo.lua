LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Items.Components.RangedWeapon"], "IsSuitableProjectile")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.RangedWeapon"], "suitableProjectiles")

Hook.Patch("Barotrauma.Items.Components.RangedWeapon", "IsSuitableProjectile", function(instance, ptable)
    if ptable["projectile"] == nil then return end
    local idarray = {}
    for id in instance.suitableProjectiles do
        table.insert(idarray,id)
    end
    if instance.item == nil then return end
    if instance.item.GetComponentString("LightComponent") == nil then return end
    if not instance.item.GetComponentString("LightComponent").IsOn then
        ptable.ReturnValue = (idarray[1] == ptable["projectile"].Item.Prefab.Identifier)
    else
        ptable.ReturnValue = (idarray[2] == ptable["projectile"].Item.Prefab.Identifier)
    end
    --ptable.PreventExecution = true
end,1)