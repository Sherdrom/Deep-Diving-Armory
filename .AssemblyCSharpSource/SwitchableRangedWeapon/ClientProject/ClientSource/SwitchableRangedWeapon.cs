using Barotrauma;
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

            if (PlayerInput.KeyHit(Keys.F))
            {
                currentProjectileSelected += 1;
                if (SerializableProperties.TryGetValue(nameof(currentProjectileSelected).ToIdentifier(), out var property))
                {
                    GameMain.Client?.CreateEntityEvent(Item, new Item.ChangePropertyEventData(property, this));
                }
            }
        }
    }
}
