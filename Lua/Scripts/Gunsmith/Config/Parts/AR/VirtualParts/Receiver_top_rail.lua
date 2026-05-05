Deep_Lua.Gunsmith = Deep_Lua.Gunsmith or {}

local parts = Deep_Lua.Gunsmith.Config.parts

-- 虚拟配件：它不消耗实体 item，也不额外绘制贴图。适用于自带多个导轨的配件，例如有的护木自带四个导轨，就不需要加实体导轨，改用虚拟导轨确定配件挂点。
parts.AR_receiver_top_rail = { type = "receiver_top_rail",
    nameKey = "deep.gunsmith.part.AR_receiver_top_rail",
    provides = { "AR_top_rail" },
    item = { virtual = true },
    mounts = { -- 只是一个例子，说明虚拟配件也可以提供挂点，UI 会正常显示“进入该配件挂点”。实际设计时可以根据需要调整挂点数量、位置和接受的配件类型。
        -- path 是 UI 展示路径用的；partType 指向候选配件使用的通用类型。
        -- 因此前后挂点都能安装 type = "optic_mount" 的通用瞄具。
        { path = "rear_optic_mount", nameKey = "deep.gunsmith.mount.AR_receiver_top_rail.rear_optic_mount", partType = "optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 0, y = 0 } },
        { path = "front_optic_mount", nameKey = "deep.gunsmith.mount.AR_receiver_top_rail.front_optic_mount", partType = "optic_mount", accepts = { "small_optic", "medium_optic" }, anchor = { x = 42, y = 0 } }
    }
}
