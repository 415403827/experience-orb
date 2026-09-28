# 经验球 Experience Orb

> **Project Zomboid Build 42.20** ｜ 玩家死亡时，把**真正练出来的技能经验**做成经验球掉在尸体旁，捡起来右键吸收即可找回。

一个"技能经验回收"mod：和遗书/技能日志类 mod 思路相近，但只回收**实际练出来的那部分**——
天赋、职业赠送的初始等级，以及电视/VHS 教学经验都会被扣除。

- 仓库：https://github.com/415403827/experience-orb
- 版本：0.6.2（历史见 [CHANGELOG.md](CHANGELOG.md)）
- 许可：[MIT](LICENSE)

## 特性

- **35 项原版技能各一种球**：木工/烹饪/耕作/急救/电工/金工/技工/缝纫/钓鱼/诱捕/搜寻/石器/石工/陶艺/雕刻/畜牧/追踪/锻造/屠宰/玻璃 + 武器/近战 + 移动 + 体格/力量；
- **只回收真实经验**：以角色**出生瞬间的经验**为基准扣除天赋/职业/基础等级，并排除电视/VHS 教学经验；没练过的技能不掉球；
- **球是"容器"**：容量 = 该技能 **10 级总经验**；吸收时只填到上限，**超出部分留在球内**，可留到下一世或换天赋配置后再吸；
- **球名带归属**：`力量经验球(Shimakaze)`，多人服一眼分清是谁的；默认只有本人（同账号）能吸收；
- **18 种语言**：技能名直接取官方翻译（EN/CN/CH/DE/FR/ES/ES_MX/ES_CL/IT/PT/PTBR/RU/UA/PL/NL/JP/KO/TR，其余语言回退 EN）；
- **不吃沙盒经验倍率**：吸收使用 `addXpNoMultiplier`，球里多少就发多少；
- 服务端权威结算，单机 / 本地主机 / 专用服务器通用，联机下死亡时有快照兜底；
- 不使用任何版权音效或素材（图标为自绘占位图）。

## 安装

**单机 / 本地主机**

```
克隆或解压到：  <用户目录>\Zomboid\mods\ExperienceOrb\
目录内应直接看到： mod.info / common / 42.20 / README.md
```

```bash
git clone https://github.com/415403827/experience-orb.git "%USERPROFILE%\Zomboid\mods\ExperienceOrb"
```

启动游戏 → 主菜单「模组」→ 启用 **Experience Orb** → 开新档（或在存档的 mod 列表里勾选）。

> `mods\ExperienceOrb\` 下必须是 `mod.info`、`common\`、`42.20\`，**不要多套一层**
> （`mods\ExperienceOrb\ExperienceOrb\mod.info` 是认不到的）。

**服务器**

建议走创意工坊：客户端订阅条目，服务器把该 ID 加进 `WorkshopItems`（面板的工坊列表），
更新后重启。**只把文件塞进服务器是不够的**——死亡上报、球名、翻译都在客户端脚本里，
客户端也要拿到同一版本。

## 使用

1. 角色死亡 → 尸体附近地面出现该角色有经验的技能球；
2. 走到球上 **Take** 拾取（普通物品，可存包/转交）；
3. 背包里右键 → **“吸收经验球(用户名)”** → 头顶提示本次获得量；经验涨到球内数值；
4. 技能已满 10 级时会提示并**保留球**，余量以后再用。

> 单人模式是"死亡即结算"，看不到重生后捡球的过程；完整的死亡→掉球→吸收请在本地主机
> （Host）或服务器上体验。

## 配置

编辑 `42.20/media/lua/server/ExperienceOrb_Config.lua`（改完**重启**生效）：

| 键 | 默认 | 说明 |
|---|---|---|
| `RecoveryRatio` | `1.0` | 恢复比例，`0.01`(1%) ~ `1.0`(100%)，自动钳制 |
| `ExcludeMediaXp` | `true` | 不把电视/VHS 教学经验计入经验球 |
| `ExcludeTraitAndProfessionXp` | `true` | 扣除天赋/职业/基础等级带来的"免费经验" |
| `AllowAnyoneToAbsorb` | `false` | `false`=仅本人（同 SteamID/账号）可吸收；`true`=任何玩家 |
| `EnabledSkillGroups` | 全 `true` | `craft` / `combat` / `movement` / `physical` 四组开关 |
| `DisabledSkills` | `{}` | 额外单独禁用某些技能，如 `{ Strength = true }` |
| `DropSpreadRadius` | `1` | 掉落在尸体周围几格内 |
| `Debug` | `true` | 服务器日志打印 `[ExperienceOrb] …` 明细（排查用，正式服建议改回 `false`） |

## 已知限制

- mod **安装之前**已经看过的电视/VHS 经验无法追溯剔除；
- 存档里由旧版本生成的球会**保留原样**（可正常捡取/吸收，只是没有用量条）；
- 若同时使用其它会改动经验/技能系统的 mod，请自行联调；
- 图标目前是自绘的纯色占位图（按技能分类配色），后续会替换为正式美术。

## 文档

| 文档 | 内容 |
|---|---|
| [docs/TECHNICAL.md](docs/TECHNICAL.md) | 代码逻辑与引擎 API：出生快照、经验曲线、容量/用量、吸收流程、死亡触发与联机兜底、老存档兼容、踩坑记录 |
| [docs/I18N.md](docs/I18N.md) | 多语言规范：目录与文件分组、编码约定、生成器用法、新增语言步骤 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 目录结构、开发工具、版本号与发布流程、调试日志字段、测试清单、图标配色表 |
| [CHANGELOG.md](CHANGELOG.md) | 版本历史 |

## 许可

**MIT License**（见 [LICENSE](LICENSE)）：允许自由使用、修改、再分发，只需保留版权声明。
本 mod 未使用任何第三方版权素材。
