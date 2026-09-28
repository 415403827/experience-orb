# Changelog

版本号同时出现在两处，改完记得一起改：

- `mod.info`（顶层 / `42.20/` / `common/` 三份）里的 `modversion`
- `42.20/media/lua/server/ExperienceOrb_Main.lua` 里的 `ExperienceOrb.Version`
  （服务器日志启动横幅会打印它：`[ExperienceOrb] v0.6.2 loaded. ...`）

## 0.6.2

- 球名改为**生成时由服务端写一次**（`setName` + `setCustomName`），不依赖客户端参与；
  客户端脚本只做"语言升级"：用 `instanceItem(fullType)` 取干净基础名，按本机语言重拼，
  与当前名字相同则跳过（幂等）。
- 球名格式确定为 `<技能经验球>(<用户名>)`，不再附带容量数字。
- 归属标识去掉 `user:` 前缀，日志字段拆分为 `owner=` / `steam=`。

## 0.6.1

- 修复球名被反复追加 `(用户名)` 的问题：基础名不再从"活动物品的当前名字"推导
  （原版 Lua 也不用 `getText("Base.*")` 取物品名），改为 `instanceItem` 取全新实例的
  显示名并缓存；已叠名的旧球会自动被覆盖回一层。

## 0.6.0

- 新增版本标记 `ExperienceOrb.Version`，启动横幅打印，便于确认服务器实际加载的构建。
- **经验球容量机制**：物品改为 `ItemType = base:drainable` + `UseDelta`，
  用量条 = `球内经验 / 该技能 10 级总经验`；吸收时 `room = 容量 − 当前累计XP`，
  只发放 `min(球内XP, room)`，**超出上限的部分留在球内**，用于换天赋配置后继续回收。
- 用量**保底一格**（`frac >= item:getUseDelta()`）：引擎只在 `uses <= 0` 时把 drainable
  判为空（名字加 `(Empty)` 并在转移时销毁），保底后任何比例都不会消失。
- 旧球（旧版本存档里的 `base:normal` 物品）**保留不迁移**，吸收时就地更新 `md.xp`，
  只是没有用量条；等后续版本再统一清理。
- 多语言体系重做：18 种语言 × 3 个分组文件（`ItemName.json` / `IG_UI.json` /
  `ContextMenu.json`），键按原版前缀归位，UTF-8 无 BOM，技能名取官方翻译。
- 吸收提示改为服务端回传数值、客户端拼文本，跟随玩家语言。

## 早期版本（未编号，逐步修正）

- 死亡结算改为以**出生瞬间的经验快照（baseline）**为免费部分：`当前XP − baseline − 媒体XP`，
  精确扣除基础等级 / 特质 / 职业加成；老角色退回"被动技能 5 + 加成"的特质算法。
- 联机可靠性：客户端死亡时上报经验快照（`xp` / `media` / `start` / 坐标 / SteamID / token），
  服务端在玩家对象已被替换（`receiveClientCommand: player is null`）时仍能结算；
  服务端 `OnTick` 轮询与 `Events.OnPlayerDeath` 双通道 + token 去重。
- 电视/VHS 经验排除（包装 `ISRadioInteractions.checkPlayer` 逐行记账）。
- 吸收使用 `addXpNoMultiplier`，不吃沙盒经验倍率。
- 全部 `.lua` 保持纯 ASCII（LuaJ 词法分析器遇非 ASCII 会抛
  `ArrayIndexOutOfBoundsException`，导致整个文件失效）。
