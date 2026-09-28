# 开发与发布

## 目录结构

```
ExperienceOrb/                       ← 这个目录本身就是 mod 根（mods\ExperienceOrb\）
├─ mod.info                          顶层元数据（版本选择器）
├─ poster.png / icon.png
├─ README.md                          用户向简介
├─ CHANGELOG.md / LICENSE / .gitignore / .gitattributes
├─ docs/                              维护者文档（TECHNICAL / I18N / DEVELOPMENT）
├─ common/mod.info                    B42 通用选择器
├─ tools/                             开发工具（游戏不读取，不影响发布）
│  ├─ gen_translate.ps1               多语言生成/校验（纯 ASCII）
│  ├─ translate_data.json             语言与格式数据（UTF-8 无 BOM）
│  ├─ gen_solid_icons.ps1             重新生成纯色占位图标
│  └─ gen_icons.ps1                   旧的"带纹样"图标生成器（历史保留）
└─ 42.20/                             ★ 版本目录：内容必须放在匹配版本目录内
   ├─ mod.info
   ├─ poster.png / icon.png
   └─ media/
      ├─ scripts/items_XpOrb.txt      35 个经验球物品定义（base:drainable）
      ├─ textures/ + textures/WorldItems/ + inventory/
      │                               图标三处各一份（XpOrb_*.png 与 Item_XpOrb_*.png，
      │                               兼容原版不同的贴图查找路径）
      └─ lua/
         ├─ shared/
         │  ├─ ExperienceOrb_Perks.lua       技能目录、球名拼装、归属判定
         │  ├─ ExperienceOrb_Math.lua        经验曲线/免费等级换算（客户端与服务器共用）
         │  ├─ ExperienceOrb_MediaTracker.lua 电视/VHS 经验记账
         │  └─ Translate/<LANG>/             18 种语言 × 3 个文件
         ├─ server/
         │  ├─ ExperienceOrb_Config.lua      ★ 配置
         │  └─ ExperienceOrb_Main.lua        结算/掉球/吸收/去重/兼容
         └─ client/
            ├─ ExperienceOrb_Client.lua      死亡上报 + 经验快照
            ├─ ExperienceOrb_ClientUse.lua   右键吸收 + 本地化提示
            └─ ExperienceOrb_ClientName.lua  球名语言升级（幂等）
```

> B42 在存在版本目录时只装载**匹配版本目录内**的 `media`（顶层 `media` 不再生效），
> 所以内容放在 `42.20/media` 下，并且 `common/`、`42.20/` 都要有 `mod.info` 选择器。

## 开发工具

| 文件 | 用途 |
|---|---|
| `tools/gen_translate.ps1` | 生成并校验多语言文件（细节见 [I18N.md](I18N.md)） |
| `tools/translate_data.json` | 语言与格式串数据，加语言只改这里 |
| `tools/gen_solid_icons.ps1` | 重新生成纯色占位图标（35 技能 × 3 目录 × 2 命名 = 210 个 PNG） |
| `tools/gen_icons.ps1` | 旧的带纹样图标生成器，仅作历史保留 |

> 工具脚本**必须保持纯 ASCII**：Windows PowerShell 5.1 用系统 ANSI 代码页读取无 BOM 的 `.ps1`，
> 中文会被读坏并直接语法报错。

## 版本号与发布流程

版本号出现在三处，**改完要一起改**：

1. `mod.info`（顶层 / `42.20/` / `common/` **三份**）的 `modversion`；
2. `42.20/media/lua/server/ExperienceOrb_Main.lua` 里的 `ExperienceOrb.Version`
   （服务器启动横幅会打印：`[ExperienceOrb] v0.6.2 loaded. …`）；
3. `CHANGELOG.md` 增加对应条目。

发布步骤：

