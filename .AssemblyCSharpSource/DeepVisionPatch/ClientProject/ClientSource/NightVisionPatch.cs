using Barotrauma;
using Barotrauma.Lights;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

public class NightVisionPatch
{
    public static Dictionary<ushort, bool> NightVisionStatus { get; } = new();

    private static readonly Color NightVisionLightColor = new(255, 255, 255, 150);
    private static LightSource? nightVisionLight;
    private static Character? lightCharacter;
    private static Item? lightItem;

    public NightVisionPatch(ILuaEventService luaEventService)
    {
        luaEventService.Add("NightVision_Off", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleNightVision(item, false);
            }
            return null;
        });

        luaEventService.Add("NightVision_On", (object[] args) =>
        {
            if (args.Length > 2 && args[2] is Item item)
            {
                HandleNightVision(item, true);
            }
            return null;
        });
    }

    private void HandleNightVision(Item item, bool enabled)
    {
        Character? character = Character.Controlled;
        bool isCurrentHead = character?.Inventory.GetItemInLimbSlot(InvSlotType.Head) == item;

        if (!enabled && ReferenceEquals(lightItem, item))
        {
            RemoveNightVisionLight();
            NightVisionStatus[item.ID] = false;
        }

        if (character == null || item.ParentInventory?.Owner != character)
        {
            return;
        }

        NightVisionStatus[item.ID] = enabled;
        if (enabled && isCurrentHead)
        {
            SyncControlledLight(character, item);
        }
    }

    public static bool SyncControlledLight(Character? character, Item? headItem)
    {
        bool enabled = character != null
            && headItem != null
            && NightVisionStatus.TryGetValue(headItem.ID, out bool status)
            && status;

        if (!enabled)
        {
            RemoveNightVisionLight();
            return false;
        }

        Limb? headLimb = character!.AnimController?.GetLimb(LimbType.Head);
        if (headLimb == null || headLimb.IsSevered || headLimb.Removed || headLimb.body == null)
        {
            RemoveNightVisionLight();
            return false;
        }

        if (nightVisionLight != null &&
            (!ReferenceEquals(lightCharacter, character) || !ReferenceEquals(lightItem, headItem)))
        {
            RemoveNightVisionLight();
        }

        if (nightVisionLight == null)
        {
            nightVisionLight = new LightSource(
                Vector2.Zero,
                5000f,
                NightVisionLightColor,
                character.Submarine,
                addLight: false)
            {
                CastShadows = false,
                ParentBody = headLimb.body,
                OffsetFromBody = Vector2.Zero,
                ParentSub = character.Submarine,
                Enabled = true
            };
            lightCharacter = character;
            lightItem = headItem;
            GameMain.LightManager.AddLight(nightVisionLight);
        }
        else
        {
            nightVisionLight.ParentBody = headLimb.body;
            nightVisionLight.ParentSub = character.Submarine;
            nightVisionLight.OffsetFromBody = Vector2.Zero;
            nightVisionLight.Enabled = true;
        }

        return true;
    }

    public static void RemoveNightVisionLight()
    {
        if (nightVisionLight != null)
        {
            nightVisionLight.Enabled = false;
            nightVisionLight.Remove();
            nightVisionLight = null;
        }

        lightCharacter = null;
        lightItem = null;
    }
}
