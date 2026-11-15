蘇清的冷藏升级 / SuQing Refrigeration Upgrades 1.0.0-rc.2-perf.8

B42.22.2 单人 Lua 适配候选，保留 B42.21 加载范围。保留现有随身装备、冷藏开关及付款记录。B42.22.2 使用 Lua 逐次结算，物品栏显示合并沿用已审 B42.21 渲染链的门禁。独立 Java 0.1.0-rc.2 候选已离线验证 B42.21.0 和原版 B42.22.2。本次保留 perf.8 兼容标识与既有退出重进候选，游戏内验收待完成。
Single-player Lua compatibility candidate for B42.22.2 with B42.21 loading retained. Existing equipment, cooling switches and payment records use the same data. B42.22.2 settles display updates immediately under the existing render-chain guard. The optional Java 0.1.0-rc.2 candidate has passed offline verification on B42.21.0 and stock B42.22.2. This candidate carries forward the existing re-entry fix and perf.8 compatibility identifier. Gameplay validation is pending.

Lua模式在大量冷藏食品时CPU开销可能较大，关闭背包后仍可能掉帧；大容量随身食品库存建议搭配独立Java性能补丁SuQingRefrigerationNative_4221。主模组可单独使用，Java 候选 0.1.0-rc.2 另需 ZombieBuddy 2.3.4，适用 B42.21.0 和原版 B42.22.2 单人。Java采用原版FridgeFactor/FoodRotSpeed，RotSpeedPercent仅Lua生效。首次正常批准JAR，完整退出重启后启用。
Lua mode can be CPU-heavy with large refrigerated food inventories, including with inventory panels closed. For high-capacity portable food storage, the separate Java companion SuQingRefrigerationNative_4221 is recommended. The base remains standalone; Java candidate 0.1.0-rc.2 additionally requires ZombieBuddy 2.3.4 for B42.21.0 and stock B42.22.2 single-player. Java uses vanilla FridgeFactor/FoodRotSpeed; RotSpeedPercent is Lua-only. Approve its JAR normally and fully exit/restart.
Java补丁 / Java companion: https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443

B42.21.0 的历史实测确认 Java 接管和保存退出，B42.22.2 候选的游戏内验收待完成。可选Lua显示合并精确审核到搜索增强0.1.1；0.1.2会保守停用显示功能，Java接管不依赖它。
Historical B42.21.0 testing confirmed native takeover and save/exit. In-game acceptance of the B42.22.2 candidate is pending. Optional display coalescing is audited for Search Enhancement0.1.1;0.1.2 disables that feature conservatively. Native takeover is independent.
