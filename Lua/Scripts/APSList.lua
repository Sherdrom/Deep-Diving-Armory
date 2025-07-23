Deep_Lua.APS = {
    defaultAPS = {
        minVelocity = 5,
        maxVelocity = 40,
        minsize = 0,
        probability = 100,
        action = function(item,target,prob)
            Game.Explode(target.WorldPosition,50,15,10,10,10,0,0)
            if Deep_Lua.HF.DoChance(prob) then
                target.Condition = -100
            end
            item.Condition = 0
        end
    }
}