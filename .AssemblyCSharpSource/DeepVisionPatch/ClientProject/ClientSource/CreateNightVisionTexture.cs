using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

/// <summary>
/// Creates and manages night vision texture effects
/// Handles texture generation, grid overlay, scanlines, and vignette effects
/// </summary>
public class CreateNightVisionTexture
{
    // Core texture data
    private Texture2D _texture = null!;
    private Color[] _pixelBuffer = null!;
    private float[] _vignetteTable = null!;

    private int _textureWidth;
    private int _textureHeight;

    // Night vision visual parameters
    private Color _nightVisionColor = new Color(0, 255, 0, 50);
    private int _gridSpacing = 3; // 网格间距
    private float _scanLineSpeed = 80.0f; // 扫描线移动速度 
    private float _scanLinePosition = 0; // 扫描线位置
    private float _vignetteMultiplier = 0.8f; // 暗角倍数 

    // Constants for scanline calculations
    private const int SCANLINE_WIDTH = 3;
    private const float GRID_DARKEN_FACTOR = 0.7f;
    private const int SCANLINE_BRIGHTNESS = 50;

    /// <summary>
    /// Initializes the night vision texture with specified color
    /// </summary>
    /// <param name="graphicsDevice">The graphics device to create the texture on</param>
    /// <param name="color">Base color for the night vision effect</param>
    public void Initialize(GraphicsDevice graphicsDevice, Color color)
    {
        _nightVisionColor = color;
        _textureWidth = 512;
        _textureHeight = 512;

        _texture = new Texture2D(graphicsDevice, _textureWidth, _textureHeight);
        _pixelBuffer = new Color[_textureWidth * _textureHeight];

        PrecomputeStaticData();
        GenerateInitialTexture();
    }

    /// <summary>
    /// Precomputes static data tables for vignette effects
    /// </summary>
    private void PrecomputeStaticData()
    {
        _vignetteTable = new float[_textureWidth * _textureHeight];
        float centerX = _textureWidth / 2f;
        float centerY = _textureHeight / 2f;
        float vignetteRadius = Math.Min(centerX, centerY) * _vignetteMultiplier;

        for (int y = 0; y < _textureHeight; y++)
        {
            for (int x = 0; x < _textureWidth; x++)
            {
                int index = y * _textureWidth + x;
                float distX = x - centerX;
                float distY = y - centerY;
                float distance = MathF.Sqrt(distX * distX + distY * distY);

                // Vignette effect: center stays bright, edges get darker
                _vignetteTable[index] = distance < vignetteRadius
                    ? 1.0f
                    : Math.Max(0.0f, 1.0f - (distance - vignetteRadius) / vignetteRadius);
            }
        }
    }

    /// <summary>
    /// Generates the initial night vision texture using multi-threading
    /// </summary>
    private void GenerateInitialTexture()
    {
        // Use parallel processing for better performance
        Parallel.For(0, _textureHeight, y =>
        {
            int rowStart = y * _textureWidth;
            for (int x = 0; x < _textureWidth; x++)
            {
                int index = rowStart + x;
                _pixelBuffer[index] = CalculatePixelColor(x, y, checkScanLine: false);
            }
        });

        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// Updates the night vision texture with animated scanlines
    /// </summary>
    /// <param name="deltaTime">Time elapsed since last update (in seconds)</param>
    public void Update(float deltaTime)
    {
        // Update scanline position (wrap around texture height)
        _scanLinePosition = (_scanLinePosition + _scanLineSpeed * deltaTime) % _textureHeight;
        if (_scanLinePosition < 0)
            _scanLinePosition += _textureHeight;

        UpdateDynamicRegions();
    }

    /// <summary>
    /// Updates only the regions that change (scanline areas)
    /// </summary>
    private void UpdateDynamicRegions()
    {
        // Calculate current and previous scanline regions
        int currentStart = Math.Max(0, (int)_scanLinePosition - SCANLINE_WIDTH);
        int currentEnd = Math.Min(_textureHeight, (int)_scanLinePosition + SCANLINE_WIDTH);

        int previousStart = Math.Max(0, (int)(_scanLinePosition - _scanLineSpeed) - SCANLINE_WIDTH);
        int previousEnd = Math.Min(_textureHeight, (int)(_scanLinePosition - _scanLineSpeed) + SCANLINE_WIDTH);

        // Update both regions
        UpdateTextureRegion(previousStart, previousEnd, includeScanLine: false);
        UpdateTextureRegion(currentStart, currentEnd, includeScanLine: true);

        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// Updates a specific Y-range of the texture
    /// </summary>
    private void UpdateTextureRegion(int startY, int endY, bool includeScanLine)
    {
        for (int y = startY; y < endY; y++)
        {
            int rowStart = y * _textureWidth;
            for (int x = 0; x < _textureWidth; x++)
            {
                int index = rowStart + x;
                _pixelBuffer[index] = CalculatePixelColor(x, y, includeScanLine);
            }
        }
    }

    /// <summary>
    /// Calculates the color for a single pixel with all night vision effects
    /// </summary>
    private Color CalculatePixelColor(int x, int y, bool checkScanLine)
    {
        Color pixelColor = _nightVisionColor;

        // Grid effect: darken every few pixels horizontally
        if ((y % _gridSpacing) < 2)
        {
            pixelColor.R = (byte)(pixelColor.R * GRID_DARKEN_FACTOR);
            pixelColor.G = (byte)(pixelColor.G * GRID_DARKEN_FACTOR);
            pixelColor.B = (byte)(pixelColor.B * GRID_DARKEN_FACTOR);
        }

        // Vignette effect (using precomputed table)
        int index = y * _textureWidth + x;
        float vignette = _vignetteTable[index];
        pixelColor.R = (byte)(pixelColor.R * vignette);
        pixelColor.G = (byte)(pixelColor.G * vignette);
        pixelColor.B = (byte)(pixelColor.B * vignette);

        // Scanline effect: bright horizontal line that moves
        if (checkScanLine && Math.Abs(y - _scanLinePosition) <= 1)
        {
            pixelColor.R = (byte)Math.Min(pixelColor.R + SCANLINE_BRIGHTNESS, 255);
            pixelColor.G = (byte)Math.Min(pixelColor.G + SCANLINE_BRIGHTNESS, 255);
            pixelColor.B = (byte)Math.Min(pixelColor.B + SCANLINE_BRIGHTNESS, 255);
        }

        return pixelColor;
    }

    /// <summary>
    /// Updates night vision parameters (recomputes data if needed)
    /// </summary>
    public void SetNightVisionParameters(
        Color? color = null,
        int? gridSpacing = null,
        float? scanLineSpeed = null)
    {
        bool needsRecompute = false;

        if (color.HasValue)
            _nightVisionColor = color.Value;

        if (gridSpacing.HasValue)
        {
            _gridSpacing = gridSpacing.Value;
            needsRecompute = true;
        }

        if (scanLineSpeed.HasValue)
            _scanLineSpeed = scanLineSpeed.Value;

        // Recompute only if grid spacing changed (affects static data)
        if (needsRecompute)
        {
            PrecomputeStaticData();
            GenerateInitialTexture();
        }
    }

    /// <summary>
    /// Gets the current night vision texture
    /// </summary>
    public Texture2D GetTexture() => _texture;

    /// <summary>
    /// Releases all resources
    /// </summary>
    public void Dispose()
    {
        if (_texture != null && !_texture.IsDisposed)
        {
            _texture.Dispose();
        }

        // Clear references to help GC
        _texture = null!;
        _pixelBuffer = null!;
        _vignetteTable = null!;
    }
}