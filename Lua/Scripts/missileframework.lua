if NAT_MissileFramework == true then end--do nothing bcuz the framework does not exist yet :)

LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.Turret"], "targetRotation")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Items.Components.Turret"], "set_Rotation")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Items.Components.Turret"], "Launch")

local locktarget = {}
local Missile = {}
local launchercd = {}
Missile.__index = Missile

-- helpfunc

function Missile:getMissile(item, Launcher, Target, isTurretLaunched)
    local data = {}
    setmetatable(data, Missile)
	data.item = item
	data.launcher = Launcher
	data.destarget = Target
	data.msldata = Deep_Lua.MissileConfigs[item.Prefab.Identifier.Value]
	data.isTurretLaunched = isTurretLaunched
	data.isAuto = Deep_Lua.MissileConfigs[item.Prefab.Identifier.Value].IS_AUTO_GUIDED
	data.isDead = false
	data.tick = 0
    return data
end
local function getEndPoint(Vect, distance, ang)
    return Vector2(Vect.X + distance * math.cos(ang),Vect.Y + distance * math.sin(-ang))
end
local function sign(value)
	if value > 0 then return 1 end
	if value < 0 then return -1 end
	return 0
end
local function lerp(initval, endval, t)
	return initval + (endval - initval) * t
end
local function clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end
	return value
end
local function radToVec(rad)
	return Vector2(math.cos(rad), math.sin(rad))
end
local function radToDeg(rad)
	return rad * (180/math.pi)
end
local function getDirection(vector)
	return math.atan2(vector.Y, vector.X)
end

local ActiveMissiles = {}

Hook.Add("roundEnd", "resetonstart", function() --reset
    locktarget = {}
	ActiveMissiles = {}
end)

Hook.Patch("Barotrauma.Items.Components.Projectile", "Launch",function(instance,ptable)
	local projectile = instance.item
	if projectile == nil or not projectile.HasTag("saclosmsl") then return end
	local aimarget = nil
	local newMissile = Missile:getMissile(projectile, instance.Launcher, aimarget, false)
	table.insert(ActiveMissiles, newMissile)
end,Hook.HookMethodType.Before)--Add projectile to upd table when launched, for handholds
-- Very fair, turret launch doesn't counts for projectile launch :)

Hook.Patch("Barotrauma.Items.Components.Turret", "Launch", function(instance,ptable)
	local projectile = ptable["projectile"]
	local aimtarget = nil
	local gunrotation = instance.Rotation
	local sub = instance.item.Submarine
	if launchercd[instance.item] == true then
		ptable.preventExecution = true
		return
	end
	if projectile == nil or not projectile.HasTag("saclosmsl") then return end
	if Deep_Lua.MissileConfigs[projectile.Prefab.Identifier.Value] == nil then return end
	if Deep_Lua.MissileConfigs[projectile.Prefab.Identifier.Value].IS_AUTO_GUIDED then
		local prefab = ItemPrefab.GetItemPrefab("msl_targetmarker")
		Entity.Spawner.AddItemToSpawnQueue(prefab, instance.item.OwnInventory , nil, nil, nil)
		local mslmarker = instance.item.OwnInventory.FindItemByIdentifier("msl_targetmarker",false)
		instance.Launch(mslmarker,ptable["user"], ptable["launchRotation"],  ptable["tinkeringStrength"] )
		aimtarget = locktarget[instance.item]
		locktarget[instance.item] = nil -- immediately clear table value to avoid issue
		--[[ For future use for lock range limits
		if then
			ptable.preventExecution = true
		end
		]]
		if aimtarget == nil then
			ptable.preventExecution = true
			return
		end
	end
	if instance.item.HasTag("vls") then
		instance.RotationLimits = Vector2(0,360)                             --Remove rotationlimit to allow guidence
		instance.set_Rotation(instance.item.RotationRad - math.pi * 0.5)     --Launch "Vertically"
	end
	local newMissile = Missile:getMissile(projectile, instance, aimtarget, true)
	aimtarget = nil
	table.insert(ActiveMissiles, newMissile)
	launchercd[instance.item] = true
	Timer.Wait(function() launchercd[instance.item] = nil end, 10)
end,Hook.HookMethodType.Before)-- Use before instad of after to get locked on target

Hook.Add("item.removed", "CBRN_SACLOS_RemoveMissile", function(item)
	if not item.HasTag("saclosmsl") then return end
	for index, value in pairs(ActiveMissiles) do
		if value == item then
			table.remove(ActiveMissiles, index)
			break
		end
	end
end)--Remove projectile from upd table when it is removed

