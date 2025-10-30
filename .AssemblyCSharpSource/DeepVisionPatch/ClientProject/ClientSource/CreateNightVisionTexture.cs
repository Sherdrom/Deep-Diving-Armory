using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

public class CreateNightVisionTexture
{
    // Ensure the fields are initialized to avoid nullability issues
    private Texture2D _texture = null!;
    private Color[] _pixelBuffer = null!;
    private float[] _vignetteTable = null!;

    private int _textureWidth = 512;
    private int _textureHeight = 512;
    
    // 夜视仪参数
    private Color _nightVisionColor = new Color(0, 255, 0, 50); // 绿色
    private int _gridSpacing = 3; // 网格间距
    private float _scanLineSpeed = 80.0f; // 扫描线移动速度
    private float _scanLinePosition = 0; // 扫描线位置
    private float vignetteMulti = 0.8f; // 暗角倍数

    /// <summary>
    /// 初始化矩形夜视仪纹理
    /// </summary>
    public void Initialize(GraphicsDevice graphicsDevice, Color color)
    {
        _nightVisionColor = color;
        _texture = new Texture2D(graphicsDevice, _textureWidth, _textureHeight);
        _pixelBuffer = new Color[_textureWidth * _textureHeight];
        
        // 预计算数据
        PrecomputeData();
        
        // 生成初始纹理
        GenerateNightVisionTexture();
    }

    /// <summary>
    /// 预计算静态数据
    /// </summary>
    private void PrecomputeData()
    {
        // 预计算暗角表
        _vignetteTable = new float[_textureWidth * _textureHeight];
        float centerX = _textureWidth / 2f;
        float centerY = _textureHeight / 2f;

        // 添加一个变量用于调整中心保持明亮的区域大小
        float vignetteRadius = Math.Min(centerX, centerY) * vignetteMulti; // 可调节的半径系数

        for (int y = 0; y < _textureHeight; y++)
        {
            for (int x = 0; x < _textureWidth; x++)
            {
                int index = y * _textureWidth + x;
                float distX = x - centerX;
                float distY = y - centerY;
                float distance = MathF.Sqrt(distX * distX + distY * distY);

                // 根据距离计算暗角值，中心区域保持明亮
                _vignetteTable[index] = distance < vignetteRadius
                    ? 1.0f
                    : Math.Max(0.0f, 1.0f - (distance - vignetteRadius) / vignetteRadius);
            }
        }
    }

    /// <summary>
    /// 生成夜视仪纹理（优化版本，支持多线程）
    /// </summary>
    private void GenerateNightVisionTexture()
    {
        // 使用多线程处理像素数据以提高性能
        Parallel.For(0, _textureHeight, y =>
        {
            int rowStart = y * _textureWidth;
            for (int x = 0; x < _textureWidth; x++)
            {
                int index = rowStart + x;
                _pixelBuffer[index] = CalculatePixelColor(x, y, false);
            }
        });

        // 批量更新纹理数据
        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// 更新纹理（优化版本）
    /// </summary>
    public void Update(float deltaTime)
    {
        // 更新扫描线位置，确保范围在 [0, _textureHeight]
        _scanLinePosition = (_scanLinePosition + _scanLineSpeed * deltaTime) % _textureHeight;
        if (_scanLinePosition < 0) _scanLinePosition += _textureHeight;

        UpdateDynamicTexture();
    }

    /// <summary>
    /// 只更新需要变化的部分（扫描线区域）
    /// </summary>
    private void UpdateDynamicTexture()
    {
        // 只更新扫描线附近的区域（±3像素）
        int scanLineStart = Math.Max(0, (int)_scanLinePosition - 3);
        int scanLineEnd = Math.Min(_textureHeight, (int)_scanLinePosition + 3);
        
        // 清除之前的扫描线区域
        int prevScanLineStart = Math.Max(0, (int)(_scanLinePosition - _scanLineSpeed) - 3);
        int prevScanLineEnd = Math.Min(_textureHeight, (int)(_scanLinePosition - _scanLineSpeed) + 3);
        
        // 更新两个区域（当前和之前的扫描线位置）
        UpdateTextureRegion(prevScanLineStart, prevScanLineEnd, false);
        UpdateTextureRegion(scanLineStart, scanLineEnd, true);
        
        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// 只更新纹理的特定区域
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
    /// 计算单个像素颜色（高度优化）
    /// </summary>
    private Color CalculatePixelColor(int x, int y, bool checkScanLine)
    {
        Color pixelColor = _nightVisionColor;

        // 网格效果（使用预计算的模运算）
        if ((y % _gridSpacing) < 2) // 水平网格线
        {
            pixelColor.R = (byte)(pixelColor.R * 0.7f);
            pixelColor.G = (byte)(pixelColor.G * 0.7f);
            pixelColor.B = (byte)(pixelColor.B * 0.7f);
        }

        // 暗角效果（优化计算）
        int index = y * _textureWidth + x;
        float vignette = _vignetteTable[index];
        pixelColor.R = (byte)(pixelColor.R * vignette);
        pixelColor.G = (byte)(pixelColor.G * vignette);
        pixelColor.B = (byte)(pixelColor.B * vignette);

        // 扫描线效果（只在需要时检查）
        if (checkScanLine && Math.Abs(y - _scanLinePosition) <= 1)
        {
            pixelColor.R = (byte)Math.Min(pixelColor.R + 50, 255);
            pixelColor.G = (byte)Math.Min(pixelColor.G + 50, 255);
            pixelColor.B = (byte)Math.Min(pixelColor.B + 50, 255);
        }

        return pixelColor;
    }

    /// <summary>
    /// 设置夜视仪参数（需要时重新预计算）
    /// </summary>
    public void SetNightVisionParameters(Color? color = null, int? gridSpacing = null, float? scanLineSpeed = null)
    {
        bool needsRecompute = false;
        
        if (color.HasValue) _nightVisionColor = color.Value;
        if (gridSpacing.HasValue)
        {
            _gridSpacing = gridSpacing.Value;
            needsRecompute = true;
        }
        
        if (scanLineSpeed.HasValue) _scanLineSpeed = scanLineSpeed.Value;
        
        if (needsRecompute)
        {
            PrecomputeData();
            GenerateNightVisionTexture();
        }
    }

    /// <summary>
    /// 获取当前纹理
    /// </summary>
    public Texture2D GetTexture() => _texture;

    /// <summary>
    /// 释放资源
    /// </summary>
    public void Dispose()
    {
        if (_texture != null && !_texture.IsDisposed)
        {
            _texture.Dispose();
        }
        _texture = null!; // Suppress nullable warnings
        _pixelBuffer = null!; // Suppress nullable warnings
        _vignetteTable = null!; // Suppress nullable warnings
    }
}