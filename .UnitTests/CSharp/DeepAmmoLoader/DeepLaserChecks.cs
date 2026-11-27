using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;

internal static class DeepLaserChecks
{
    internal static void Run(Assembly plugin, Func<string, Type> gameType, Func<string, object> item,
        Func<Type, string, FieldInfo> field)
    {
        var laser = plugin.GetType("DeepLaser.DeepLaser", true)!;
        MethodInfo Method(string name) => laser.GetMethod(name, BindingFlags.NonPublic | BindingFlags.Static)!;
        var circle = Method("TryIntersectCircle");
        var capsule = Method("TryIntersectCapsule");
        var vectorType = circle.GetParameters()[0].ParameterType;
        object V(float x, float y) => Activator.CreateInstance(vectorType, x, y)!;
        object New(string name) => RuntimeHelpers.GetUninitializedObject(gameType(name));
        void Set(object target, string name, object value) => field(target.GetType(), name).SetValue(target, value);
        object InitCollection(object target, string name)
        {
            var member = field(target.GetType(), name);
            var collection = Activator.CreateInstance(member.FieldType)!;
            member.SetValue(target, collection);
            return collection;
        }
        static void Check(bool ok, string label)
        {
            if (!ok) throw new Exception("DeepLaser: " + label);
        }
        static void Near(float actual, float expected, string label) =>
            Check(MathF.Abs(actual - expected) <= 0.0000002f, $"{label}: expected {expected:R}, got {actual:R}");
        void Intersection(MethodInfo shape, string label, float? expected, params object?[] args)
        {
            bool hit = (bool)shape.Invoke(null, args)!;
            Check(hit == expected.HasValue, label);
            if (hit) Near((float)args[^1]!, expected!.Value, label);
        }
        var start = V(0, 0);
        var right = V(1, 0);
        Intersection(circle, "circle starts inside, center behind", 0, start, right, 100f, V(-3, 0), 5f, null);
        Intersection(circle, "circle center past end", .98f, start, right, 100f, V(103, 0), 5f, null);
        Intersection(circle, "circle tangent", .5f, start, right, 100f, V(50, 8), 8f, null);
        Intersection(circle, "circle behind ray", null, start, right, 100f, V(-6, 0), 5f, null);
        Intersection(capsule, "capsule side x=42", .42f, start, right, 100f, V(50, -20), V(50, 20), 8f, null);
        Intersection(capsule, "capsule parallel, end cap", .22f, start, right, 100f, V(30, 0), V(60, 0), 8f, null);
        Intersection(capsule, "start inside strip", 0, start, right, 100f, V(2, -20), V(2, 20), 8f, null);
        Intersection(capsule, "point capsule", .45f, start, right, 100f, V(50, 0), V(50, 0), 5f, null);
        Intersection(capsule, "capsule past end", null, start, right, 100f, V(109, -20), V(109, 20), 8f, null);

        var hull = New("Lights.ConvexHull");
        var pointType = gameType("Lights.SegmentPoint");
        var points = new[] { V(-10, -10), V(10, -10), V(10, 10), V(-10, 10) };
        var vertices = Array.CreateInstance(pointType, points.Length);
        for (int i = 0; i < points.Length; i++)
            vertices.SetValue(Activator.CreateInstance(pointType, points[i], hull), i);
        Set(hull, "vertices", vertices);
        void HullEntry(object from, object segment, float expected, object position)
        {
            var hit = Method("FindHullHit").Invoke(null, [hull, from, segment])!;
            Check((bool)field(hit.GetType(), "HasHit").GetValue(hit)!, "missing hull hit");
            Near((float)field(hit.GetType(), "Fraction").GetValue(hit)!, expected, "hull entry");
            Check(position.Equals(field(hit.GetType(), "WorldPosition").GetValue(hit)), "hull position");
        }
        HullEntry(start, V(100, 0), 0, start);
        HullEntry(start, V(1, 0), 0, start);
        HullEntry(V(-20, 0), V(100, 0), .1f, V(-10, 0));
        var owner = item("hidden");
        Set(hull, "<ParentEntity>k__BackingField", owner);
        Set(hull, "enabled", true);
        Check((bool)Method("IsValidHull").Invoke(null, [hull])!, "visible hull rejected");
        owner.GetType().GetProperty("HiddenInGame")!.SetValue(owner, true);
        Check(!(bool)Method("IsValidHull").Invoke(null, [hull])!, "hidden hull accepted");

        object Sprite(float depth)
        {
            var sprite = New("Sprite");
            sprite.GetType().GetProperty("Depth")!.SetValue(sprite, depth);
            return sprite;
        }
        object AddComponent(object target, string name)
        {
            var component = New("Items.Components." + name);
            var map = (IDictionary)InitCollection(target, "componentsByType");
            var list = (IList)Activator.CreateInstance(map.GetType().GenericTypeArguments[1])!;
            list.Add(component);
            map.Add(component.GetType(), list);
            Set(component, "item", target);
            return component;
        }
        var weapon = item("deep_mac10");
        var emitter = item("deep_laser");
        Set(weapon, "activeSprite", Sprite(.55f));
        var container = New("Items.Components.ItemContainer");
        Set(container, "containedSpriteDepths", Array.Empty<float>());
        container.GetType().GetProperty("ContainedSpriteDepth")!.SetValue(container, -1f);
        var inventory = New("ItemInventory");
        Set(inventory, "Owner", weapon);
        Set(inventory, "container", container);
        Set(emitter, "parentInventory", inventory);

        (float Weapon, float Attachment, float Beam) Depths(object? holder, float rail, float? gunsmith = null)
        {
            Set(emitter, "activeSprite", Sprite(rail));
            return ((float, float, float))Method("GetLaserDepths").Invoke(null, [weapon, emitter, holder, gunsmith.HasValue, gunsmith])!;
        }
        void CheckDepth(object? holder, float expectedWeapon, float rail, float? gunsmith = null)
        {
            var d = Depths(holder, rail, gunsmith);
            Near(d.Weapon, expectedWeapon, "weapon depth");
            float offset = gunsmith.HasValue ? gunsmith.Value - .55f : (rail - .55f) / 10000f;
            Check(d.Attachment == d.Weapon + offset, "attachment relative depth");
            Check(d.Attachment < d.Beam && (offset < 0 ? d.Beam <= d.Weapon : d.Weapon < d.Beam), "rail mask ordering");
        }
        CheckDepth(null, .55f, .551f);
        CheckDepth(null, .55f, .54f);

        // Use the installed client's actual hand slots, arm sprites and ladder offset.
        var holder = New("Character");
        var controller = New("HumanoidAnimController");
        Set(holder, "AnimController", controller);
        Set(controller, "character", holder);
        var limbs = (IDictionary)InitCollection(controller, "limbDictionary");
        foreach (var (name, depth) in new[] { ("RightArm", .02f), ("LeftArm", .14f), ("Head", .05f) })
        {
            var limb = New("Limb");
            Set(limb, "<Sprite>k__BackingField", Sprite(depth));
            InitCollection(limb, "<ConditionalSprites>k__BackingField");
            InitCollection(limb, "WearingItems");
            limbs.Add(Enum.Parse(gameType("LimbType"), name), limb);
        }
        var limbArray = Array.CreateInstance(gameType("Limb"), limbs.Count);
        limbs.Values.CopyTo(limbArray, 0);
        Set(controller, "limbs", limbArray);
        Set(AddComponent(weapon, "Holdable"), "picker", holder);
        var hands = New("CharacterInventory");
        Set(holder, "<Inventory>k__BackingField", hands);
        var slots = (IDictionary)InitCollection(hands, "slotsByType");
        var handSlot = Activator.CreateInstance(gameType("Inventory+ItemSlot"), hands)!;
        ((IList)field(handSlot.GetType(), "items").GetValue(handSlot)!).Add(weapon);
        var slotList = (IList)Activator.CreateInstance(slots.GetType().GenericTypeArguments[1])!;
        slotList.Add(handSlot);
        var slotType = gameType("InvSlotType");
        slots.Add(Enum.Parse(slotType, "LeftHand"), slotList);
        CheckDepth(holder, .139998f, .551f);
        slots.Clear();
        slots.Add(Enum.Parse(slotType, "RightHand"), slotList);
        CheckDepth(holder, .020002f, .551f);
        CheckDepth(holder, .020002f, .54f);
        CheckDepth(holder, .020002f, .551f, .5525f);
        CheckDepth(holder, .020002f, .54f, .5475f);
        var ladder = item("ladder");
        Set(ladder, "activeSprite", Sprite(.51f));
        AddComponent(ladder, "Ladder");
        Set(holder, "<SelectedSecondaryItem>k__BackingField", ladder);
        var collider = New("PhysicsBody");
        var body = field(collider.GetType(), "<FarseerBody>k__BackingField");
        body.SetValue(collider, RuntimeHelpers.GetUninitializedObject(body.FieldType));
        ((IList)InitCollection(controller, "collider")).Add(collider);
        CheckDepth(holder, .570002f, .551f);
        CheckDepth(holder, .570002f, .54f, .5475f);
        var ladderRect = field(ladder.GetType(), "rect");
        ladderRect.SetValue(ladder, Activator.CreateInstance(ladderRect.FieldType, 100, 0, 32, 64));
        CheckDepth(holder, .510102f, .54f);

        var characters = (IList)holder.GetType().GetField("CharacterList")!.GetValue(null)!;
        var bodyLimb = New("Limb");
        var limbParams = field(bodyLimb.GetType(), "Params");
        limbParams.SetValue(bodyLimb, RuntimeHelpers.GetUninitializedObject(limbParams.FieldType));
        var limbBody = New("PhysicsBody");
        Set(bodyLimb, "body", limbBody);
        var oneLimb = Array.CreateInstance(gameType("Limb"), 1);
        oneLimb.SetValue(bodyLimb, 0);
        Set(controller, "limbs", oneLimb);
        Set(holder, "enabled", true);
        Set(collider, "isEnabled", true);
        Set(bodyLimb, "_alpha", 1f);
        Set(limbBody, "drawPosition", V(60, 0));
        void CharacterEntry(float? expected)
        {
            var hit = Method("FindCharacterHit").Invoke(null, [start, V(100, 0), null])!;
            Check((bool)field(hit.GetType(), "HasHit").GetValue(hit)! == expected.HasValue, "character hit filter");
            if (expected.HasValue) Near((float)field(hit.GetType(), "Fraction").GetValue(hit)!, expected.Value, "character entry");
        }
        characters.Add(holder);
        try
        {
            CharacterEntry(null); // Disabled limbs must not fall back to the enabled center collider.
            Set(limbBody, "isEnabled", true);
            CharacterEntry(.5f);
            Set(bodyLimb, "_alpha", 0f);
            CharacterEntry(null);
            Set(bodyLimb, "_alpha", 1f);
            Set(bodyLimb, "_hidden", true);
            CharacterEntry(null);
            Set(controller, "limbs", Array.CreateInstance(gameType("Limb"), 0));
            CharacterEntry(0f);
        }
        finally { characters.Remove(holder); }

        Set(weapon, "body", collider);
        Set(collider, "drawRotation", MathF.PI / 6f);
        foreach (float facing in new[] { 1f, -1f })
        {
            Set(collider, "dir", facing);
            object?[] args = [weapon, emitter, null, null, null, null, null, null, null];
            Check((bool)Method("TryGetLaserTransform").Invoke(null, args)! && Equals(args[2], false), "native laser transform");
            Near((float)vectorType.GetField("X")!.GetValue(args[5])!, facing * MathF.Sqrt(.75f), "beam draw direction X");
            Near((float)vectorType.GetField("Y")!.GetValue(args[5])!, facing * .5f, "beam draw direction Y");
        }
        Console.WriteLine("DeepLaser geometry, visibility, draw direction and weapon/rail depths PASS");
    }
}