1. 改版本号 → 跑 `tools/gen_translate.ps1` 校验翻译；
2. 本地启用测试（见下）；
3. 发布创意工坊（发布工程目录 `Zomboid\Workshop\ExperienceOrb\Contents\mods\ExperienceOrb\`）；
4. 服务器更新工坊内容并重启，日志确认 `[ExperienceOrb] v<版本> loaded.`；
5. 客户端重启游戏更新工坊内容（否则客户端脚本/翻译还是旧版）。

> 只把文件拷进服务器**不够**：死亡上报、球名、翻译都在客户端脚本里，客户端必须拿到同一版本。

## 调试开关与日志字段

`ExperienceOrb_Config.lua` 里 `Debug = true`（正式服建议 `false`）会输出：

| 日志 | 含义 |
|---|---|
| `baseline captured for <ID> (<账号名>)` | 记录了角色出生快照（重生后应能看到） |
| `baseline: Strength=… Fitness=…` / `none (trait fallback)` | 本次结算用的免费经验来源 |
| `skill <技能> src= raw= base= free= freeXp= value=` | 逐技能明细：`value = (raw − base − 媒体) × RecoveryRatio` |
| `died: <ID> source=live\|payload drops=N` | 是否走的客户端快照兜底（`payload` 是正常现象） |
| `drop Base.XpOrb_x xp=<球内>/<容量> owner=<账号名> steam=<ID>` | 掉球明细 |
| `N orbs dropped for <ID> (<账号名>)` | 本次掉落汇总（**非 Debug 模式也会打印**） |
| `use <技能> xp=<发放> noMultiplier=true left=<剩余>` | 吸收明细 |
| `orb <技能> refused: raw=… cap=…` | 已满 10 级，球原样保留 |
| `curve <技能> totalXpForLevel: 1=… 10=…` | 启动时打印引擎真实经验曲线 |

## 测试清单

**单机 / 本地主机**

1. 新建角色（沙盒默认，别开高经验倍率）→ 练一点某技能 → 死亡；
2. 看日志：`value` 应等于 `(原始XP − baseline − 媒体XP) × RecoveryRatio`；没练过的技能不掉球；
3. 重生 → 捡球 → 右键吸收 → 提示数值应与日志 `use … xp=` 一致。

**专用服务器**

1. 工坊发布 → 服务器 `WorkshopItems` 加 ID → steamcmd 更新 → 重启 → 客户端重启；
2. 日志出现 `[ExperienceOrb] v<版本> loaded.`；
3. 让朋友/僵尸杀死一个练过技能的角色（全新角色本来就该 0 掉落）；
4. 预期：掉球 → **捡起不消失**（背包里有用量条）→ 球名 `<技能球>(<账号名>)` → 右键吸收有本地化提示；
5. 满 10 级时吸收应提示并保留球；余量可在下一世/换配置后继续吸。

## 图标配色表（当前占位图）

图标为自绘纯色球，按技能分类配色；同分类内视觉上不区分（正式美术后续替换）。

| 分类 | 配色 | 技能 |
|---|---|---|
| 体能 | 橙红 | Fitness 体格、Strength 力量 |
| 战斗-远程 | 紫 | Aiming 瞄准、Reloading 装填 |
| 战斗-近战 | 钢蓝 | Axe 斧头、Blunt 长棍、SmallBlunt 短棍、LongBlade 长刀、SmallBlade 短刀、Spear 长矛、Maintenance 维护 |
| 移动 | 青绿 | Sprinting 冲刺、Lightfoot 轻巧、Nimble 灵活、Sneak 潜行 |
| 求生 | 绿 | Fishing 钓鱼、Trapping 诱捕、PlantScavenging 搜寻、Tracking 追踪、Butchering 屠宰 |
| 农业 | 金黄 | Farming 耕作、Husbandry 畜牧 |
| 合成/生活 | 天青 | Woodwork 木工、Cooking 烹饪、Doctor 急救、Electricity 电工、MetalWelding 金工、Mechanics 技工、Tailoring 缝纫、FlintKnapping 石器、Masonry 石工、Pottery 陶艺、Carving 雕刻、Blacksmith 锻造、Glassmaking 玻璃 |

## 本地副本

除 git 仓库外，本机还有两份**发布用**副本（不含 `docs/`、`tools/`、README 等仓库文件）：

| 路径 | 用途 |
|---|---|
| `<用户目录>\Zomboid\mods\ExperienceOrb\` | 单机/主机测试 |
| `<用户目录>\Zomboid\Workshop\ExperienceOrb\Contents\mods\ExperienceOrb\` | 创意工坊发布工程 |

改完代码后把 `42.20/`、`common/`、`mod.info`、`poster.png`、`icon.png` 同步到这两处即可。
