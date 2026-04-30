# Modify System 模组

## 📖 功能概述

Modify系统是一个类似Quality（质量）的物品属性增强系统，具有以下特点：

### ✨ 核心特性
- ✅ **与Quality高度相似**：使用相同的StatType枚举，支持所有属性类型加成
- ❌ **不受技能影响**：加工台无法制造高等级Modify物品
- ❌ **无法搜刮获得**：世界生成时Modify物品始终为0级
- ✅ **仅通过StatusEffect升级**：只能通过StatusEffect改变Modify等级
- ✅ **黄色边框显示**：物品栏边框为黄色，**覆盖Quality的颜色**
- ✅ **名称后缀**：在物品名字后添加"**改装**"两字，位于Quality的"大师"等后缀后面

---

## 🔧 技术架构

```
Modify/
├── SharedProject/SharedSource/
│   ├── Modify.cs              # 核心组件类（Shared层）
│   └── Plugin.cs              # Harmony补丁和扩展方法
├── ClientProject/ClientSource/
│   └── Modify.cs              # 客户端UI逻辑（Client层）
├── Examples/
│   └── item_with_modify.xml   # 物品配置示例
└── README.md                  # 本文件
```

---

## 📝 使用方法

### 1. 在物品XML中添加Modify组件

```xml
<Item identifier="myweapon" category="Weapon" ...>
  <!-- 现有的Quality配置 -->
  <Quality>
    <QualityStat stattype="Condition" value="0.1" />
    <QualityStat stattype="FirepowerMultiplier" value="0.1" />
  </Quality>
  
  <!-- 新增的Modify配置 -->
  <Modify>
    <ModifyStat stattype="Condition" value="0.15" />
    <ModifyStat stattype="FirepowerMultiplier" value="0.12" />
    <ModifyStat stattype="FiringRateMultiplier" value="0.08" />
  </Modify>
</Item>
```

### 2. 通过StatusEffect修改Modify等级

#### 方法A：使用SetProperty（推荐）

```xml
<StatusEffect target="This">
  <!-- 设置Modify等级为2 -->
  <SetProperty name="ModifyLevel" value="2" />
</StatusEffect>
```

#### 方法B：使用自定义ActionType

```xml
<!-- 在消耗品或事件中使用 -->
<Item identifier="modifykit" category="Misc">
  <Use>
    <StatusEffect type="OnUse" target="Selected">
      <SetProperty name="ModifyLevel" value="3" />
      <Sound file="Content/Sounds/Upgrade.ogg" range="1000" />
    </StatusEffect>
  </Use>
</Item>
```

#### 方法C：通过脚本/Lua调用

```lua
-- LuaCs中修改Modify等级
local item = ...
if item then
    item:SetModifyLevel(2)  -- 设置为2级
end
```

---

## 🎨 视觉效果

### 颜色系统
| 系统 | 颜色 | 说明 |
|------|------|------|
| **Modify** | ⭐ **金黄色 (255, 215, 0)** | 始终覆盖Quality颜色 |
| Quality 0 | 白色 | 普通 |
| Quality 1 | 绿色 | 优秀 |
| Quality 2 | 蓝色 | 精良 |
| Quality 3 | 紫色 | 大师 |

### 显示效果示例

**无Modify时：**
> 🔫 左轮手枪 大师  
> ‖color:purple‖+30%‖color:end‖ 耐久度  
> ‖color:purple‖+30%‖color:end‖ 火力倍率

**有Modify时（2级）：**
> 🔫 左轮手枪 大师 改装  
> ‖color:gold‖+30%‖color:end‖ 耐久度 *(Modify属性)*  
> ‖color:gold‖+24%‖color:end‖ 火力倍率 *(Modify属性)*  
> ‖color:purple‖+20%‖color:end‖ 耐久度 *(Quality属性)*  
> ‖color:purple‖+20%‖color:end‖ 火力倍率 *(Quality属性)*

**边框颜色：** 黄色（完全覆盖Quality的紫色）

---

## ⚙️ StatType 支持列表

Modify支持与Quality完全相同的属性类型：

```csharp
public enum StatType
{
    Condition,                              // 耐久度加成
    ExplosionRadius,                        // 爆炸半径
    ExplosionDamage,                        // 爆炸伤害
    RepairSpeed,                            // 修复速度
    RepairToolStructureRepairMultiplier,    // 结构修复倍率
    RepairToolStructureDamageMultiplier,    // 结构伤害倍率
    RepairToolDeattachTimeMultiplier,       // 拆卸时间倍率
    FirepowerMultiplier,                    // 火力倍率（远程武器）
    StrikingPowerMultiplier,                // 攻击力倍率（近战武器）
    StrikingSpeedMultiplier,                // 攻击速度倍率（近战武器）
    FiringRateMultiplier                    // 射速倍率（远程武器）
}
```

