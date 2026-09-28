# 经验球 Experience Orb (Project Zomboid Build 42.20)

玩家死亡时，按其**实际练出来的技能经验**在尸体附近地面生成「经验球」；
把经验球捡进背包后，**右键 → “吸收经验球”**，按配置比例恢复经验
（与遗书/墓碑/技能日志类 mod 思路类似，B42；吸收量算法参照 Skill Recovery Journal）。

## 特性

- 覆盖 B42 全部可积累经验的原版技能（35 项：木工/烹饪/耕作/急救/电工/金工/技工/缝纫/钓鱼/诱捕/搜寻/石器/石工/陶艺/雕刻/畜牧/追踪/锻造/屠宰/玻璃 + 武器/近战 + 移动 + 体格/力量），每个技能一种经验球物品；
- 某技能从未获得经验（或只来自赠送）→ 不生成该技能的经验球；
- **不计算电视/VHS 录像获得的经验**（B42 两者同一发放通道；mod 通过包装
  `ISRadioInteractions` 逐行增量记账，死亡时精确扣除）；
- **不计算天赋/职业/被动赠送的“免费等级”**：以角色**出生瞬间的经验快照**
  （baseline）为准（基础等级、特质、职业加成全部已包含），死亡时按
  `当前XP − baseline − 媒体XP` 结算；装 mod 之前就存在的老角色退回按
  职业/天赋 XPBoosts 计算（被动技能取 `5 + 加成`）；
- 恢复比例可配置 `0.01 ~ 1.0`（默认 1.0 = 100%）；
- 经验球有归属：默认仅死亡玩家本人（按 SteamID）可吸收，单机本地不拦截；
  `AllowAnyoneToAbsorb=true` 时人人可用；
- **球名带归属**：`力量经验球(Shimakaze)`，括号里是**账号名**（`getUsername`），
  多人服务器上可以分辨球是谁的（`CanStack=false`，不会和别人的球叠在一起）。
  球名由**服务端在生成时写一次**（`setName` + `setCustomName`），客户端脚本只做"语言升级"：
  用 `instanceItem(fullType)` 取干净基础名按本机语言重拼，**与当前名字相同就跳过**（幂等，
  所以 `(用户名)` 不会叠加两次）；
- **每个球是一个"容器"**：容量 = 该技能 **10 级总经验**（普通技能 `32,775`；力量/体格 `487,500`，
  实测引擎在上限处截断 XP）。物品用原版 `ItemType = base:drainable` + `UseDelta = 0.000001`，
  背包里像胶带/电池那样显示**用量条**；
- 用量条语义只有一种：**`球内经验 ÷ 该技能 10 级总经验`**；
  并**保底一格**（`frac >= item:getUseDelta()`）——引擎只在 `uses <= 0` 时把 drainable 判为空
  （名字被加上 `(Empty)`，且**转移时会被销毁**），保底后哪怕只有 0.01 XP 也不会消失、不显示 `(倒空)`；
  > ⚠ 踩坑记录：早期把 `UseDelta` 设成 `0.001`，例 `8/32775` 只占 0.024% → `uses` 四舍五入成 **0**
  > → 球在捡起（客户端按网络包重建物品）时被判为空并销毁。现在粒度足够细 + 保底一格，双保险。
- **吸收按上限截断，余量留在球内**：`room = 容量 − 当前累计XP`，只发放 `min(球内XP, room)`；
  没吸完的球**不消失**，`md.xp` 与用量条同步下降，可以留到下一世/换配置后再吸；
  已经满 10 级时球原样保留并提示。这样"换天赋配置导致初始等级更高"时，超出上限的部分不会被浪费；
- 吸收使用 `addXpNoMultiplier`，**不吃沙盒经验倍率**，球里是多少就发多少；
- **18 种语言**（EN/CN/CH/DE/FR/ES/ES_MX/ES_CL/IT/PT/PTBR/RU/UA/PL/NL/JP/KO/TR），
  其余语言由引擎自动回退到 EN；技能名直接取**官方翻译**，与技能面板术语一致；
- 服务端权威计算与发放（客户端只发命令，防作弊），单机/主机/服务器均可用；
- 不使用任何版权音效/素材；图标为自绘彩色经验球（按技能分类配色 + 内纹区分，开发中）。

