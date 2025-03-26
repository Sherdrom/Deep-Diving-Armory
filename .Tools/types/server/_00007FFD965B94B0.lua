---@meta
---@class System.Int32 : System.ValueType, integer
---`Field Private Instance`
---@field m_value System.Int32
---`Field Public Static`
---@field MaxValue System.Int32
---`Field Public Static`
---@field MinValue System.Int32
_G['System']['Int32'] = {}

---`Method NonPublic Static`
---@param value System.Int32.TOther
---@return System.Int32
_G['System']['Int32'].Create = function(value) end

---`Method Public Instance Virtual`
---@overload fun(value:System.Object):(System.Int32)
---@param value System.Int32
---@return System.Int32
_G['System']['Int32'].CompareTo = function(value) end

---`Method Public Instance Virtual`
---@overload fun(obj:System.Object):(System.Boolean)
---@param obj System.Int32
---@return System.Boolean
_G['System']['Int32'].Equals = function(obj) end

---`Method Public Instance Virtual`
---@return System.Int32
_G['System']['Int32'].GetHashCode = function() end

---`Method Public Instance Virtual`
---@overload fun():(System.String)
---@overload fun(provider:System.IFormatProvider):(System.String)
---@param format System.String
---@param provider System.IFormatProvider
---@return System.String
_G['System']['Int32'].ToString = function(format, provider) end

---`Method Public Instance`
---@param format System.String
---@return System.String
_G['System']['Int32'].ToString = function(format) end

---`Method Public Instance Virtual`
---@param destination System.Span*1System*Char
---@param charsWritten System.Int32-ref
---@param format? System.ReadOnlySpan*1System*Char
---@param provider? System.IFormatProvider
---@return System.Boolean
_G['System']['Int32'].TryFormat = function(destination, charsWritten, format, provider) end

---`Method Public Static`
---@overload fun(s:System.String):(System.Int32)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles):(System.Int32)
---@overload fun(s:System.String, provider:System.IFormatProvider):(System.Int32)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider):(System.Int32)
---@param s System.ReadOnlySpan*1System*Char
---@param style? System.Globalization.NumberStyles
---@param provider? System.IFormatProvider
---@return System.Int32
_G['System']['Int32'].Parse = function(s, style, provider) end

---`Method Public Static`
---@overload fun(s:System.String, result:System.Int32-ref):(System.Boolean)
---@overload fun(s:System.ReadOnlySpan*1System*Char, result:System.Int32-ref):(System.Boolean)
---@overload fun(s:System.String, style:System.Globalization.NumberStyles, provider:System.IFormatProvider, result:System.Int32-ref):(System.Boolean)
---@param s System.ReadOnlySpan*1System*Char
---@param style System.Globalization.NumberStyles
---@param provider System.IFormatProvider
---@param result System.Int32-ref
---@return System.Boolean
_G['System']['Int32'].TryParse = function(s, style, provider, result) end

---`Method Public Instance Virtual`
---@return System.TypeCode
_G['System']['Int32'].GetTypeCode = function() end

