# 技术文档：代码逻辑与引擎 API

> 本文面向维护者，描述经验球的计算与实现。所有 API 均在 **Project Zomboid 42.20.x** 实测验证。
> 用户向说明见 [README.md](../README.md)。

## 1. 一次死亡结算的完整链路

```
[角色死亡]
   │
   ├─ 服务器 Events.OnPlayerDeath（单机/本地主机直接生效）
   ├─ 客户端 Events.OnPlayerDeath / OnTick 轮询 → sendClientCommand("onPlayerDeath", 经验快照)
   └─ 服务器 OnTick 轮询 isDead()（兜底）
   │
   ▼
processDeath(playerObj, force, payload)
   ├─ token 去重（客户端会在重生后重发数次，服务端只结算一次）
   ├─ ownerSteam / ownerUser / charName（账号名）解析
   ├─ baseline = 角色出生瞬间的经验快照
   └─ 对 35 个技能逐个 recoverableXp():
          可回收 = 当前累计XP − baseline − 电视/VHS 记账
                   × RecoveryRatio（钳制 0.01~1.0，四舍五入到 0.01）
          ≤ 0 → 不生成该技能的球
   │
   ▼
按尸体周围格子循环 AddWorldInventoryItem("Base.XpOrb_<技能>")
   ├─ ModData: xp / cap / ownerSteam / ownerUser / char / perk
   ├─ 用量条 usedDelta = 球内经验 ÷ 容量（保底一格，见 §4）
   └─ 物品名 setName("<技能球>(<账号名>)") + setCustomName(true)
```

## 2. 免费经验：出生快照 baseline

角色的"初始等级"不是练出来的，必须扣除。做法不是去猜特质/职业数据，而是**读一次出生瞬间的经验**：

- 角色创建时（`Events.OnCreatePlayer`，以及 Tick 兜底，仅当 `getHoursSurvived() <= 0.1`）
  把每个技能的 XP 存进角色 ModData：`playerModData.ExperienceOrbBaseline`
  （压缩字符串 `Strength=337500;Fitness=37500;…`，随存档持久化）；
- 死亡结算：`可回收XP = 当前XP − baseline[技能] − 媒体XP`；
- 结算后清空 baseline，重生后重新记录；离线/重进不会重复记录（字段已存在则跳过）。

这样"初始等级"无论是基础等级（力量/体格基础 5 级）、特质加成还是职业加成，都会被精确扣除，
不依赖任何公式猜测。

**引擎实测经验曲线**（`Debug=true` 时启动会打印 `curve <技能> totalXpForLevel: 1=… 10=…`）：

| 技能类型 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| 普通技能 | 75 | 225 | 525 | 1275 | 2775 | 5775 | 10275 | 16275 | 23775 | **32775** |
| 力量/体格 | 1500 | 4500 | 10500 | 19500 | 37500 | 67500 | 127500 | 217500 | 337500 | **487500** |

例：`Lumberjack`（力量 +1）出生 6 级 = 67,500 XP；练到 10 级（487,500）死亡 →
球内 = 487,500 − 67,500 = **420,000**，正好是 7~10 级的量。引擎在 10 级封顶，
所以我们把 `totalXpForLevel(perk, 10)` 当作球的"容量"。

**老角色退回算法**（mod 安装前就存在的角色没有 baseline）：被动技能取 `5 + 加成`，
其它技能取加成等级，再扣 `perk:getTotalXpForLevel(等级)`。游戏数据示例：
`Strong = XPBoosts Strength=4`、`Athletic = Fitness=4`、`Weak = Strength=-5`、
`Lumberjack = Axe=2;Strength=1;Maintenance=1`。注意被动技能取 `5 + 加成` 而不是"当前等级"，
否则练上去的等级会被误当作免费部分。

## 3. 电视 / VHS 经验排除

B42 里电视与 VHS 走同一发放通道。实现方式是包装原版客户端脚本的
`ISRadioInteractions:getInstance().checkPlayer`，每行播报前后做一次各技能 XP 增量差，
累加到 `ExperienceOrbMedia[playerObj][perkId]`；死亡结算时按技能扣除。
该记账**只存在于客户端**（RadioCom 是客户端类），因此联机时必须靠客户端死亡快照把记账带给服务端（§6）。

## 4. 容量与用量条

球是"容器"，容量 = 该技能 10 级总经验：

```lua
room  = cap − 当前累计XP                -- cap = totalXpForLevel(perk, 10)
grant = min(球内XP, room)               -- 只发放能装下的部分
remaining = 球内XP − grant              -- 余量留在球里，球不消失
```

物品脚本用原版 drainable 机制显示用量：

```
ItemType  = base:drainable,
UseDelta  = 0.000001,      -- 100 万档，只影响进度条精度
```
`usedDelta = 球内经验 ÷ 容量`（1.0 = 满）。