---

## 🔒 限制机制

### 1. 加工台限制
```csharp
// Fabricator制造时，如果物品有Modify组件：
// → QualityResult强制设为(0, true, 0, 0)
// → 无法通过技能roll出高质量
```

### 2. 世界生成限制
```csharp
// EntitySpawner生成物品时，如果物品有Modify组件：
// → quality参数强制设为0
// → 搜刮、沉船等无法产出高等级Modify物品
```

### 3. 唯一升级途径
✅ **仅限以下方式提升Modify等级：**
- StatusEffect的`<SetProperty name="ModifyLevel" value="X" />`
- 脚本代码调用 `item.SetModifyLevel(X)`
- LuaCs脚本调用

---

## 🛠️ API参考

### Item 扩展方法

```csharp
// 获取当前Modify等级
int level = item.GetModifyLevel();

// 设置Modify等级（自动同步到Modify组件）
item.SetModifyLevel(3);

// 获取特定属性的修正值
float conditionBonus = item.GetModifyModifier(Modify.StatType.Condition);
float damageBonus = item.GetModifyModifier(Modify.StatType.FirepowerMultiplier);
```

### Modify 组件方法

```csharp
var modifyComp = item.GetComponent<Modify>();

// 获取属性值（已乘以等级）
float value = modifyComp.GetValue(Modify.StatType.Condition);

// 直接设置等级（触发重计算）
modifyComp.ModifyLevel = 2;

// 获取最大等级
int maxLevel = Modify.MaxModifyLevel; // 返回3
```

### 客户端静态方法

```csharp
// 获取Modify颜色（用于自定义UI）
Color color = Modify.GetModifyColor(modifyLevel); // 金黄色或Transparent
```

---

## 📊 数值计算公式

```
最终属性值 = 基础值 × (1 + Quality修正 + Modify修正)

其中：
- Quality修正 = qualityStatValue × QualityLevel
- Modify修正 = modifyStatValue × ModifyLevel

示例（Condition属性）：
基础耐久度 = 100
Quality: statValue=0.1, level=3 → 修正 = 30%
Modify: statValue=0.15, level=2 → 修正 = 30%
最终最大耐久度 = 100 × (1 + 0.3 + 0.3) = 160
```

---

## 🚀 高级用法

### 动态调整Modify等级

```xml
<!-- 根据条件动态设置不同等级 -->
<StatusEffect target="This">
  <Conditional>
    <If hasTag="elite" />
    <Then>
      <SetProperty name="ModifyLevel" value="3" />
    </Then>
    <Else>
      <SetProperty name="ModifyLevel" value="1" />
    </Else>
  </Conditional>
</StatusEffect>
```

### 组合使用Quality和Modify

```xml
<Item identifier="supergun" ...>
  <!-- Quality提供基础加成（可通过技能/搜刮获得） -->
  <Quality>
    <QualityStat stattype="FirepowerMultiplier" value="0.1" />
  </Quality>
  
  <!-- Modify提供额外加成（仅能通过特殊途径获得） -->
  <Modify>
    <ModifyStat stattype="FirepowerMultiplier" value="0.2" />
    <ModifyStat stattype="FiringRateMultiplier" value="0.15" />
  </Modify>
</Item>

<!-- 结果：满级时火力 = 基础 × (1 + 0.3[Quality] + 0.6[Modify]) = 基础 × 1.9 -->
```

---

## ⚠️ 注意事项

1. **性能考虑**：Modify组件会轻微增加内存占用（每个带Modify的物品约多几字节）
2. **网络同步**：ModifyLevel会通过网络同步到其他玩家
3. **兼容性**：与现有Quality系统完全兼容，可同时存在
4. **存档安全**：ModifyLevel会被保存到存档中

---

## 🐛 故障排除

### 问题：Modify边框不显示
**解决方案**：确认物品XML中有`<Modify>`组件定义

### 问题：StatusEffect无法修改ModifyLevel
**解决方案**：检查目标是否正确，应使用`target="This"`或`target="Contained"`

### 问题：名称后缀位置错误
**解决方案**：这是正常行为 - "改装"始终在Quality后缀之后

---

## 📄 版本历史

- **v1.0.0** (2026-04-21)
  - 初始版本
  - 实现核心Modify系统
  - 支持所有Quality属性类型
  - 完整的UI集成（边框+名称后缀）
  - StatusEffect支持
  - 加工台/生成器限制

---

## 👥 开发者信息

**模组作者**：AI Assistant  
**基于框架**：LuaCsForBarotrauma  
**依赖库**：Lib.Harmony 2.3.3  
**兼容性**：Barotrauma v1.0+

---

## 📜 许可证

本项目采用与LuaCsForBarotrauma相同的许可证。
