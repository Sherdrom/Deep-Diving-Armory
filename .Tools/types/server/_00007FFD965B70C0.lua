---@meta
---@class System.Int16 : System.ValueType, integer
---`Field Private Instance`
---@field m_value System.Int16
---`Field Public Static`
---@field MaxValue System.Int16
---`Field Public Static`
---@field MinValue System.Int16
_G['System']['Int16'] = {}

---`Method Public Instance Virtual`
---@overload fun(value:System.Object):(System.Int32)
---@param value System.Int16
---@return System.Int32
_G['System']['Int16'].CompareTo = function(value) end

---`Method Public Instance Virtual`
---@overload fun(obj:System.Object):(System.Boolean)
---@param obj System.Int16
---@return System.Boolean
_G['System']['Int16'].Equals = function(obj) end

---`Method Public Instance Virtual`
---@return System.Int32
_G['System']['Int16'].GetHashCode = function() end

---`Method Public Instance Virtual`
---@overload fun():(System.String)
---@overload fun(provider:System.IFormatProvider):(System.String)
---@param format System.String
---@param provider System.IFormatProvider
---@return System.String
_G['System']['Int16'].ToString = function(format, provider) end

---`Method Public Instance`
---@param format System.String
---@return System.String
_G['System']['Int16'].ToString = function(format) end

---`Method Public Instance Virtual`
---@param destination System.Span*1System*Char
---@param charsWritten System.Int32-ref
---@param format? System.ReadOnlySpan*1System*Char
---@param provider? System.IFormatProvider
---@return System.Boolean
_G['System']['Int16'].TryFormat = function(destination, charsWritten, format, provider) end

---`Method Public Static`
---@overload fun(s:System.String):(System.Int16)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles):(System.Int16)
---@overload fun(s:System.String, provider:System.IFormatProvider):(System.Int16)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider):(System.Int16)
---@param s System.ReadOnlySpan*1System*Char
---@param style? System.Globalization.NumberStyles
---@param provider? System.IFormatProvider
---@return System.Int16
_G['System']['Int16'].Parse = function(s, style, provider) end

---`Method Private Static`
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param info System.Globalization.NumberFormatInfo
---@return System.Int16
_G['System']['Int16'].Parse = function(s, style, info) end

---`Method Public Static`
---@overload fun(s:System.String, result:System.Int16-ref):(System.Boolean)
---@overload fun(s:System.ReadOnlySpan*1System*Char, result:System.Int16-ref):(System.Boolean)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider, result:System.Int16-ref):(System.Boolean)
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param provider System.IFormatProvider
---@param result System.Int16-ref
---@return System.Boolean
_G['System']['Int16'].TryParse = function(s, style, provider, result) end

---`Method Private Static`
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param info System.Globalization.NumberFormatInfo
---@param result System.Int16-ref
---@return System.Boolean
_G['System']['Int16'].TryParse = function(s, style, info, result) end

---`Method Public Instance Virtual`
---@return System.TypeCode
_G['System']['Int16'].GetTypeCode = function() end

