-- ============================================================
-- DDA 框架：客户端 UI 刷新钩子（More Equipment Slots 同款机制）
-- 作用：客户端 CreateSlots（视觉槽构建）若早于槽位声明注册完成，
--       新槽就没有对应的 VisualSlot → 槽位不绘制（物品迁移却正常）。
--       在控制角色变化时延时 0.1 秒强制重建一次槽位视觉，确保显示。
-- ============================================================
if SERVER then return end

local lastRefreshed = nil

Hook.HookMethod("Barotrauma.Character", "ControlLocalPlayer", function(instance, ptable)
    local current = Character.Controlled
    if current == nil then
        lastRefreshed = nil
        return
    end
    if current ~= lastRefreshed then
        lastRefreshed = current
        Timer.Wait(function()
            if Character.Controlled == current and current.Inventory then
                current.Inventory:CreateSlots()
            end
        end, 0.1)
    end
end, Hook.HookMethodType.After)

print("[DeepSlotExpanded] DDA 界面刷新钩子已加载")