> ⚠ **关键坑：用量不能归零。** 引擎把 `uses <= 0` 的 drainable 判为"空"：名字被加上
> `(Empty)`（中文 `(倒空)`），并且**转移（客户端按网络包重建物品）时会被容器过滤/销毁**——
> 表现为"球一捡就消失"。早期 `UseDelta = 0.001` 时，`8/32775`（0.024%）会被四舍五入成 0 格，
> 于是踩中此坑。现在除了把粒度调细，还**强制保底一格**：

```lua
if frac < item:getUseDelta() then frac = item:getUseDelta() end
```

只要球里还有经验，`uses ≥ 1`，永远不会被判空、不会消失、也不会出现 `(倒空)` 字样。
真正吸干净时由服务端自己删球（日志 `orb emptied`）。

## 5. 吸收流程（右键 → 服务端结算）

1. 客户端 `Events.OnFillInventoryObjectContextMenu` 里为球加一项
   `ContextMenu_ExperienceOrb_Use`（标签带归属，如 `吸收经验球(Shimakaze)`），
   发送 `sendClientCommand(player, "ExperienceOrb", "useOrb", { itemID = … })`；
2. 服务端 `Events.OnClientCommand` → 校验归属（SteamID 数值比较或账号名，`AllowAnyoneToAbsorb` 可放开）；
3. 计算 `room`/`grant`/`remaining`，用 **`addXpNoMultiplier`** 发放（不吃沙盒经验倍率，
   引擎没有该函数时才退回 `addXp`）；
4. 未吸完：写回 `md.xp`、更新用量条、`syncItemFields()` 同步给客户端，物品保留；
   吸完：`inv:Remove` + `sendRemoveItemFromContainer`；
5. 结果**数值**回传客户端（`sendServerCommand … "orbResult"`），由客户端用
   `_Gained` / `_Partial` / `_Capped` 三个翻译键拼**本机语言**的头顶提示。

## 6. 联机可靠性

专用服务器在玩家死亡瞬间可能已经把该 PlayerObject 替换掉，日志里会看到
`replacing dead player` / `Player with PlayerID ='4' not found!` / `receiveClientCommand: player is null`，
此时服务端拿不到任何经验数据。因此：

- 客户端在死亡瞬间采集**经验快照**（`xp` / `media` / `start` / 坐标 / SteamID / 账号名 / token）并上报；
- 服务端**优先用实时对象**，对象不存在或已重生时用快照补齐（快照里 XP 更大时以快照为准）；
- 客户端在重生后重发数次以跨过 `player is null` 窗口，服务端用 token 去重，保证只结算一次；
- 服务端 `OnTick` 轮询 `isDead()` 作为第三条通道。

**所有引擎调用都先做方法存在性检查**（`tryMethod`）：Kahlua 的 `pcall` 拦不住"调用不存在的 Java 方法"
抛出的异常，所以不能用 `pcall` 兜底。

## 7. 老存档 / 旧球兼容

**策略：旧球原样保留，只有新爆出的球走新逻辑；旧物品等后续版本统一清理。**

引擎依据：`InventoryItem.loadItem` 是按存档里记录的 `ItemType` **id**
走 `InventoryItemFactory.CreateItem(short)` 建实例的，所以旧球读档后仍是 `base:normal`，
不会自己变成 drainable。

| 旧状态 | 升级后表现 | 处理 |
|---|---|---|
| 类别是旧的 `base:normal` | 仍可捡、可吸、可留余量，只是**没有用量条** | 不替换、不迁移；吸收时就地更新 `md.xp`；用量相关调用全部 `pcall` 包裹，旧物品类直接忽略 |
| 没有 `md.cap` | 逻辑照常（现算容量） | 服务端按 `totalXpForLevel(perk, 10)` 计算，字段缺失时补写 |
| `md.ownerSteam` 是科学计数法（`7.656119814527621E16`） | 归属仍可识别 | `SameOwner()` 先按字符串、再按数值比较 |
| 球名被旧版本用**服务器语言** `setName()` 冻结 | 会显示成英文球名 | 客户端扫到球时按本机语言重算并覆盖 |
| 技能等级/经验本身 | 不受影响 | baseline 写在角色 ModData；老角色退回特质/职业算法 |

> 后续清理旧球时：遍历在线玩家背包与已加载容器里的 `Base.XpOrb_*` 普通物品 →
> 用同类型新物品替换并搬运 `ModData`。

## 8. 其它实现约束

- **`.lua` 必须是纯 ASCII**：LuaJ 词法分析器遇到非 ASCII 字节会在 `LexState.token2str` 抛
  `ArrayIndexOutOfBoundsException`，整个文件作废。中文只出现在 JSON 翻译文件里（详见 [I18N.md](I18N.md)）。
- 物品定义在 `42.20/media/scripts/items_XpOrb.txt`：35 个物品，
  `Icon = XpOrb_<技能>`、`CanStack = false`、`cantBeConsolided = true`、`WorldStaticModel = TennisBall`。
- 掉落位置：尸体所在格优先，其次周围 `DropSpreadRadius` 格（跳过实心格与车辆碰撞格）。
