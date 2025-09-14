local RemoveList = {}

Hook.Add("Deep_RefreshItem", "Deep_RefreshItem",
    function(effect, deltaTime, item, targets, worldPosition)
        for olditem in targets do
            if LuaUserData.IsTargetType(olditem, "Barotrauma.Item") then
                local Prefab = olditem.Prefab
                local Condition = olditem.Condition
                local Quality = olditem.Quality
                Entity.Spawner.AddItemToSpawnQueue(Prefab, item.OwnInventory, Condition, Quality,
                function(spawned)
                    item.OwnInventory.RemoveItem(olditem)
                    item.OwnInventory.TryPutItem(spawned, 1, false, true, nil, true, true)
                    item.OwnInventory.TryPutItem(spawned, 1, false, true, nil, true, true)
                end,true,true, 1)
            end
        end
    end
)