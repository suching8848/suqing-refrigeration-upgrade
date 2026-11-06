蘇清的冷藏性能补丁 / SuQing's Refrigeration Performance Patch
Version: 0.1.0-rc.1 | Mod ID: SuQingRefrigerationNative_4221
Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443

中文
用于蘇清的冷藏升级的大容量随身食品库存。需要冷藏主模组1.0.0-rc.2-perf.8和ZombieBuddy2.3.4，仅支持B42.21.0单人。
顺序：ZombieBuddy → 冷藏升级 → 返鲜餐盒（若使用）→ 本补丁。首次按ZB原有提示批准JAR。
由原生食品调度接管老化、冷藏温度及冻融，停止主模组Lua逐Tick全食品扫描。使用原版FridgeFactor/FoodRotSpeed；自定义RotSpeedPercent只在Lua模式生效。现有装备、食品、改造费用、付费记录和开关保留。
主模组仍可独立运行Lua；本补丁不新增物品，无封面、poster或icon，不把餐盒列为必需依赖。
安装、更换、禁用或移除本补丁必须完整退出并重启游戏，不能在运行中替换JAR。加载器或游戏版本不符合精确门禁时会拒绝接管并保留Lua路径，需等适配更新。
实现读取ZombieBuddy的私有Instrumentation字段，不修改游戏JAR，也不关闭ZB批准机制。仅审核2.3.4及当前匹配JAR；这是版本绑定的兼容方式。
用户单人测试已确认接管和正常保存退出，并报告体感提升；没有受控FPS净增比例或联机验收。实际效果取决于食品量、地点及其他模组。
源码native-backend/README.md保留构建和验证方法。

English
For large portable food inventories using SuQing's Refrigeration Upgrades. Requires base1.0.0-rc.2-perf.8 and ZombieBuddy2.3.4; B42.21.0 single-player only.
Order: ZombieBuddy → Refrigeration Upgrades → Freshness Lunchbox (if used) → this patch. Approve its JAR through the normal ZB prompt.
Native food scheduling owns aging, cold temperature and freezing/thawing, replacing the base Lua full-food Tick sweep. Uses vanilla FridgeFactor/FoodRotSpeed; custom RotSpeedPercent remains Lua-only. Existing equipment, food, upgrade costs, payment records and switches remain.
The base still works independently in Lua mode. No new items, cover, poster or icon; Lunchbox is optional.
Fully exit and restart after installation, replacement, disabling or removal. Do not replace a running JAR. Exact game/loader gates reject unsupported versions and retain Lua until adapted.
Reads a private ZombieBuddy instrumentation field without modifying the game JAR or disabling approval. Audited for2.3.4 and its matching JAR, not a stable cross-version API.
User single-player testing confirmed activation and normal save/exit with a subjective improvement. No controlled FPS percentage or multiplayer acceptance is claimed; results depend on food load, location and other mods. native-backend/README.md retains build/validation instructions.
