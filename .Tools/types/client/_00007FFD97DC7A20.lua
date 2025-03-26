---@meta
---@class Barotrauma.AIObjectiveDecontainItem : Barotrauma.AIObjective
---`Field Public Instance`
---@field GetItemPriority (System.Func*1Barotrauma*Item*1System*Single)|(fun(arg:Barotrauma.Item):(System.Single))
---`Field Private Instance`
---@field itemIdentifiers (Barotrauma.Identifier-arr)|(Barotrauma.Identifier[])
---`Field Private Instance`
---@field sourceContainer Barotrauma.Items.Components.ItemContainer
---`Field Private Instance`
---@field targetContainer Barotrauma.Items.Components.ItemContainer
---`Field Private Instance`
---@field targetItem Barotrauma.Item
---`Field Private Instance`
---@field getItemObjective Barotrauma.AIObjectiveGetItem
---`Field Private Instance`
---@field containObjective Barotrauma.AIObjectiveContainItem
---`Getter Public Instance Virtual`
---<br/>`Setter Public Instance Virtual`
---@field Identifier Barotrauma.Identifier
---`Getter NonPublic Instance Virtual`
---@field AllowWhileHandcuffed System.Boolean
---`Getter Public Instance`
---@field GetItemObjective Barotrauma.AIObjectiveGetItem
---`Getter Public Instance`
---@field ContainObjective Barotrauma.AIObjectiveContainItem
---`Getter Public Instance`
---@field TargetItem Barotrauma.Item
---`Getter Public Instance`
---@field TargetContainer Barotrauma.Items.Components.ItemContainer
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field Equip System.Boolean
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field TakeWholeStack System.Boolean
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field DropIfFails System.Boolean
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field RemoveExistingWhenNecessary System.Boolean
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field RemoveExistingPredicate (System.Func*1Barotrauma*Item*1System*Boolean)|(fun(arg:Barotrauma.Item):(System.Boolean))
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field RemoveExistingMax System.Nullable*1System*Int32
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field AbandonGetItemDialogueIdentifier System.String
---`Getter Public Instance`
---<br/>`Setter Public Instance`
---@field AbandonGetItemDialogueCondition (System.Func*1System*Boolean)|(fun():(System.Boolean))
_G['AIObjectiveDecontainItem'] = {}

---`Method NonPublic Instance Virtual`
---@return System.Boolean
_G['AIObjectiveDecontainItem'].CheckObjectiveState = function() end

---`Method NonPublic Instance Virtual`
---@param deltaTime System.Single
_G['AIObjectiveDecontainItem'].Act = function(deltaTime) end

---`Method Public Instance Virtual`
_G['AIObjectiveDecontainItem'].Reset = function() end

---`Method NonPublic Instance Virtual`
_G['AIObjectiveDecontainItem'].OnAbandon = function() end

---`Constructor Public Instance`
---@overload fun(character:Barotrauma.Character, targetItem:Barotrauma.Item, objectiveManager:Barotrauma.AIObjectiveManager, sourceContainer?:Barotrauma.Items.Components.ItemContainer, targetContainer?:Barotrauma.Items.Components.ItemContainer, priorityModifier?:System.Single):Barotrauma.AIObjectiveDecontainItem
---@overload fun(character:Barotrauma.Character, itemIdentifier:Barotrauma.Identifier, objectiveManager:Barotrauma.AIObjectiveManager, sourceContainer:Barotrauma.Items.Components.ItemContainer, targetContainer?:Barotrauma.Items.Components.ItemContainer, priorityModifier?:System.Single):Barotrauma.AIObjectiveDecontainItem
---@param character Barotrauma.Character
---@param itemIdentifiers (Barotrauma.Identifier-arr)|(Barotrauma.Identifier[])
---@param objectiveManager Barotrauma.AIObjectiveManager
---@param sourceContainer Barotrauma.Items.Components.ItemContainer
---@param targetContainer? Barotrauma.Items.Components.ItemContainer
---@param priorityModifier? System.Single
---@return Barotrauma.AIObjectiveDecontainItem
_G['AIObjectiveDecontainItem'] = function(character, itemIdentifiers, objectiveManager, sourceContainer, targetContainer, priorityModifier) end

---`Constructor Public Instance`
---@overload fun(character:Barotrauma.Character, targetItem:Barotrauma.Item, objectiveManager:Barotrauma.AIObjectiveManager, sourceContainer?:Barotrauma.Items.Components.ItemContainer, targetContainer?:Barotrauma.Items.Components.ItemContainer, priorityModifier?:System.Single):Barotrauma.AIObjectiveDecontainItem
---@overload fun(character:Barotrauma.Character, itemIdentifier:Barotrauma.Identifier, objectiveManager:Barotrauma.AIObjectiveManager, sourceContainer:Barotrauma.Items.Components.ItemContainer, targetContainer?:Barotrauma.Items.Components.ItemContainer, priorityModifier?:System.Single):Barotrauma.AIObjectiveDecontainItem
---@param character Barotrauma.Character
---@param itemIdentifiers (Barotrauma.Identifier-arr)|(Barotrauma.Identifier[])
---@param objectiveManager Barotrauma.AIObjectiveManager
---@param sourceContainer Barotrauma.Items.Components.ItemContainer
---@param targetContainer? Barotrauma.Items.Components.ItemContainer
---@param priorityModifier? System.Single
---@return Barotrauma.AIObjectiveDecontainItem
_G['AIObjectiveDecontainItem'].__new = function(character, itemIdentifiers, objectiveManager, sourceContainer, targetContainer, priorityModifier) end

