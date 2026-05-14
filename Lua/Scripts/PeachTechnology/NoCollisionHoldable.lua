local DEBUG = false

local function log(...)
	if DEBUG then
		print("[NoCollisionHoldable]", ...)
	end
end

Hook.Patch(
	"Barotrauma.Items.Components.Holdable",
	"OnPusherCollision",
	{
		"FarseerPhysics.Dynamics.Fixture",
		"FarseerPhysics.Dynamics.Fixture",
		"FarseerPhysics.Dynamics.Contacts.Contact"
	},
	function(instance, ptable)
		local other = ptable["other"]
		if other == nil then
			return
		end

		local userData = other.Body.UserData
		if userData == nil then
			return
		end

		if LuaUserData.HasMember(userData, "IsHuman") then
			log("Pusher passes through: " .. userData.Name)
			ptable.PreventExecution = true
			return false
		end

		ptable.PreventExecution = true
		return true
	end,
	Hook.HookMethodType.Before
)