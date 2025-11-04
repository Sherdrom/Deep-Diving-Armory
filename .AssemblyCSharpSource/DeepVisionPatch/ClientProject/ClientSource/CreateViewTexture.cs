using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

/// <summary>
/// Creates and manages tactical view textures
/// Supports circular view masks and sector-shaped view gaps for tactical displays
/// </summary>
public class CreateViewTexture
{
    // Core texture data
    private Texture2D _texture;
    private Texture2D _textureCircle;
    private Color[] _pixelBuffer;
    private float[,] _distanceTable;
    private float[,] _angleTable;
    private Vector2 _center;
    private float _lastGapDegrees = -1f;
    private int _textureSize;

    // Constants
    private const float TWO_PI = MathHelper.TwoPi;

    /// <summary>
    /// Initializes the view texture and precomputes lookup tables
    /// </summary>
    /// <param name="graphicsDevice">The graphics device to create textures on</param>
    /// <param name="radius">The radius of the circular view in pixels</param>
    public void Initialize(GraphicsDevice graphicsDevice, int radius)
    {
        _textureSize = radius * 2;
        _center = new Vector2(radius, radius);

        // Create both dynamic and static textures
        _texture = new Texture2D(graphicsDevice, _textureSize, _textureSize);
        _textureCircle = new Texture2D(graphicsDevice, _textureSize, _textureSize);
        _pixelBuffer = new Color[_textureSize * _textureSize];

        // Precompute distance and angle lookup tables for performance
        _distanceTable = new float[_textureSize, _textureSize];
        _angleTable = new float[_textureSize, _textureSize];

        PrecomputeLookupTables();
        InitializeCircularMask();
    }

    /// <summary>
    /// Precomputes distance and angle values for all pixels
    /// This lookup table improves performance by avoiding repeated calculations
    /// </summary>
    private void PrecomputeLookupTables()
    {
        Parallel.For(0, _textureSize, y =>
        {
            for (int x = 0; x < _textureSize; x++)
            {
                Vector2 pixelPos = new Vector2(x, y);

                // Calculate and store distance and angle for this pixel
                _distanceTable[x, y] = Vector2.Distance(pixelPos, _center);

                // Calculate angle in [0, 2π] range
                float angle = MathF.Atan2(pixelPos.Y - _center.Y, pixelPos.X - _center.X);
                _angleTable[x, y] = (angle + TWO_PI) % TWO_PI;
            }
        });
    }

    /// <summary>
    /// Creates a static circular mask texture (white circle on transparent background)
    /// </summary>
    private void InitializeCircularMask()
    {
        Color[] circlePixels = new Color[_textureSize * _textureSize];
        float circleRadius = _textureSize / 2f;

        Parallel.For(0, _textureSize, y =>
        {
            for (int x = 0; x < _textureSize; x++)
            {
                int index = y * _textureSize + x;
                float distance = _distanceTable[x, y];
                circlePixels[index] = distance <= circleRadius ? Color.White : Color.Transparent;
            }
        });

        _textureCircle.SetData(circlePixels);
    }

    /// <summary>
    /// Updates the sector-shaped view texture
    /// Only recalculates when the gap angle changes
    /// </summary>
    /// <param name="gapDegrees">The angular size of the gap in degrees (0-360)</param>
    /// <param name="sectorColor">The color for the non-gap sectors</param>
    public void UpdateSectorTexture(float gapDegrees, Color sectorColor)
    {
        // Skip if gap angle hasn't changed
        if (gapDegrees == _lastGapDegrees)
            return;

        _lastGapDegrees = gapDegrees;

        // Calculate gap boundaries
        float halfGap = gapDegrees / 2f;
        float gapStart = (-halfGap + TWO_PI) % TWO_PI;
        float gapEnd = (halfGap + TWO_PI) % TWO_PI;

        float radius = _textureSize / 2f;

        // Update all pixels based on their angle
        Parallel.For(0, _textureSize, y =>
        {
            for (int x = 0; x < _textureSize; x++)
            {
                int index = y * _textureSize + x;
                float distance = _distanceTable[x, y];
                float angle = _angleTable[x, y];

                // Pixels outside the circle are transparent
                if (distance > radius)
                {
                    _pixelBuffer[index] = Color.Transparent;
                    continue;
                }

                // Check if this pixel's angle falls within the gap
                bool inGap = (gapStart <= gapEnd)
                    ? (angle >= gapStart && angle <= gapEnd)
                    : (angle >= gapStart || angle <= gapEnd);

                // Set pixel color: white for gap, sector color for view area
                _pixelBuffer[index] = inGap ? Color.White : sectorColor;
            }
        });

        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// Gets the current sector texture
    /// </summary>
    public Texture2D GetTexture() => _texture;

    /// <summary>
    /// Gets the static circular mask texture
    /// </summary>
    public Texture2D GetTextureCircle() => _textureCircle;

    /// <summary>
    /// Releases all resources
    /// </summary>
    public void Dispose()
    {
        _texture?.Dispose();
        _textureCircle?.Dispose();

        _texture = null;
        _textureCircle = null;
        _pixelBuffer = null;
        _distanceTable = null;
        _angleTable = null;
    }
}
