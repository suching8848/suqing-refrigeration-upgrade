# 冷藏原生接管初次离线交付记录 / Initial native refrigeration offline delivery

> 历史阶段快照：下文“尚未安装／提交／发布”等状态记录初次离线交付时点。此后已完成单人部署和用户实测；当前安装与发布状态见[中文说明](../README.md)、[英文说明](../README.en.md)及[本轮发布记录](cooling-release-20261107.md)。
> Historical stage snapshot: statements below such as “not installed/committed/published” describe the initial offline delivery. Single-player deployment and user testing were completed later. Use the linked READMEs and current release record for the later state.

2026-11-07，北京时间。已完成源码、构建、双语依赖说明及离线回归；尚未安装、启用、游戏内验收、提交或发布。

Source, build, bilingual dependency documentation and offline regression are complete. Installation, enablement, in-game acceptance, commit and publication have not been performed.

## 交付范围 / Delivery

| 项目 / Component | 候选版本 / Source candidate | 当前个人环境 / Personal runtime |
| --- | --- | --- |
| SuQingRefrigerationUpgrade_4221 | 1.0.0-rc.2-perf.8 | 1.0.0-rc.2-perf.7 |
| SuQingRefrigerationNative_4221 | 0.1.0-rc.1 | 未安装 / Not installed |
| SuQingFreshnessLunchbox | 0.1.0-rc.8-perf.8，精确适配冷藏1–8 / exact cooling perf.1–8 gates | 0.1.0-rc.8-perf.7 |

Java补丁为原主模组的独立可选后端，不新增物品、配方或存档schema。仅对当前B42.21.0单人、ZombieBuddy2.3.4审核；依赖原主模组perf.8和ZombieBuddy。主模组缺少补丁仍可独立运行Lua功能。源码位于 `E:\code\suqing-refrigeration-upgrade`，餐盒源码位于 `D:\steam\steamapps\common\ProjectZomboid\CodexRepos\suqing-freshness-lunchbox`。

The independent optional Java backend depends on the original base perf.8 and ZombieBuddy. It adds no items, recipes or save schema. The reviewed scope is B42.21.0 single-player with ZombieBuddy2.3.4; the base remains usable on its own in Lua mode. The two source repositories are listed above.

## 实现与验证 / Implementation and validation

只改写已核对Food方法里的环境查询调用点及保存入口；保留原生年龄公式、FridgeFactor、FoodRotSpeed、降温、冻融和腐坏处理顺序。实际容器类型、归属、容量、重量、付费升级与开关记录保持。Lua旧账本先完成严格清算，确认Java接管后才移除逐Tick全食品循环。转移、开关和保存按边界清算；总开关关闭时仍只有一个后端拥有结算权。

Only reviewed Food environment-query callsites and the save entry change. Native aging formulas, temperature/freezing behavior and rotting order remain. Real container identity, ownership, capacity, weight and paid records remain. Legacy Lua must flush before confirmed native activation ends the full-food Tick sweep. Transfers, switches and saving settle at boundaries; ownership stays exclusive with the master switch off.

使用原版FridgeFactor/FoodRotSpeed。自定义RotSpeedPercent仅Lua后端生效。按容器缓存资格，未知旁路状态写入最多延迟1游戏分钟；正常受支持转移/开关立即失效。使用ZB私有Instrumentation字段的只读反射，绑定精确版本与JAR哈希，保留加载器批准；生产不新增agent或启动参数。详见 [后端说明](../native-backend/README.md) 和 [独立审查](../native-backend/docs/review-20261107.md)。

Native mode uses vanilla FridgeFactor/FoodRotSpeed; custom RotSpeedPercent is Lua-only. Container qualification is cached for at most one game minute for unknown bypass writes, with immediate invalidation at supported boundaries. Read-only access to a private ZB instrumentation field is version/hash-bound and retains loader approval; production adds no agent or launch arguments. See the linked backend guide and review.

- 真实JVM重转换、字节码校验、原生Food/冰箱对照：225条断言；缺句柄/初次冲突/后续冲突另13条通过。
- 实际ZB Exposer→Java API→Lua握手、健康/保存/停用：317条断言通过。
- Lua生命周期22场景、122条断言通过，旧完整无API回退回归通过。
- 资格策略31条、真实原生容器/缓存/检查点45条通过；餐盒版本门禁和组合回归通过。
- 所有测试均无World Cell、玩家、UI、读档或游戏主循环，正式配置/名单/日志及目标JAR受保护文件保持；不据此推断FPS。

The real-JVM integration passed225 assertions plus13 failure-path assertions; actual ZB exposure/API/Lua integration passed317; Lua lifecycle passed22 scenarios/122 assertions and legacy API-absent regression. Eligibility31 and native container/cache/checkpoint45 assertions passed, along with lunchbox gates/combined regression. These are isolated method-level tests without a World Cell, player, UI, save loading or game loop. Protected live files stayed unchanged. No FPS claim is made.

具体回执路径集中于 [离线证据](../native-backend/docs/offline-evidence.json)。候选JAR SHA-256：`331720f30d01861480922374165fe81f711c5f3f4598641010f31b46293cffd8`。测试专用premain没有进入产品JAR。

Report paths are collected in the offline evidence file. The candidate JAR hash is above; test-only premain code is excluded from the product JAR.

## 后续用户验收 / Subsequent user acceptance

后续安装需配套更新主模组与餐盒，再按加载器正常批准流程加载独立Java补丁；本次没有安装，也没有改两份启用名单。更换、禁用或移除Java补丁必须完整退出并重启游戏。目标Food方法由其他模组后置改写的组合仍需实际加载验证，不能保证捕获所有后置transform。

A later installation must pair the base/lunchbox update and use normal loader approval for the independent Java companion. This task has not installed or changed either enabled list. Fully exit and restart before replacing, disabling or removing Java. Combinations with later Food transformers still require actual loading verification; all post-transform changes cannot be detected.

由用户测试：确认日志接管成功；相同位置及物品量分别开背包约50秒、关背包约50秒、暂停约30秒；测试单件/整包转移、开关、冷藏包落地、原生冰箱/冰柜、保存并完整退出重进。用同场景日志判断Lua全扫是否消失及实际FPS，不把不同地点或减少食品后的变化当作版本收益。完整Food序列化、存档重进、世界调度及长期性能仍待验收。

User acceptance should confirm successful takeover in logs, then sample roughly50 seconds with inventory open,50 closed and30 paused at the same position/item count. Check single-item/whole-bag transfers, switches, a dropped cold bag, vanilla fridge/freezer and save/full-exit/reload. Use matched logs to assess the removed Lua sweep and FPS. Full item serialization, save reload, world scheduling and sustained performance remain unverified.
