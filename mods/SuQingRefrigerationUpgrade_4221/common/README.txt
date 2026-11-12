蘇清的冷藏升级 / SuQing Refrigeration Upgrades 1.0.0-rc.2-perf.8

支持 B42.21 和 B42.22.2 单人 Lua 模式，沿用 perf.8 兼容标识、随身装备、冷藏开关和付款记录。B42.22.2 的 Lua 显示合并适用于工坊 CleanUI 2.10.5 的 42.22 分支及已审核的可选库存包装器（批量转移 1.2.4、融合选区 1.0.3、搜索增强 0.1.4-rc.3）。未知包装、Snake Utils 和实际操作继续即时结算。Java 接管后的食品老化沿用原生处理。两版离线回归通过，B42.22.2 游戏内验收待完成。
Supports single-player Lua on B42.21 and B42.22.2. The perf.8 compatibility identifier, equipment, cooling switches and payment records remain valid. On B42.22.2, Lua display coalescing supports the Workshop CleanUI 2.10.5 42.22 branch and its audited optional inventory wrappers (Transfer Performance 1.2.4, Proximity Selection 1.0.3, Search Enhancement 0.1.4-rc.3). Unknown renderers, Snake Utils and actual actions use immediate settlement. Active Java takeover retains native food aging. Offline regression passed on both versions; B42.22.2 gameplay testing is pending.

Lua模式在大量冷藏食品时CPU开销可能较大，关闭背包后仍可能掉帧；大容量随身食品库存建议搭配独立Java性能补丁SuQingRefrigerationNative_4221。主模组可单独使用，工坊另行分发的 Java 0.1.0-rc.1 适用 B42.21.0，并需要 ZombieBuddy 2.3.4。Java采用原版FridgeFactor/FoodRotSpeed，RotSpeedPercent仅Lua生效。首次正常批准JAR，完整退出重启后启用。
Lua mode can be CPU-heavy with large refrigerated food inventories, including with inventory panels closed. For high-capacity portable food storage, the separate Java companion SuQingRefrigerationNative_4221 is recommended. The base remains standalone; The separately distributed Workshop Java 0.1.0-rc.1 targets B42.21.0 and requires ZombieBuddy 2.3.4. Java uses vanilla FridgeFactor/FoodRotSpeed; RotSpeedPercent is Lua-only. Approve its JAR normally and fully exit/restart.
Java补丁 / Java companion: https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443

B42.21.0 的历史实测确认 Java 接管和保存退出。B42.21 的显示合并沿用既有渲染链审核范围。
Historical B42.21.0 testing confirmed native takeover and save/exit. On B42.21, display coalescing keeps its original audited renderer coverage.