Hook.Patch("Barotrauma.Item", "ApplyWaterForces", function(instance,ptable)
	if Deep_Lua.MissileConfigs[instance.Prefab.Identifier.Value] ~= nil then
		ptable.PreventExecution = Deep_Lua.MissileConfigs[instance.Prefab.Identifier.Value].DISABLE_RESISTANCE
	end
end)

Hook.Patch("Barotrauma.Items.Components.Projectile", "Use", {"Barotrauma.Character", "System.Single"}, function(instance,ptable)
	if Deep_Lua.MissileConfigs[instance.item.Prefab.Identifier.Value] ~= nil then
		local launchimpulse = Deep_Lua.MissileConfigs[instance.item.Prefab.Identifier.Value].INIT_LAUNCH_SPEED
		ptable["launchImpulseModifier"] = Single(launchimpulse)
		return
	end
end)


-- todo: Lost LOS when LOS was cut off by something
Hook.Add("think", "CBRN_SACLOS_Guide", function ()
	if CLIENT and Game.Paused then return end
	if Game.GameSession == nil then return end
	
    for missile in ActiveMissiles do
		if not missile.item.removed and not missile.isDead then
			
			missileVelocity = missile.item.body.LinearVelocity
			missileDirection = getDirection(missileVelocity)

			propulsionForce = radToVec(missileDirection) * missile.msldata.MAX_ACCELERATION
			missile.item.body.ApplyLinearImpulse(propulsionForce)

			if missile.isTurretLaunched then
				WeaponDirection = missile.launcher.targetRotation
			else
				if missile.launcher.ParentInventory.Owner == nil then return end
				WeaponDirection = -getDirection(missile.launcher.ParentInventory.Owner.CursorPosition-missile.launcher.ParentInventory.Owner.Position)
			end
			--math works related to weapon directions
			WeaponDirection = sign(WeaponDirection) * ( math.pi - math.abs(WeaponDirection))
			WeaponDirection = WeaponDirection - math.floor(WeaponDirection / 2.0 / math.pi) * 2.0 * math.pi - math.pi

			steeringForce = (radToVec(WeaponDirection) - radToVec(missileDirection)) / missile.msldata.TOLERANCE * missile.msldata.MAX_STEERING_FORCE


			if missile.isTurretLaunched then
				WeaponPosition = missile.launcher.item.WorldPosition
			else
				WeaponPosition = missile.launcher.WorldPosition
			end

			missilePosition = missile.item.WorldPosition
			WeaponDirectionVector = radToVec(WeaponDirection)
			closestPointOnLOS = WeaponPosition + Vector2.dot(missilePosition - WeaponPosition, WeaponDirectionVector) * WeaponDirectionVector
			
			correctionDirection = Vector2.Normalize(closestPointOnLOS - missilePosition)

			if missile.msldata.CAN_LOST_LOS and math.abs(getDirection(correctionDirection)) > missile.msldata.FOV * math.pi then
				return
			end

			correctionMagnitude = lerp(0, missile.msldata.MAX_CORRECTION_FORCE, clamp((closestPointOnLOS - missilePosition).Length() / (1000 * missile.msldata.AVR_G_FORCE_MULTIPLIER), 0, missile.msldata.STEERAGE_MULTIPLIER))
			--Larger multiplier means less force, means a softer curve

			correctionForce = correctionDirection * correctionMagnitude

			missile.item.body.ApplyLinearImpulse(steeringForce + correctionForce)
				
			-- missle visual turning
			bodyDirection = missile.item.body.TransformedRotation
			bodyDirection = bodyDirection - math.floor((bodyDirection + math.pi)/ 2.0 / math.pi) * 2.0 * math.pi
			turnMagnitude = (radToVec(missileDirection) - radToVec(bodyDirection)).Length() * 0.1
			bodyDirectionVector = radToVec(bodyDirection)
			turnDirection = sign(bodyDirectionVector.X * missileVelocity.Y - bodyDirectionVector.Y * missileVelocity.X) -- cross product
			missile.item.body.ApplyTorque(turnMagnitude * turnDirection)
			missile.item.body.SmoothRotate(missileDirection, 30, true)

			end
		end
end)

Hook.Add("msl.marktarget", "msl.marktarget", function(effect, deltaTime, item, targets, worldPosition)
    if targets == nil then return end
	local launcher = item.GetComponentString("Projectile").Launcher
    local target = targets[1]
	locktarget[launcher] = target
end)


-- Original Code created by 4SunnyH