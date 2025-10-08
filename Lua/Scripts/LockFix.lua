Hook.Add("roundStart", "Deep_LuaLockFixer", function()
    for item in Item.ItemList do
        if  item.prefab.ContentPackage.Name == "Deep Diving Armory" and (item.NonInteractable or item.NonPlayerTeamInteractable) then
            item.NonInteractable = false
            item.NonPlayerTeamInteractable = false
            item.Condition = 100
        end
    end
end)