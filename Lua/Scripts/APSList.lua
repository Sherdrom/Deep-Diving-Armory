Deep_Lua.APS = {
    defaultAPS = {
        minVelocity = 20,
        maxVelocity = 40,
        minsize = 100,
        probablity = 80,
        afteraction = function(item,target)
            target.Condition = -100
            item.Condition = 0
        end
    }
}