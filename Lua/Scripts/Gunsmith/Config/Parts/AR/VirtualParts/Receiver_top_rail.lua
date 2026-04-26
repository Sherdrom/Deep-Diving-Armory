Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 虚拟配件：机匣自带顶部导轨。
-- 它不消耗实体 item，也不额外绘制贴图，只负责把一个机匣挂点展开成前/后两个瞄具挂点。
parts.AR_receiver_top_rail = {
    slot = "receiver_top_rail",
    name = "机匣顶部导轨",
    provides = { "AR_top_rail" },
    item = { virtual = true },
    mounts = {
        -- 只是一个例子，说明虚拟配件也可以提供挂点，UI 会正常显示“进入该配件挂点”。实际设计时可以根据需要调整挂点数量、位置和接受的配件类型。
        -- slot 是保存/UI 路径，必须唯一；partSlot 指向候选配件使用的通用槽位。
        -- 因此前后挂点都能安装 slot = "optic_mount" 的通用瞄具。
        { slot = "rear_optic_mount", name = "后瞄具挂点", partSlot = "optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 0, y = 0 } },
        -- { slot = "front_optic_mount", name = "前瞄具挂点", partSlot = "optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 42, y = 0 } }
    }
}
