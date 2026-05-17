local DEADLY_AFFLICTIONS = {
	deep_headshot_deadly = true,
	deep_headshot_deadly_irresistible = true,
}

Hook.Patch("Barotrauma.CharacterHealth", "AddLimbAffliction",
{
	"Barotrauma.Limb",
	"Barotrauma.Affliction",
	"System.Boolean",
	"System.Boolean"
},
function(instance, p)
	local identifier = tostring(p["newAffliction"].Prefab.Identifier)
	if not DEADLY_AFFLICTIONS[identifier] then
		return
	end

	local character = instance.Character
	if not character.IsHuman then
		p.PreventExecution = true
		return
	end

	local limb = p["limb"]
	if limb == nil or limb.type ~= LimbType.Head then
		p.PreventExecution = true
		return
	end
end, Hook.HookMethodType.Before)