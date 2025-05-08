SetFuse = nil
local UpdateAmmo = {}
local GlobalLauncher = {}

local function PointDistance(V1, V2)
    local dx = V2.X - V1.X
    local dy = V2.Y - V1.Y
    return math.sqrt(dx ^ 2 + dy ^ 2)
end

local function VectorVelocity(V)
    return math.sqrt(V.X * V.X + V.Y * V.Y)
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
        if Launcher == nil then
            return
        end
        Timer.Wait(function()
            local User = GlobalLauncher[Launcher]
            GlobalLauncher[Launcher] = nil
            if User == nil then
                return
            end
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
            SetFuse = nil
            UpdateAmmo[ProjectileItem] = {
                FuseDistance = FuseDistance,
                StartingPoint = StartingPoint
            }
        end, 1)
    end)

Hook.Add("think", "Deep_AirBurstUpdate", function() -- Projectile update
    for item, data in pairs(UpdateAmmo) do
        if data == nil then
            break
        end
        local itemvelocity = item.body.LinearVelocity
        if item.WorldPosition == nil or data.StartingPoint == nil or data.FuseDistance == nil then
            UpdateAmmo[item] = nil
            return
        end
        if PointDistance(item.WorldPosition, data.StartingPoint) >= data.FuseDistance then
            item.Condition = 0
            UpdateAmmo[item] = nil
            return
        end
        if VectorVelocity(itemvelocity) <= 5 then -- Consider a projectile is dead if moving way too slow
            UpdateAmmo[item] = nil
            return
        end
    end
end)

Hook.Add("item.removed", "Deep_RoundsRemoved", function(item) -- Removed projectiles
    if not item.HasTag("xm25round") then
        return
    end
    UpdateAmmo[item] = nil
end)
