SetFuse = nil
local GlobalLauncher = {}

local function PointDistance(V1, V2)
    local dx = V2.X - V1.X
    local dy = V2.Y - V1.Y
    return math.sqrt(dx ^ 2 + dy ^ 2)
end

local function VectorVelocity(V)
    return math.sqrt(V.X ^ 2 + V.Y ^ 2)
end

local function SetTimedFuse(projectileitem, range, speedvector)
    local velocity = VectorVelocity(speedvector)
    local tick = range / velocity * 8.333  -- Cant determine what this multiplier is, help required.
    Timer.Wait(function()
        projectileitem.Condition = 0
    end,time)
end

Hook.Add("Deep_AirBurstBound", "Deep_AirBurstBound",
    function(effect, deltaTime, item, targets, worldPosition) -- Bound item user
        local UsingCharacter = targets[1]
        local LauncherItem = item
        GlobalLauncher[LauncherItem] = UsingCharacter
    end)

Hook.Add("Deep_AirBurstControl", "Deep_AirBurstControl",
    function(effect, deltaTime, item, targets, worldPosition) -- Projectile stuff
        local dataX = nil
        local dataY = nil
        local ProjectileItem = item
        local Projectile = item.GetComponentString("Projectile")
        if Projectile == nil then
            return
        end
        local Launcher = Projectile.Launcher
        if Launcher == nil then return end
        local User = GlobalLauncher[Launcher]
        GlobalLauncher[Launcher] = nil
        if User == nil then return end
        local CursorPosition = User.CursorWorldPosition
        local StartingPoint = Projectile.Launcher.WorldPosition
        local FuseDistance = PointDistance(User.CursorWorldPosition, Projectile.Launcher.WorldPosition)
        if CLIENT and Game.IsMultiplayer then
            local message = Networking.Start("Fuse")
            message.WriteDouble(FuseDistance)
            Networking.Send(message)
            FuseDistance = nil
            return
        end
        if SERVER and Game.IsMultiplayer then
            FuseDistance = nil
            Networking.Receive("Fuse", function(message, client)
                SetFuse = message.ReadDouble()
            end)
        end
        FuseDistance = SetFuse or FuseDistance
        print(FuseDistance)
        SetFuse = nil
        if FuseDistance == nil then return end
        SetTimedFuse(Launcher, ProjectileItem, FuseDistance, ProjectileItem.body.LinearVelocity)
    end)