## 安装

**单机 / 本地主机（GitHub 版）**

```text
克隆或解压到：  <用户目录>\Zomboid\mods\ExperienceOrb\
目录内应直接看到： mod.info / common / 42.20 / README.md
启动游戏 → 主菜单「模组」→ 启用 "Experience Orb" → 开新档（或存档时在 mod 列表里勾选）
```

> 注意：`mods\ExperienceOrb\` 下面必须是 `mod.info`、`common\`、`42.20\`，不要多套一层
> （例如 `mods\ExperienceOrb\ExperienceOrb\mod.info` 是不行的）。B42 只装载**匹配版本目录**
> （这里是 `42.20\`）里的 `media`，所以内容都在 `42.20\media` 下。

**服务器（建议走创意工坊）**

服务器端与客户端需要同一版本的 mod：客户端订阅创意工坊条目，服务器把该 ID 加进
`WorkshopItems`（面板里的工坊列表），更新后重启。仅把文件塞进服务器是不够的——
死亡上报、球名、翻译都在客户端脚本里。

**开发 / 调试**：`42.20\media\lua\server\ExperienceOrb_Config.lua` 里 `Debug = true`
会在服务器日志打印 `[ExperienceOrb] v<版本> loaded. …`、`baseline captured`、
`skill <技能> src= raw= base= free= freeXp= value=`、`drop … xp=…/… owner=…`、
`use … left=…` 等明细；发布前请改回 `false`。

## 使用方式

1. 角色死亡 → 尸体附近地面出现彩色经验球堆（有真实经验的技能各一颗），
   球名带死亡角色名，方便多人服分辨；
2. 走到球上 **Take**（普通拾取物品，可存包/转交）；
3. 背包里右键该球 → **“吸收经验球(用户名)”** → 头顶提示本地化文本，技能经验上涨；
   若该技能已到 10 级上限，球会保留并提示，余量可留到以后再吸。

> 单人模式死亡即结算（无法继续操作）；完整“死亡→掉球→吸收”请在本地主机
> （Host/本地多人）或服务器上测试。

## 目录结构

```
ExperienceOrb/                        ← 这个目录本身就是 mod 根（mods\ExperienceOrb\）
├─ mod.info                         顶层元数据（含 versionMin/Max 选择器）
├─ poster.png / icon.png
├─ README.md / CHANGELOG.md / .gitignore / LICENSE（待补）
├─ common/mod.info                 通用选择器
├─ tools/                          开发工具（游戏不读取，不影响发布）
│  ├─ gen_translate.ps1            多语言生成/校验（纯 ASCII）
│  ├─ translate_data.json          语言与格式数据（UTF-8 无 BOM）
│  ├─ gen_solid_icons.ps1          重新生成纯色占位图标
│  └─ gen_icons.ps1                旧的"带纹样"图标生成器（历史保留）
├─ 42.20/
│  ├─ mod.info                     版本目录选择器（匹配 42.20.x）
│  ├─ poster.png / icon.png
│  └─ media/                       ★ B42 规范：内容必须放在匹配版本的目录内
│     ├─ scripts/items_XpOrb.txt            35 种经验球物品定义（base:drainable）
│     ├─ textures/ + textures/WorldItems/ + inventory/   ★ 图标三处各一份
│     │                                       （XpOrb_*.png 与 Item_XpOrb_*.png，
│     │                                        兼容原版不同的贴图查找路径）
│     └─ lua/
│        ├─ shared/
│        │  ├─ ExperienceOrb_Perks.lua       技能目录（id 与 Perks.<id> 一致）
│        │  ├─ ExperienceOrb_Math.lua        免费等级/累计经验换算（客户端与服务器共用）
│        │  ├─ ExperienceOrb_MediaTracker.lua 电视/VHS 经验记账
│        │  └─ Translate/<LANG>/             ★ 18 种语言，每种 3 个文件：
│        │     ├─ ItemName.json               "Base.XpOrb_<技能>" 物品名
│        │     ├─ IG_UI.json                  IGUI_* 界面文本（球名标注格式）
│        │     └─ ContextMenu.json            ContextMenu_* 右键菜单文本
│        ├─ server/
│        │  ├─ ExperienceOrb_Config.lua      ★ 配置文件
│        │  └─ ExperienceOrb_Main.lua        死亡结算/掉球/右键吸收/去重
│        └─ client/
│           ├─ ExperienceOrb_Client.lua      死亡上报 + 经验快照（联机关键）
│           ├─ ExperienceOrb_ClientUse.lua   右键“吸收经验球” + 吸收结果本地化提示
│           └─ ExperienceOrb_ClientName.lua  球名语言升级（幂等）
```

> 说明：B42 在存在版本目录时只装载**匹配版本目录内**的 `media`（顶层 `media` 不再生效），
> 所以内容必须放在 `42.20/media` 下，并将 `common/`、`42.20/` 都提供 `mod.info` 选择器。

## 多语言（i18n）

### 目录与文件分组

`42.20/media/lua/shared/Translate/<语言代码>/`，语言代码与原版一致（`media/lua/shared/Translate` 下的文件夹名）。
**键放在哪个文件不是随便放的**：引擎的 `Translator.getTextInternal` 按**键前缀**把查询路由到不同的表，
文件与表一一对应（`tryFillMapFromFile` / `tryFillMapFromMods` 以文件名装载），所以：

| 键前缀 | 文件 | 本 mod 用到的键 |
|---|---|---|
| `Base.<物品全类型>` | `ItemName.json` | `Base.XpOrb_<技能>` × 35 |
| `IGUI_` | `IG_UI.json` | `IGUI_ExperienceOrb_OwnerName`、`_Capacity`、`_Gained`、`_Partial`、`_Capped` |
| `ContextMenu_` | `ContextMenu.json` | `ContextMenu_ExperienceOrb_Use` |
| `Tooltip_` / `UI_` / `Sandbox_` | `Tooltip.json` / `UI.json` / `Sandbox.json` | （本 mod 暂未使用） |

键的用途：`_OwnerName` = 球名里的持有人格式（`%1 (%2)`）；`_Capacity` = 球名里的剩余/容量（`%1/%2`）；
`_Gained` / `_Partial` / `_Capped` = 吸收后的头顶提示（满吸 / 部分吸收 / 已满 10 级）。
头顶提示由**服务端发数值、客户端拼文本**（`Events.OnServerCommand` → `HaloTextHelper`），
所以提示也是玩家自己的语言。

> 早期版本把 `ContextMenu_*`、`IgUI_*` 混写在 `ItemName.json` 里、且前缀大小写不对（`IgUI_` ≠ `IGUI_`），
> 属于不合规写法，已修正。

### 编码约定（关键，写错就会"服务器不认/乱码"）

原版实测：**UTF-8 无 BOM + LF**；Skill Recovery Journal 实测：**UTF-8 无 BOM + CRLF** —— 两者都能正常加载。
本 mod 采用 **UTF-8 无 BOM**（生成器强制）。以下都会出问题：

- **UTF-8 BOM**：JSON 首字节变成 `EF BB BF`，解析失败 → 所有键变成原始文本（玩家看到 `Base.XpOrb_Strength`）；
- **UTF-16 / GBK**：同样解析失败或乱码；
- **Lua 源码里写非 ASCII**：LuaJ 词法分析器直接抛 `ArrayIndexOutOfBoundsException`，整个文件作废（所以本 mod 的
  `.lua` 全部是纯 ASCII，中文只出现在 JSON 里）；
- **PowerShell 脚本里写非 ASCII**：Windows PowerShell 5.1 会用系统 ANSI 代码页读取**无 BOM** 的 `.ps1`
  （实测把中文读成 `缁忛獙鐞?` 并直接语法报错）。因此 `tools/gen_translate.ps1` 保持纯 ASCII，
  文案全部放在 `tools/translate_data.json`（UTF-8 无 BOM，脚本显式用 UTF-8 读取）。

### 生成 / 校验

```powershell
# 自动探测原版安装目录，重建全部 18 种语言并校验
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gen_translate.ps1
# 或显式指定原版目录
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gen_translate.ps1 -VanillaRoot "G:\SteamLibrary\steamapps\common\ProjectZomboid"
```

脚本会：从原版的 `Translate/<LANG>/IG_UI.json` 读取**官方技能名**（`IGUI_perks_*`，缺失按键回退 EN），
套用 `tools/translate_data.json` 里每种语言的格式串生成三个文件，最后校验
（无 BOM、合法 UTF-8、JSON 可解析、35 个键齐全）。

技能 id 与原版键名的三处差异（容易踩坑）：
`PlantScavenging → IGUI_perks_Foraging`、`Lightfoot → IGUI_perks_Lightfooted`、`Sneak → IGUI_perks_Sneaking`。

新增一种语言：在 `tools/translate_data.json` 的 `languages` 里加一行（`item`/`use`/`owner` 三个格式串，
`%1`=官方技能名，`%2`=角色名），重跑生成器即可。

### 球名标注：生成时写一次 + 客户端按语言升级

1. **生成时（服务端）**：掉落瞬间用 `item:setName("<技能球> (<用户名>)")` + `setCustomName(true)` 写一次，
   即使客户端没有运行本 mod 的客户端脚本，球名也是对的；
2. **客户端（可选升级）**：客户端脚本用 `instanceItem(fullType)` 造一个全新实例取**干净的基础名**
   （原版 Lua 不用 `getText("Base.*")` 取物品名，所以不能从物品自身名字推），
   按**本机语言**重新拼一次；**拼出来的名字与当前名字相同就跳过**（幂等），
   所以 `(用户名)` 永远不会被叠加两次——旧版本叠出来的多层名字也会在这一步被覆盖回正确的一层。
   > 踩坑记录：早期实现从"物品当前名字"取基础名，每扫一次就再包一层 → `体格经验球(Shimakaze)(Shimakaze)…`。
   现在基础名只来自"全新实例"或 fullType 字符串，绝不读活动物品的名字。

服务器端调用 `item:setName()` 会把名字**固定成服务器语言的字符串**（专服通常是 EN），
中文客户端就会看到英文球名。所以现在：

- 物品名 = `ItemName.json` 的本地化文本（每名玩家各看各的语言）；
- 角色名由 **客户端** `ExperienceOrb_ClientName.lua` 用 `IGUI_ExperienceOrb_OwnerName` 格式拼上
  （背包内每秒扫一次、右键/查看时立即应用）→ 中文客户端看到 `力量经验球（Shimakaze）`；
- 右键菜单同样的格式，显示 `吸收经验球（Shimakaze）`。

## 配置

编辑 `42.20/media/lua/server/ExperienceOrb_Config.lua`（改完重启生效）：

| 键 | 默认 | 说明 |
|---|---|---|
| `RecoveryRatio` | `1.0` | 恢复比例，`0.01`(1%) ~ `1.0`(100%)，自动钳制 |
| `ExcludeMediaXp` | `true` | 不把电视/VHS 教学经验计入经验球 |
| `ExcludeTraitAndProfessionXp` | `true` | 扣除天赋/职业/被动赠送免费等级（SRJ 算法） |
| `AllowAnyoneToAbsorb` | `false` | `false`=仅本人(SteamID)可吸收；`true`=任何玩家 |
| `EnabledSkillGroups` | 全 `true` | `craft/combat/movement/physical` 四组开关 |
| `DisabledSkills` | `{}` | 额外单独禁用，如 `{ Strength = true }` |
| `DropSpreadRadius` | `1` | 掉落在尸体周围几格内 |
| `Debug` | `true` | 打印 `[ExperienceOrb] …` 明细（**目前为联机排查临时打开**，稳定后请改回 `false`） |
> 其它语言玩家：在 `media/lua/shared/Translate/<语言>/ItemName.json` 补充形如
> `"Base.XpOrb_Woodwork": "…"` 与 `"ContextMenu_ExperienceOrb_Use": "…"` 的条目即可。

## 工作原理（B42 API，均已在本机 42.20.x 验证）

- 原始经验：`player:getXp():getXP(perk)`（累计值，升级不清零）；
- 免费经验（不产生经验球的部分）= **角色出生瞬间的经验快照（baseline）**：
  角色创建时服务端 `Events.OnCreatePlayer` 会把每个技能当时的 XP 存进
  `playerModData.ExperienceOrbBaseline`（压缩字符串，随存档持久化），
  死亡时 `可回收XP = 当前XP − baseline − 媒体XP`，结算后清空，重生后重新记录。
  这样“初始等级”无论是基础等级（力量/体格基础 5 级）、特质加成还是职业加成，
  都会被精确扣除，不依赖任何公式猜测。
  引擎实测曲线（服务器日志 `curve` 行）：
  - 普通技能：`1=75 2=225 3=525 4=1275 5=2775 6=5775 7=10275 8=16275 9=23775 10=32775`
  - 力量/体格：`1=1500 2=4500 3=10500 4=19500 5=37500 6=67500 7=127500 8=217500 9=337500 10=487500`
    （即基础 5 级 = 37,500 XP；例：`Lumberjack` 力量 +1 → 出生 6 级 = 67,500 XP，
    练到 10 级死亡 → 球里是 487,500 − 67,500 = 420,000，正好是 7~10 级的量）
- 没有 baseline 的角色（装 mod 之前就存在的老角色）退回按特质/职业计算：
  被动技能取 `5 + 加成`，其它技能取加成等级，再扣 `perk:getTotalXpForLevel(等级)`。
  游戏数据示例：`Strong = XPBoosts Strength=4`、`Athletic = Fitness=4`、`Weak = Strength=-5`。
- 电视/VHS 记账：包装 `ISRadioInteractions:getInstance().checkPlayer` 做行级 XP 增量差；
- 掉落：`IsoGridSquare:AddWorldInventoryItem("Base.XpOrb_<id>", x, y, 0)`，
  随后写入 `item:getModData()`（`xp` / `ownerSteam` / `char` / `perk`）并用
  `item:setName(label)` + `item:setCustomName(true)` 把角色名写进物品名
  （标签格式取自翻译键 `IgUI_ExperienceOrb_OwnerName`，随客户端语言变化）；
- 吸收（手动）：客户端右键发 `sendClientCommand(player,"ExperienceOrb","useOrb",{itemID=…})`，
  服务端 `Events.OnClientCommand` 校验归属 → 计算 `room = totalXpForLevel(10) − 当前XP` →
  **`addXpNoMultiplier`** 发放 `min(球内XP, room)`（不吃沙盒经验倍率，日志 `noMultiplier=true`）→
  未吸完则写回 `md.xp`、`setUsedDelta(剩余/容量)`、`syncItemFields()` 后保留物品；
  吸完才 `Remove`+`sendRemoveItemFromContainer` → 结果数值回传客户端拼本地化提示；
- 死亡触发（三路，token 去重，同一角色重生后可再次触发）：
  1. 服务器 `Events.OnPlayerDeath`（单机/本地主机直接生效）；
  2. 客户端 `Events.OnPlayerDeath` + `OnTick` 轮询上报 `onPlayerDeath`，并附带
     **经验快照**（`xp`/`media`/`start`/坐标/SteamID）；
  3. 服务器 `OnTick` 轮询 `isDead()` 兜底。
  联机时服务器在玩家死亡瞬间可能已经把该 PlayerObject 替换掉（日志会出现
  `replacing dead player` / `Player with PlayerID ='4' not found!` /
  `receiveClientCommand: player is null`），此时服务端拿不到任何经验数据；
  因此客户端快照是**必需的兜底**：快照在死亡瞬间采集，并在重生后重发数次，
  服务端 token 去重保证只结算一次。
- 全部引擎调用先做方法存在性检查（Kahlua 的 pcall 拦不住“调用不存在方法”的 Java 异常）。
- **Lua 源码必须为纯 ASCII**：LuaJ 词法分析器遇到非 ASCII 字节会在
  `LexState.token2str` 抛 `ArrayIndexOutOfBoundsException`，整个文件作废
  （中文只能写在 JSON 翻译文件里）。

## 兼容性 / 老存档升级

**当前策略：旧球原样保留，只有新爆出的球走新逻辑；旧物品等后续版本再统一清理。**

线上服务器/存档里已经存在的旧经验球**不丢经验、不改类别、不被替换**（实测依据：引擎 `InventoryItem.loadItem`
是按存档里记录的 `ItemType` id 走 `InventoryItemFactory.CreateItem(short)` 建实例，
所以旧球读档后仍是 `base:normal`，不会自己变成 drainable）：

| 旧状态 | 升级后表现 | 处理 |
|---|---|---|
| 类别是旧的 `base:normal` | 仍可捡、可吸、可留余量，只是**没有用量条** | 不替换、不迁移；吸收时就地更新 `md.xp`，用量相关调用全部 pcall 包裹，旧物品类直接忽略 |
| 没有 `md.cap`（容量字段） | 球名照样显示 `剩余/容量` | 服务端按 `totalXpForLevel(perk, 10)` 现算，只在字段缺失时补写；客户端 `OrbLabel` 可从 `md.perk` 推导 |
| `md.ownerSteam` 是科学计数法（`7.656119814527621E16`） | 归属判断 | `SameOwner()` 先按字符串再按数值比较，老球仍认得出主人 |
| 球名被旧版本用**服务器语言** `setName()` 冻结过 | 会显示成英文球名 | 客户端每次扫到球时按本机语言重算并覆盖名字 |
| 技能等级/经验本身 | 不受影响 | `baseline` 机制写在角色 `ModData`；老角色没有 baseline 时退回特质/职业算法 |
| 新爆出的球 | 全部是 `base:drainable` + `md.cap` + 用量条 | 走新逻辑 |

> 后续清理旧球时（1~2 个版本后）再加一次性迁移即可：遍历在线玩家背包与已加载容器里的
> `Base.XpOrb_*` 普通物品 → 用同类型新物品替换并搬运 `ModData`。现在不动。

## 已知限制

- mod **安装之前**已看过的电视/VHS 经验无法追溯剔除；
- 若同时使用会改动经验/技能/音效系统的其它 mod，请自行联调；
- 物品图标为**自绘彩色经验球**：7 大分类配色 + 球心几何纹样区分同分类内的技能（无版权）。

## 图标素材（已实现，无版权）

每颗球 = 分类底色球 + 球心几何纹样（语言无关，同分类内每个技能一个纹样序号）+ 高光。
素材存放在 `42.20/media/textures/WorldItems/XpOrb_<技能>.png`（及 textures 根目录同图一份），
由 `tools/gen_icons.ps1` 生成（改配色/纹样后重跑即可）。

| 分类 | 配色 | 技能 |
|---|---|---|
| 体能 | 橙红 | Fitness 体格、Strength 力量 |
| 战斗-远程 | 紫 | Aiming 瞄准、Reloading 装填 |
| 战斗-近战 | 钢蓝 | Axe 斧头、Blunt 长棍、SmallBlunt 短棍、LongBlade 长刀、SmallBlade 短刀、Spear 长矛、Maintenance 维护 |
| 移动 | 青绿 | Sprinting 冲刺、Lightfoot 轻巧、Nimble 灵活、Sneak 潜行 |
| 求生 | 绿 | Fishing 钓鱼、Trapping 诱捕、PlantScavenging 搜寻、Tracking 追踪、Butchering 屠宰 |
| 农业 | 金黄 | Farming 耕作、Husbandry 畜牧 |
| 合成/生活 | 天青 | Woodwork 木工、Cooking 烹饪、Doctor 急救、Electricity 电工、MetalWelding 金工、Mechanics 技工、Tailoring 缝纫、FlintKnapping 石器、Masonry 石工、Pottery 陶艺、Carving 雕刻、Blacksmith 锻造、Glassmaking 玻璃 |

## 版本与发布

- 版本号出现在三处，**改完一起改**：`mod.info`（顶层 / `42.20/` / `common/` 三份）的 `modversion`、
  `ExperienceOrb_Main.lua` 里的 `ExperienceOrb.Version`（启动横幅会打印）、以及 `CHANGELOG.md`。
- 发布流程：改版本号 → 跑 `tools/gen_translate.ps1` 校验翻译 → 本地启用测试 → 发布创意工坊
  （发布工程目录 `Zomboid\Workshop\ExperienceOrb\Contents\mods\ExperienceOrb\`）→ 服务器更新工坊内容并重启
  → 客户端重启游戏 → 日志确认 `[ExperienceOrb] v<版本> loaded.`。
- 当前版本：**0.6.2**（历史见 `CHANGELOG.md`）。

## 开发者工具（`tools/`）

| 文件 | 用途 |
|---|---|
| `gen_translate.ps1` | 生成并校验 18 种语言的 `Translate/<LANG>/{ItemName,IG_UI,ContextMenu}.json`；技能名从**原版** `IG_UI.json` 的 `IGUI_perks_*` 读取，保证术语一致；强制 UTF-8 无 BOM |
| `translate_data.json` | 语言与格式串数据（`item` / `use` / `owner` / `gained` / `partial` / `capped`），加语言只改这里 |
| `gen_solid_icons.ps1` | 重新生成纯色占位图标（35 技能 × 3 个贴图目录 × 2 种命名） |

> 工具脚本**必须保持纯 ASCII**：Windows PowerShell 5.1 会用系统 ANSI 代码页读取无 BOM 的 `.ps1`，
> 中文会被读坏并直接语法报错；所有文案放在 `translate_data.json`（脚本显式按 UTF-8 读取）。

## 许可

本项目使用 **MIT License**（见 `LICENSE`）：允许自由使用、修改、再分发，只需保留版权声明。
游戏素材（贴图/模型/音效）均未使用任何第三方版权资源；经验球图标为自绘占位图。

> `LICENSE` 里的版权持有人目前写的是 `Shimakaze`，改成你的 GitHub 昵称/真名都可以。
## 测试建议

### 单机/本地主机
1. 本地主机（Host）建新档（沙盒默认，别开高经验倍率）→ 练一点某技能 → 死亡；
2. `console.txt` 看 `[ExperienceOrb] died/skill/drop/use` 明细：`value` =
   (原始XP − 免费等级XP − 媒体XP) × `RecoveryRatio`；没练过的技能不掉球；
3. 重生新角色 → 捡球右键“吸收经验球” → 头顶 `+xxx XP` 与 log 的 `value` 一致。

### 正式服务器（联机）
1. 把本 mod 发布到创意工坊（`C:\Users\<你>\Zomboid\Workshop\ExperienceOrb`），
   服务器面板里把该 ID 加进 `WorkshopItems`，客户端订阅同一 ID；
   > 只改服务器上的文件是不够的：**客户端也跑本 mod 的 client 脚本**（死亡上报/右键吸收），
   > 必须走创意工坊更新，客户端才会拿到新版本。
2. 重启服务器，看服务器日志/控制台应先出现
   `[ExperienceOrb] loaded. ratio=… excludeMedia=… excludeTrait=… debug=…`；
3. 让朋友或僵尸杀死一个“练过技能”的角色（不要用刚创建、什么都没练的角色，
   那样本来就该 0 掉落）；
4. 死亡瞬间服务器日志应出现
   `[ExperienceOrb] died: <SteamID> source=live|payload drops=<N>`
   与 `[ExperienceOrb] <N> orbs dropped for <SteamID>`；
   - `source=payload` 说明走的是客户端快照兜底（正常现象）；
   - 每个技能一行 `skill <技能> src=… raw=… base=… free=… freeXp=… value=…`：
     `raw`=当前累计经验，`base`=出生 baseline（优先），`free`/`freeXp`=无 baseline 时的特质/职业回退值，
     `value`=(raw − base − 媒体经验) × `RecoveryRatio`，可逐项核对；
   - 死亡时还会打印 `baseline: Strength=… Fitness=…`（或 `none (trait fallback)`），
     重生时应能看到 `baseline captured for <SteamID> (<角色名>)`；
   - `Debug=true` 时启动还会输出
     `[ExperienceOrb] curve <技能> totalXpForLevel: 1=… 10=…`，用引擎真实曲线核对扣减；
   - 若出现 `no XP to recover` → 该角色确实没有净经验（天赋/职业/电视经验被排除了）；
   - 若出现 `FAILED to spawn Base.XpOrb_xxx` → 物品脚本没加载，检查
     `42.20/media/scripts/items_XpOrb.txt` 是否在服务器 mod 目录里。
5. 捡球右键“吸收经验球”，头顶出现 `+xxx XP`。
