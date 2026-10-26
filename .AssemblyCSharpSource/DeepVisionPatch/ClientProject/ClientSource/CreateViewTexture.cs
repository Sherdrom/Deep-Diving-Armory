using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

/// <summary>
/// Creates and manages tactical view textures
/// Supports circular view masks and sector-shaped view gaps for tactical displays
/// </summary>
public class CreateViewTexture
{
    private const int CircleSegments = 64;
    private const int MaxSectorSegments = 60;
    private const float MaxFieldOfView = MathF.PI * 8f / 9f;
    private const float BoundaryFeather = 0.002f;
    private const float EdgeFeatherRadius = 0.25f;

    private Texture2D _textureCircle = null!;
    private readonly VertexPositionColorTexture[] _sectorVertices =
        new VertexPositionColorTexture[(CircleSegments * 2 + MaxSectorSegments * 2 + 2) * 4];
    private int _textureSize;

    /// <summary>
    /// Initializes the static white texture used by the geometry renderer
    /// </summary>
    /// <param name="graphicsDevice">The graphics device to create textures on</param>
    /// <param name="radius">The radius of the circular view in pixels</param>
    public void Initialize(GraphicsDevice graphicsDevice, int radius)
    {
        _textureSize = radius * 2;

        _textureCircle = new Texture2D(graphicsDevice, _textureSize, _textureSize);

        InitializeCircularMask();
    }

    private void InitializeCircularMask()
    {
        Color[] circlePixels = new Color[_textureSize * _textureSize];
        float center = _textureSize / 2f;
        float radiusSquared = (center - 1f) * (center - 1f);

        Parallel.For(0, _textureSize, y =>
        {
            for (int x = 0; x < _textureSize; x++)
            {
                float dx = x - center;
                float dy = y - center;
                circlePixels[y * _textureSize + x] = dx * dx + dy * dy < radiusSquared
                    ? Color.White
                    : Color.Transparent;
            }
        });

        _textureCircle.SetData(circlePixels);
    }

    public void DrawSector(
        SpriteBatch spriteBatch,
        Vector2 center,
        float rotation,
        Vector2 scale,
        float fieldOfView,
        Color sectorColor)
    {
        float clampedFieldOfView = MathHelper.Clamp(fieldOfView, 0f, MathHelper.TwoPi);
        int segmentCount = Math.Min(
            MaxSectorSegments,
            Math.Max(1, (int)MathF.Ceiling(clampedFieldOfView / (MaxFieldOfView / MaxSectorSegments))));
        float halfFieldOfView = clampedFieldOfView / 2f;
        float angleStep = clampedFieldOfView / segmentCount;
        float radius = _textureSize / 2f;
        float sinRotation = MathF.Sin(rotation);
        float cosRotation = MathF.Cos(rotation);
        int quadCount = 0;

        for (int i = 0; i < CircleSegments; i++)
        {
            float startAngle = MathHelper.TwoPi * i / CircleSegments;
            float endAngle = MathHelper.TwoPi * (i + 1) / CircleSegments;
            SetSectorQuad(quadCount++, center, scale, radius - EdgeFeatherRadius, sinRotation, cosRotation,
                startAngle, endAngle, sectorColor, sectorColor);
            SetRingQuad(quadCount++, center, scale, radius - EdgeFeatherRadius, radius + EdgeFeatherRadius,
                sinRotation, cosRotation, startAngle, endAngle, sectorColor);
        }

        for (int i = 0; i < segmentCount; i++)
        {
            float startAngle = -halfFieldOfView + angleStep * i;
            SetSectorQuad(quadCount++, center, scale, radius - EdgeFeatherRadius, sinRotation, cosRotation,
                startAngle, startAngle + angleStep, Color.White, Color.White);
            SetRingQuad(quadCount++, center, scale, radius - EdgeFeatherRadius, radius + EdgeFeatherRadius,
                sinRotation, cosRotation, startAngle, startAngle + angleStep, Color.White);
        }

        SetSectorQuad(quadCount++, center, scale, radius - EdgeFeatherRadius, sinRotation, cosRotation,
            -halfFieldOfView - BoundaryFeather, -halfFieldOfView, Color.Transparent, Color.White);
        SetSectorQuad(quadCount++, center, scale, radius - EdgeFeatherRadius, sinRotation, cosRotation,
            halfFieldOfView, halfFieldOfView + BoundaryFeather, Color.White, Color.Transparent);

        spriteBatch.Draw(_textureCircle, _sectorVertices, 1f, quadCount);
    }

