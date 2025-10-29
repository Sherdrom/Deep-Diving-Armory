using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;
using System;

namespace DeepVisionPatch;

public class CreateNightVisionTexture
{
    private Texture2D _texture;
    private Color[] _pixelBuffer;
    private Random _random;
    private int _textureWidth;
    private int _textureHeight;
    
    // 夜视仪参数
    private Color _nightVisionColor = new Color(0, 255, 0, 255); // 绿色
    private int _gridSpacing = 8; // 网格间距
    private float _noiseIntensity = 0.1f; // 杂色强度
    private float _scanLineSpeed = 2.0f; // 扫描线移动速度
    private float _scanLinePosition = 0; // 扫描线位置

    // 预计算表
    private float[] _vignetteTable;
    private int _gridSpacingSquared;
    private int _verticalGridSpacing;

    /// <summary>
    /// 初始化矩形夜视仪纹理
    /// </summary>
    public void Initialize(GraphicsDevice graphicsDevice, int width, int height)
    {
        _textureWidth = width;
        _textureHeight = height;
        _texture = new Texture2D(graphicsDevice, _textureWidth, _textureHeight);
        _pixelBuffer = new Color[_textureWidth * _textureHeight];
        _random = new Random();
        
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
        float maxDistance = Math.Max(centerX, centerY);

        for (int y = 0; y < _textureHeight; y++)
        {
            for (int x = 0; x < _textureWidth; x++)
            {
                int index = y * _textureWidth + x;
                float distX = Math.Abs(x - centerX) / maxDistance;
                float distY = Math.Abs(y - centerY) / maxDistance;
                _vignetteTable[index] = 1.0f - Math.Max(distX, distY) * 0.3f;
            }
        }

        _gridSpacingSquared = _gridSpacing * _gridSpacing;
        _verticalGridSpacing = _gridSpacing * 4;
    }

    /// <summary>
    /// 生成夜视仪纹理（优化版本）
    /// </summary>
    private void GenerateNightVisionTexture()
    {
        // 使用单线程循环，通常比Parallel.For更快用于小纹理
        for (int i = 0; i < _pixelBuffer.Length; i++)
        {
            int x = i % _textureWidth;
            int y = i / _textureWidth;
            
            _pixelBuffer[i] = CalculatePixelColor(x, y, false);
        }
        
        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// 更新纹理（优化版本）
    /// </summary>
    public void Update(float deltaTime)
    {
        // 只更新扫描线位置
        _scanLinePosition += _scanLineSpeed * deltaTime;
        if (_scanLinePosition > _textureHeight + 10)
            _scanLinePosition = -10;
        
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
        else if ((x % _verticalGridSpacing) < 2) // 垂直网格线
        {
            pixelColor.R = (byte)(pixelColor.R * 0.8f);
            pixelColor.G = (byte)(pixelColor.G * 0.8f);
            pixelColor.B = (byte)(pixelColor.B * 0.8f);
        }
        
        // 杂色效果（使用更快的随机数生成）
        float noise = ((x * 197 + y * 331 + (int)(_scanLinePosition * 1000)) & 0xFF) * 0.0039f - 0.5f; // 0.0039 = 1/255
        noise *= _noiseIntensity;
        
        pixelColor.R = ClampByte(pixelColor.R + noise * 255);
        pixelColor.G = ClampByte(pixelColor.G + noise * 255);
        pixelColor.B = ClampByte(pixelColor.B + noise * 255);
        
        // 暗角效果（使用预计算表）
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
    /// 快速字节钳制
    /// </summary>
    private byte ClampByte(float value)
    {
        int intValue = (int)value;
        return (byte)(intValue < 0 ? 0 : intValue > 255 ? 255 : intValue);
    }

    /// <summary>
    /// 设置夜视仪参数（需要时重新预计算）
    /// </summary>
    public void SetNightVisionParameters(Color? color = null, int? gridSpacing = null, float? noiseIntensity = null, float? scanLineSpeed = null)
    {
        bool needsRecompute = false;
        
        if (color.HasValue) _nightVisionColor = color.Value;
        if (gridSpacing.HasValue) 
        {
            _gridSpacing = gridSpacing.Value;
            needsRecompute = true;
        }
        if (noiseIntensity.HasValue) _noiseIntensity = noiseIntensity.Value;
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
        _texture?.Dispose();
        _texture = null;
        _pixelBuffer = null;
        _vignetteTable = null;
    }
}