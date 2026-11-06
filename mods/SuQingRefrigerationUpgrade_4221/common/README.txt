蘇清的冷藏升级 / SuQing Refrigeration Upgrades 1.0.0-rc.2-perf.8

Lua模式在大量冷藏食品时CPU开销可能较大，关闭背包后仍可能掉帧；大容量随身食品库存建议搭配独立Java性能补丁SuQingRefrigerationNative_4221。主模组可单独使用，补丁另需ZombieBuddy2.3.4，限B42.21.0单人。Java采用原版FridgeFactor/FoodRotSpeed，RotSpeedPercent仅Lua生效。首次正常批准JAR，完整退出重启后启用。
Lua mode can be CPU-heavy with large refrigerated food inventories, including with inventory panels closed. For high-capacity portable food storage, the separate Java companion SuQingRefrigerationNative_4221 is recommended. The base remains standalone; the patch additionally requires ZombieBuddy2.3.4 and B42.21.0 single-player. Java uses vanilla FridgeFactor/FoodRotSpeed; RotSpeedPercent is Lua-only. Approve its JAR normally and fully exit/restart.
Java补丁 / Java companion: https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443

用户单人测试确认Java接管和正常保存退出，没有受控FPS提升比例。可选Lua显示合并精确审核到搜索增强0.1.1；0.1.2会保守停用显示功能，Java接管不依赖它。
User SP testing confirms native takeover and save/exit, without a controlled FPS claim. Optional display coalescing is audited for Search Enhancement0.1.1;0.1.2 disables that feature conservatively. Native takeover is independent.
