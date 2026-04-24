namespace GunsmithPatch
{
    public static partial class GunsmithApi
    {
        private static List<GunsmithLayer> ParseLayers(string layerSpec)
        {
            List<GunsmithLayer> layers = new();
            foreach (string layerText in layerSpec.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                string[] parts = layerText.Split('|', StringSplitOptions.TrimEntries);
                if (parts.Length < 5) { continue; }
                if (!TryParseRectangle(parts[2], out Rectangle sourceRect)) { continue; }
                if (!TryParseVector2(parts[3], out Vector2 offset)) { continue; }
                if (!int.TryParse(parts[4], out int order)) { order = 0; }

                layers.Add(new GunsmithLayer
                {
                    TexturePath = ResolvePath(parts[1]),
                    SourceRect = sourceRect,
                    Offset = offset,
                    Order = order
                });
            }

            return layers.OrderBy(layer => layer.Order).ToList();
        }

        private static Texture2D ComposeTexture(IReadOnlyList<GunsmithLayer> layers, int width, int height)
        {
            GraphicsDevice graphics = graphicsDevice!;
            SpriteBatch batch = spriteBatch!;
            RenderTargetBinding[] previousTargets = graphics.GetRenderTargets();
            RenderTarget2D target = new(graphics, width, height, false, SurfaceFormat.Color, DepthFormat.None);

            graphics.SetRenderTarget(target);
            graphics.Clear(Color.Transparent);
            batch.Begin(SpriteSortMode.Deferred, null, SamplerState.PointClamp, null, null);
            foreach (GunsmithLayer layer in layers)
            {
                Texture2D texture = GetTexture(layer.TexturePath);
                batch.Draw(texture, layer.Offset, layer.SourceRect, Color.White);
            }
            batch.End();

            graphics.SetRenderTargets(previousTargets);
            return target;
        }

        private static Texture2D GetTexture(string path)
        {
            return textureCache.GetOrAdd(path, static p =>
            {
                using FileStream stream = File.OpenRead(p);
                return Texture2D.FromStream(graphicsDevice!, stream);
            });
        }

        private static Sprite? CreateWorldSprite(Sprite? original, Texture2D texture)
        {
            if (original == null) { return null; }

            Sprite clone = new(original)
            {
                SourceRect = CreateWorldSourceRect(original, texture),
                Origin = original.Origin,
                RelativeOrigin = original.RelativeOrigin,
                RelativeSize = original.RelativeSize,
                Depth = original.Depth,
                SourceElement = original.SourceElement,
                EntityIdentifier = original.EntityIdentifier,
                FilePath = original.FilePath
            };
            clone.texture = texture;
            return clone;
        }

        private static Sprite? CreateInventorySprite(Sprite? original, Texture2D texture)
        {
            if (original == null) { return null; }

            Rectangle sourceRect = new(0, 0, texture.Width, texture.Height);
            Sprite clone = new(original)
            {
                SourceRect = sourceRect,
                Origin = new Vector2(sourceRect.Width * 0.5f, sourceRect.Height * 0.5f),
                RelativeOrigin = new Vector2(0.5f, 0.5f),
                RelativeSize = Vector2.One,
                Depth = original.Depth,
                SourceElement = original.SourceElement,
                EntityIdentifier = original.EntityIdentifier,
                FilePath = original.FilePath
            };
            clone.texture = texture;
            return clone;
        }

        private static Rectangle CreateWorldSourceRect(Sprite original, Texture2D texture)
        {
            Rectangle sourceRect = original.SourceRect;
            int width = Math.Min(sourceRect.Width, texture.Width);
            int height = Math.Min(sourceRect.Height, texture.Height);

            if (width <= 0 || height <= 0)
            {
                return new Rectangle(0, 0, texture.Width, texture.Height);
            }

            return new Rectangle(0, 0, width, height);
        }

        private static string ResolvePath(string path)
        {
            string resolved = path.Replace('\\', Path.DirectorySeparatorChar).Replace('/', Path.DirectorySeparatorChar);
            if (GunsmithPatch.Package != null)
            {
                resolved = resolved.Replace("%ModDir%", GunsmithPatch.Package.Dir, StringComparison.OrdinalIgnoreCase);
            }
            return resolved;
        }

        private static bool TryParseRectangle(string value, out Rectangle rectangle)
        {
            rectangle = default;
            string[] parts = value.Split(',', StringSplitOptions.TrimEntries);
            if (parts.Length != 4) { return false; }
            if (!int.TryParse(parts[0], out int x)) { return false; }
            if (!int.TryParse(parts[1], out int y)) { return false; }
            if (!int.TryParse(parts[2], out int width)) { return false; }
            if (!int.TryParse(parts[3], out int height)) { return false; }
            rectangle = new Rectangle(x, y, width, height);
            return true;
        }

        private static bool TryParseVector2(string value, out Vector2 vector)
        {
            vector = default;
            string[] parts = value.Split(',', StringSplitOptions.TrimEntries);
            if (parts.Length != 2) { return false; }
            if (!float.TryParse(parts[0], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float x)) { return false; }
            if (!float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float y)) { return false; }
            vector = new Vector2(x, y);
            return true;
        }
    }
}