    private void SetSectorQuad(
        int quadIndex,
        Vector2 center,
        Vector2 scale,
        float radius,
        float sinRotation,
        float cosRotation,
        float startAngle,
        float endAngle,
        Color startColor,
        Color endColor)
    {
        Vector2 startDirection = new Vector2(MathF.Cos(startAngle), MathF.Sin(startAngle));
        Vector2 endDirection = new Vector2(MathF.Cos(endAngle), MathF.Sin(endAngle));
        Vector2 start = TransformSectorPoint(center, startDirection, scale, radius, sinRotation, cosRotation);
        Vector2 end = TransformSectorPoint(center, endDirection, scale, radius, sinRotation, cosRotation);
        Vector2 centerUv = new Vector2(0.5f, 0.5f);
        int index = quadIndex * 4;

        _sectorVertices[index] = new VertexPositionColorTexture(
            new Vector3(start, 0f), startColor, centerUv);
        _sectorVertices[index + 1] = new VertexPositionColorTexture(
            new Vector3(end, 0f), endColor, centerUv);
        _sectorVertices[index + 2] = new VertexPositionColorTexture(new Vector3(center, 0f), startColor, centerUv);
        _sectorVertices[index + 3] = new VertexPositionColorTexture(new Vector3(center, 0f), endColor, centerUv);
    }

    private void SetRingQuad(
        int quadIndex,
        Vector2 center,
        Vector2 scale,
        float innerRadius,
        float outerRadius,
        float sinRotation,
        float cosRotation,
        float startAngle,
        float endAngle,
        Color innerColor)
    {
        Vector2 startDirection = new Vector2(MathF.Cos(startAngle), MathF.Sin(startAngle));
        Vector2 endDirection = new Vector2(MathF.Cos(endAngle), MathF.Sin(endAngle));
        Vector2 outerStart = TransformSectorPoint(center, startDirection, scale, outerRadius, sinRotation, cosRotation);
        Vector2 outerEnd = TransformSectorPoint(center, endDirection, scale, outerRadius, sinRotation, cosRotation);
        Vector2 innerStart = TransformSectorPoint(center, startDirection, scale, innerRadius, sinRotation, cosRotation);
        Vector2 innerEnd = TransformSectorPoint(center, endDirection, scale, innerRadius, sinRotation, cosRotation);
        Vector2 centerUv = new Vector2(0.5f, 0.5f);
        int index = quadIndex * 4;

        _sectorVertices[index] = new VertexPositionColorTexture(new Vector3(outerStart, 0f), Color.Transparent, centerUv);
        _sectorVertices[index + 1] = new VertexPositionColorTexture(new Vector3(outerEnd, 0f), Color.Transparent, centerUv);
        _sectorVertices[index + 2] = new VertexPositionColorTexture(new Vector3(innerStart, 0f), innerColor, centerUv);
        _sectorVertices[index + 3] = new VertexPositionColorTexture(new Vector3(innerEnd, 0f), innerColor, centerUv);
    }

    private static Vector2 TransformSectorPoint(
        Vector2 center,
        Vector2 direction,
        Vector2 scale,
        float radius,
        float sinRotation,
        float cosRotation)
    {
        float x = direction.X * radius * scale.X;
        float y = direction.Y * radius * scale.Y;
        return center + new Vector2(x * cosRotation - y * sinRotation, x * sinRotation + y * cosRotation);
    }

    /// <summary>
    /// Gets the static circular mask texture
    /// </summary>
    public Texture2D GetTextureCircle() => _textureCircle;

    /// <summary>
    /// Releases all resources
    /// </summary>
    public void Dispose()
    {
        _textureCircle?.Dispose();

        _textureCircle = null!;
    }
}
