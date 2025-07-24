Deep_Lua.APS = {
    defaultAPS = {
        minVelocity = 5,
        maxVelocity = 30,
        minsize = 0,
        probability = 0.95,
        action = function(activeapsdata)
            if activeapsdata.triggered == nil then activeapsdata.triggered = false end
            Game.Explode(activeapsdata.apstarget.WorldPosition, 50, 30, 50, 50, 50, 0, 0)
            if Deep_Lua.HF.DoChance(activeapsdata.probability) then
                Entity.Spawner.AddItemToRemoveQueue(activeapsdata.apstarget)
            end
            if (not activeapsdata.triggered == true) then
                activeapsdata.triggered = true
                Timer.Wait(function()
                    activeapsdata.apsitem.Condition = 0
                end,5000)
                Timer.Wait(function()
                    activeapsdata.apsitem.Condition = 100
                    activeapsdata.triggered = false
                end,20000)
            end
        end
    }
}