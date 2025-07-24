Deep_Lua.APS = {
    defaultAPS = {
        minVelocity = 5,
        maxVelocity = 30,
        minsize = 0,
        probability = 0.95,
        action = function(item,target,prob)
            Game.Explode(target.WorldPosition,50,15,10,10,10,0,0)
            if Deep_Lua.HF.DoChance(prob) then
                Entity.Spawner.AddItemToRemoveQueue(target)
                --target.Condition = -100
                --target.body.LinearVelocity = target.body.LinearVelocity * 0.2
            end
            item.Condition = 0
            Timer.Wait(
                function()
                    item.Condition = 100
                end
            ,8000)
        end
    }
}