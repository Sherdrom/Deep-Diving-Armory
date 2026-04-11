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

    // Lightweight scanline overlay texture (1px wide)
    private Texture2D _scanlineTexture = null!;

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
    private const int SCANLINE_COLOR_OFFSET = 50;

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

        // Create a small scanline texture we can draw every frame without SetData
        int scanlineTexHeight = SCANLINE_WIDTH;
        _scanlineTexture = new Texture2D(graphicsDevice, 1, scanlineTexHeight);
        Color[] scanPixels = new Color[1 * scanlineTexHeight];
        for (int y = 0; y < scanlineTexHeight; y++)
        {
            // float t = 1f - MathF.Abs(y - SCANLINE_WIDTH) / (float)(SCANLINE_WIDTH + 1);
            byte r = (byte)MathF.Min(_nightVisionColor.R + SCANLINE_COLOR_OFFSET, 255);
            byte g = (byte)MathF.Min(_nightVisionColor.G + SCANLINE_COLOR_OFFSET, 255);
            byte b = (byte)MathF.Min(_nightVisionColor.B + SCANLINE_COLOR_OFFSET, 255);
            byte a = _nightVisionColor.A;
            scanPixels[y] = new Color(r, g, b, a);
        }
        _scanlineTexture.SetData(scanPixels);       
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
                _pixelBuffer[index] = CalculatePixelColor(x, y);
            }
        });

        _texture.SetData(_pixelBuffer);
    }
    /// <summary>
    /// 预计算夜视仪效果的像素颜色，包含网格和暗角效果，但不包含扫描线（扫描线在DrawOverlay中单独处理）
    /// </summary>
    private Color CalculatePixelColor(int x, int y)
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

        return pixelColor;
    }

    /// <summary>
    /// Updates the night vision texture with animated scanlines
    /// </summary>
    /// <param name="deltaTime">Time elapsed since last update (in seconds)</param>
    public void Update(float deltaTime)
    {
        // Advance scanline position for smooth motion. Keep Update lightweight (no SetData here).
        _scanLinePosition = (_scanLinePosition + _scanLineSpeed * deltaTime) % _textureHeight;
        if (_scanLinePosition < 0)
            _scanLinePosition += _textureHeight;
    }

    /// <summary>
    /// Gets the current night vision texture
    /// </summary>
    public Texture2D GetTexture() => _texture;

    /// <summary>
    /// Draws a lightweight scanline overlay on top of the base texture using the provided SpriteBatch.
    /// </summary>
    public void DrawOverlay(SpriteBatch spriteBatch, Vector2 center, Vector2 scaleVector)
    {
        if (_scanlineTexture == null) return;

        // Normalized position of the scanline within the texture [0,1]
        float normY = _scanLinePosition / _textureHeight;

        // Compute offset from texture center (in screen pixels)
        float halfTexHeightScreen = _textureHeight * 0.5f * scaleVector.Y;
        float offsetY = (normY - 0.5f) * 2f * halfTexHeightScreen; // distance from center

        // Compute destination position for scanline (centered horizontally)
        Vector2 position = new Vector2(center.X, center.Y + offsetY);

        // Scale scanline to full screen width and appropriate height
        float destWidth = _textureWidth * scaleVector.X;
        float destHeight = _scanlineTexture.Height * scaleVector.Y;

        var destRect = new Rectangle(
            (int)(position.X - destWidth * 0.5f),
            (int)(position.Y - destHeight * 0.5f),
            (int)destWidth,
            (int)destHeight);

        spriteBatch.Draw(_scanlineTexture, destRect, Color.White);
    }

    /// <summary>
    /// Releases all resources
    /// </summary>
    public void Dispose()
    {
        if (_texture != null && !_texture.IsDisposed)
        {
            _texture.Dispose();
        }

        if (_scanlineTexture != null && !_scanlineTexture.IsDisposed)
        {
            _scanlineTexture.Dispose();
        }

        // Clear references to help GC
        _texture = null!;
        _pixelBuffer = null!;
        _vignetteTable = null!;
    }
}