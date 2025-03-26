---@meta
---@class Barotrauma.LevelWallVertexBuffer : System.Object
---`Field Public Instance`
---@field WallEdgeBuffer Microsoft.Xna.Framework.Graphics.VertexBuffer
---`Field Public Instance`
---@field WallBuffer Microsoft.Xna.Framework.Graphics.VertexBuffer
---`Field Public Instance`
---@field WallTexture Microsoft.Xna.Framework.Graphics.Texture2D
---`Field Public Instance`
---@field EdgeTexture Microsoft.Xna.Framework.Graphics.Texture2D
---`Field Private Instance`
---@field wallVertices (Microsoft.Xna.Framework.Graphics.VertexPositionColorTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionColorTexture[])
---`Field Private Instance`
---@field wallEdgeVertices (Microsoft.Xna.Framework.Graphics.VertexPositionColorTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionColorTexture[])
---`Getter Public Instance`
---<br/>`Setter Private Instance`
---@field IsDisposed System.Boolean
_G['LevelWallVertexBuffer'] = {}

---`Method Public Instance`
---@param wallVertices (Microsoft.Xna.Framework.Graphics.VertexPositionTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionTexture[])
---@param wallEdgeVertices (Microsoft.Xna.Framework.Graphics.VertexPositionTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionTexture[])
---@param color Microsoft.Xna.Framework.Color
_G['LevelWallVertexBuffer'].Append = function(wallVertices, wallEdgeVertices, color) end

---`Method Public Instance Virtual`
_G['LevelWallVertexBuffer'].Dispose = function() end

---`Constructor Public Instance`
---@param wallVertices (Microsoft.Xna.Framework.Graphics.VertexPositionTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionTexture[])
---@param wallEdgeVertices (Microsoft.Xna.Framework.Graphics.VertexPositionTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionTexture[])
---@param wallTexture Microsoft.Xna.Framework.Graphics.Texture2D
---@param edgeTexture Microsoft.Xna.Framework.Graphics.Texture2D
---@param color Microsoft.Xna.Framework.Color
---@return Barotrauma.LevelWallVertexBuffer
_G['LevelWallVertexBuffer'] = function(wallVertices, wallEdgeVertices, wallTexture, edgeTexture, color) end

---`Constructor Public Instance`
---@param wallVertices (Microsoft.Xna.Framework.Graphics.VertexPositionTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionTexture[])
---@param wallEdgeVertices (Microsoft.Xna.Framework.Graphics.VertexPositionTexture-arr)|(Microsoft.Xna.Framework.Graphics.VertexPositionTexture[])
---@param wallTexture Microsoft.Xna.Framework.Graphics.Texture2D
---@param edgeTexture Microsoft.Xna.Framework.Graphics.Texture2D
---@param color Microsoft.Xna.Framework.Color
---@return Barotrauma.LevelWallVertexBuffer
_G['LevelWallVertexBuffer'].__new = function(wallVertices, wallEdgeVertices, wallTexture, edgeTexture, color) end

