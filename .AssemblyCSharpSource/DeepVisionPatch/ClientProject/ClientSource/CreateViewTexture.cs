using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework;

namespace DeepVisionPatch;

public class CreateViewTexture
{        
    private Texture2D _texture;
    private Texture2D _textureCircle;
    private Color[] _pixelBuffer;
    private float[,] _distanceTable;
    private float[,] _angleTable;
    private Vector2 _center;
    private int _textureSize;

    /// <summary>
    /// 初始化纹理和预计算数据
    /// </summary>
    public void Initialize(GraphicsDevice graphicsDevice, int radius)
    {
        _textureSize = radius * 2;
        _texture = new Texture2D(graphicsDevice, _textureSize, _textureSize);
        _textureCircle = new Texture2D(graphicsDevice, _textureSize, _textureSize);
        _pixelBuffer = new Color[_textureSize * _textureSize];
        _center = new Vector2(radius, radius);
        
        // 预计算距离和角度表
        _distanceTable = new float[_textureSize, _textureSize];
        _angleTable = new float[_textureSize, _textureSize];

        // 初始化白色圆形纹理
        Color[] circlePixels = new Color[_textureSize * _textureSize];
        float circleRadius = radius; // 中心圆半径
        
        Parallel.For(0, _textureSize, y =>
        {
            for (int x = 0; x < _textureSize; x++)
            {
                Vector2 pixelPos = new Vector2(x, y);
                float distance = Vector2.Distance(pixelPos, _center);
                _distanceTable[x, y] = Vector2.Distance(pixelPos, _center);
                float angle = MathF.Atan2(pixelPos.Y - _center.Y, pixelPos.X - _center.X);
                _angleTable[x, y] = (angle + MathHelper.TwoPi) % MathHelper.TwoPi;

                // 初始化白色圆形
                int index = y * _textureSize + x;
                circlePixels[index] = distance <= circleRadius ? Color.White : Color.Transparent;
            }
        });
        _textureCircle.SetData(circlePixels);
    }

    /// <summary>
    /// 动态更新扇形纹理（缺口角度变化时调用）
    /// </summary>
    public void UpdateSectorTexture(float gapDegrees, Color sectorColor)
    {
        float halfGap = gapDegrees / 2;
        float gapStart = -halfGap;
        float gapEnd = halfGap;
        
        // 转换到[0, TwoPi]范围
        gapStart = (gapStart + MathHelper.TwoPi) % MathHelper.TwoPi;
        gapEnd = (gapEnd + MathHelper.TwoPi) % MathHelper.TwoPi;
        
        float radius = _textureSize / 2f;
        
        Parallel.For(0, _textureSize, y =>
        {
            for (int x = 0; x < _textureSize; x++)
            {
                int index = y * _textureSize + x;
                float distance = _distanceTable[x, y];
                float angle = _angleTable[x, y];
                
                if (distance > radius) 
                {
                    _pixelBuffer[index] = Color.Transparent;
                    continue;
                }
                
                bool inGap = (gapStart <= gapEnd) 
                    ? (angle >= gapStart && angle <= gapEnd)
                    : (angle >= gapStart || angle <= gapEnd);
                
                _pixelBuffer[index] = inGap ? Color.White : sectorColor;
            }
        });
        
        _texture.SetData(_pixelBuffer);
    }

    /// <summary>
    /// 获取当前纹理（每帧渲染时使用）
    /// </summary>
    public Texture2D GetTexture() => _texture;
    public Texture2D GetTextureCircle() => _textureCircle;
    /// <summary>
    /// 释放资源
    /// </summary>
    public void Dispose()
    {
        _texture?.Dispose();
        _texture = null;
        _pixelBuffer = null;
        _distanceTable = _angleTable = null;
    }
}
