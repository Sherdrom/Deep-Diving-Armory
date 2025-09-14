Hook.Add("Deep_RefreshItem", "Deep_RefreshItem",
    function(effect, deltaTime, item, targets, worldPosition)
        local olditems = item.OwnInventory.GetItemsAt(0)
        local Prefab = olditems[1].Prefab
        local Condition = olditems[1].Condition
        local Quality = olditems[1].Quality
        for removeneededitem in olditems do 
            print(removeneededitem.Name)
            removeneededitem.Remove()
            Entity.Spawner.AddItemToSpawnQueue(Prefab, item.OwnInventory, Condition, Quality, nil, true, true, 0)
        end
    end
)