---@meta
---@class System.Byte : System.ValueType, integer
---`Field Private Instance`
---@field m_value System.Byte
---`Field Public Static`
---@field MaxValue System.Byte
---`Field Public Static`
---@field MinValue System.Byte
_G['System']['Byte'] = {}

---`Method Public Instance Virtual`
---@overload fun(value:System.Object):(System.Int32)
---@param value System.Byte
---@return System.Int32
_G['System']['Byte'].CompareTo = function(value) end

---`Method Public Instance Virtual`
---@overload fun(obj:System.Object):(System.Boolean)
---@param obj System.Byte
---@return System.Boolean
_G['System']['Byte'].Equals = function(obj) end

---`Method Public Instance Virtual`
---@return System.Int32
_G['System']['Byte'].GetHashCode = function() end

---`Method Public Static`
---@overload fun(s:System.String):(System.Byte)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles):(System.Byte)
---@overload fun(s:System.String, provider:System.IFormatProvider):(System.Byte)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider):(System.Byte)
---@param s System.ReadOnlySpan*1System*Char
---@param style? System.Globalization.NumberStyles
---@param provider? System.IFormatProvider
---@return System.Byte
_G['System']['Byte'].Parse = function(s, style, provider) end

---`Method Private Static`
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param info System.Globalization.NumberFormatInfo
---@return System.Byte
_G['System']['Byte'].Parse = function(s, style, info) end

---`Method Public Static`
---@overload fun(s:System.String, result:System.Byte-ref):(System.Boolean)
---@overload fun(s:System.ReadOnlySpan*1System*Char, result:System.Byte-ref):(System.Boolean)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider, result:System.Byte-ref):(System.Boolean)
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param provider System.IFormatProvider
---@param result System.Byte-ref
---@return System.Boolean
_G['System']['Byte'].TryParse = function(s, style, provider, result) end

---`Method Private Static`
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param info System.Globalization.NumberFormatInfo
---@param result System.Byte-ref
---@return System.Boolean
_G['System']['Byte'].TryParse = function(s, style, info, result) end

---`Method Public Instance Virtual`
---@overload fun():(System.String)
---@overload fun(provider:System.IFormatProvider):(System.String)
---@param format System.String
---@param provider System.IFormatProvider
---@return System.String
_G['System']['Byte'].ToString = function(format, provider) end

---`Method Public Instance`
---@param format System.String
---@return System.String
_G['System']['Byte'].ToString = function(format) end

---`Method Public Instance Virtual`
---@param destination System.Span*1System*Char
---@param charsWritten System.Int32-ref
---@param format? System.ReadOnlySpan*1System*Char
---@param provider? System.IFormatProvider
---@return System.Boolean
_G['System']['Byte'].TryFormat = function(destination, charsWritten, format, provider) end

---`Method Public Instance Virtual`
---@return System.TypeCode
_G['System']['Byte'].GetTypeCode = function() end

