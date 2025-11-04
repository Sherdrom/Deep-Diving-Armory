using Barotrauma;
using Barotrauma.Networking;
using Barotrauma.Particles;
using Barotrauma.Sounds;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Barotrauma.Items.Components
{
    partial class SwitchableRangedWeapon : RangedWeapon
    {

        private Keys modeswitchkey;

        [Serialize("F", IsPropertySaveable.No)]
        public string switchKey
        {
            get
            {
                return ((char)modeswitchkey).ToString();
            }
            set
            {
                object Key;
                bool success = Enum.TryParse(typeof(Keys), value, out Key);
                modeswitchkey = success ? (Keys)Key : Keys.F;
                if (!success)
                {
                    DebugConsole.AddWarning($"Invalid {nameof(modeswitchkey)} configuration at {item.Name}: {value} is not supported! Using F as default.",
                    item.Prefab.ContentPackage);
                }
            }
        }


        partial void InitProjSpecific(ContentXElement rangedWeaponElement)
        {
            switchKey = rangedWeaponElement.GetAttributeString(nameof(modeswitchkey), "F");
        }
        public override void UpdateHUDComponentSpecific(Character character, float deltaTime, Camera cam)
        {
            crossHairPosDirtyTimer -= deltaTime;
            currentCrossHairScale = currentCrossHairPointerScale = cam == null ? 1.0f : cam.Zoom;
            if (crosshairSprite != null)
            {
                // Set position based on in-world aim
                Vector2 barrelDir = (MathF.Cos(item.body.TransformedRotation), -MathF.Sin(item.body.TransformedRotation));
                float mouseDist = Vector2.Distance(BarrelScreenPos, PlayerInput.MousePosition);
                crosshairPos = Vector2.Clamp(BarrelScreenPos + barrelDir * mouseDist, Vector2.Zero, (GameMain.GraphicsWidth, GameMain.GraphicsHeight));

                // Resize pointer based on current spread
                float spread = GetSpread(character);
                if (FindProjectile() is Projectile projectile)
                {
                    spread += MathHelper.ToRadians(projectile.Spread);
                }
                float spreadAtRange = MathF.Sin(spread) * Vector2.Distance(BarrelScreenPos, crosshairPos);
                currentCrossHairPointerScale = MathHelper.Clamp(spreadAtRange / Math.Min(crosshairSprite.size.X, crosshairSprite.size.Y), 0.1f, 10f);
            }
            currentCrossHairScale *= CrossHairScale;
            crosshairPointerPos = PlayerInput.MousePosition;
            UpdateUserInput(character);
        }

        private void UpdateUserInput(Character character)
        {
            if (character == null) return;

            if (PlayerInput.KeyHit(modeswitchkey))
            {
                currentProjectileSelected += 1;
                GameMain.Client?.CreateEntityEvent(this.Item, new Item.ChangePropertyEventData(this.SerializableProperties["currentProjectileSelected".ToIdentifier()], this));
            }
        }
    }
}
