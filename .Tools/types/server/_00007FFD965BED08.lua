---@meta
---@class System.Single : System.ValueType, number
---@operator mul(Microsoft.Xna.Framework.Vector2):Microsoft.Xna.Framework.Vector2
---@operator mul(Microsoft.Xna.Framework.Vector3):Microsoft.Xna.Framework.Vector3
---@operator mul(Microsoft.Xna.Framework.Vector4):Microsoft.Xna.Framework.Vector4
---`Field Private Instance`
---@field m_value System.Single
---`Field Public Static`
---@field MinValue System.Single
---`Field Public Static`
---@field Epsilon System.Single
---`Field Public Static`
---@field MaxValue System.Single
---`Field Public Static`
---@field PositiveInfinity System.Single
---`Field Public Static`
---@field NegativeInfinity System.Single
---`Field Public Static`
---@field NaN System.Single
_G['System']['Single'] = {}

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsFinite = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsInfinity = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsNaN = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsNegative = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsNegativeInfinity = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsNormal = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsPositiveInfinity = function(f) end

---`Method Public Static`
---@param f System.Single
---@return System.Boolean
_G['System']['Single'].IsSubnormal = function(f) end

---`Method NonPublic Static`
---@param bits System.UInt32
---@return System.Int32
_G['System']['Single'].ExtractExponentFromBits = function(bits) end

---`Method NonPublic Static`
---@param bits System.UInt32
---@return System.UInt32
_G['System']['Single'].ExtractSignificandFromBits = function(bits) end

---`Method Public Instance Virtual`
---@overload fun(value:System.Object):(System.Int32)
---@param value System.Single
---@return System.Int32
_G['System']['Single'].CompareTo = function(value) end

---`Method Public Instance Virtual`
---@overload fun(obj:System.Object):(System.Boolean)
---@param obj System.Single
---@return System.Boolean
_G['System']['Single'].Equals = function(obj) end

---`Method Public Instance Virtual`
---@return System.Int32
_G['System']['Single'].GetHashCode = function() end

---`Method Public Instance Virtual`
---@overload fun():(System.String)
---@overload fun(provider:System.IFormatProvider):(System.String)
---@param format System.String
---@param provider System.IFormatProvider
---@return System.String
_G['System']['Single'].ToString = function(format, provider) end

---`Method Public Instance`
---@param format System.String
---@return System.String
_G['System']['Single'].ToString = function(format) end

---`Method Public Instance Virtual`
---@param destination System.Span*1System*Char
---@param charsWritten System.Int32-ref
---@param format? System.ReadOnlySpan*1System*Char
---@param provider? System.IFormatProvider
---@return System.Boolean
_G['System']['Single'].TryFormat = function(destination, charsWritten, format, provider) end

---`Method Public Static`
---@overload fun(s:System.String):(System.Single)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles):(System.Single)
---@overload fun(s:System.String, provider:System.IFormatProvider):(System.Single)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider):(System.Single)
---@param s System.ReadOnlySpan*1System*Char
---@param style? System.Globalization.NumberStyles
---@param provider? System.IFormatProvider
---@return System.Single
_G['System']['Single'].Parse = function(s, style, provider) end

---`Method Public Static`
---@overload fun(s:System.String, result:System.Single-ref):(System.Boolean)
---@overload fun(s:System.ReadOnlySpan*1System*Char, result:System.Single-ref):(System.Boolean)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider, result:System.Single-ref):(System.Boolean)
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param provider System.IFormatProvider
---@param result System.Single-ref
---@return System.Boolean
_G['System']['Single'].TryParse = function(s, style, provider, result) end

---`Method Private Static`
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param info System.Globalization.NumberFormatInfo
---@param result System.Single-ref
---@return System.Boolean
_G['System']['Single'].TryParse = function(s, style, info, result) end

---`Method Public Instance Virtual`
---@return System.TypeCode
_G['System']['Single'].GetTypeCode = function() end

