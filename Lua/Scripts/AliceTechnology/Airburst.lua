local SetFuse = nil
local GlobalLauncher = {}

local function PointDistance(V1, V2)
    local dx = V2.X - V1.X
    local dy = V2.Y - V1.Y
    return math.sqrt(dx ^ 2 + dy ^ 2)
end

local function VectorVelocity(V)
    return math.sqrt(V.X ^ 2 + V.Y ^ 2)
end

local function SetTimedFuse(projectileitem, fuse)
    Timer.Wait(function()
        if projectileitem == nil then return end
        projectileitem.Condition = 0
    end,fuse)
end

local function CalculateFlyingTime(distance, initialVelocity, linearDamping)
    local tick = 0
    if linearDamping == 0 then
        -- No damping, use basic kinematic equation
        tick = distance / initialVelocity
    else
        -- With damping, solve for time using the velocity decay formula
        local decayFactor = math.exp(-linearDamping * distance / initialVelocity)
        tick = (1 - decayFactor) / linearDamping
    end
    return tick/60*500
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
            Timer.Wait(function()
            local Launcher = Projectile.Launcher
            if Launcher == nil then return end
            local User = GlobalLauncher[Launcher]
            GlobalLauncher[Launcher] = nil
            if User == nil then return end
            local CursorPosition = User.CursorWorldPosition
            local StartingPoint = Projectile.Launcher.WorldPosition --+ Projectile.Launcher.GetComponentString("RangedWeapon").barrelPos + Projectile.Launcher.GetComponentString("Holdable").AimPos
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
            SetFuse = nil
            if FuseDistance == nil then return end
            local fuse = CalculateFlyingTime(FuseDistance, ProjectileItem.body.LinearVelocity.Length(), ProjectileItem.body.FarseerBody.LinearDamping, ProjectileItem.body.FarseerBody.GravityScale)
            SetTimedFuse(ProjectileItem, fuse)
        end,1)
    end
)

