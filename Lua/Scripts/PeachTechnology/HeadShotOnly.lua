Hook.Patch("Barotrauma.CharacterHealth", "AddLimbAffliction",
{
    "Barotrauma.Limb",
    "Barotrauma.Affliction",
    "System.Boolean",
    "System.Boolean"
},
function(instance, p)
    local affliction = p["newAffliction"]
    local identifier = tostring(affliction.Prefab.Identifier)
    if identifier ~= "deep_headshot_deadly" and identifier ~= "deep_headshot_deadly_irresistible" then
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