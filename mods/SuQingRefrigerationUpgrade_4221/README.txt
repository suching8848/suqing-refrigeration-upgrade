蘇清的冷藏升级 v1.0.0-rc.2-perf.8 / B42.22.2 单人 Lua 适配候选

支持 B42.21 和 B42.22.2 单人 Lua 模式，沿用 perf.8 兼容标识、随身装备、冷藏开关和付款记录。B42.22.2 的 Lua 显示合并适用于工坊 CleanUI 2.10.5 的 42.22 分支及已审核的可选库存包装器（批量转移 1.2.4、融合选区 1.0.3、搜索增强 0.1.4-rc.3）。未知包装、Snake Utils 和实际操作继续即时结算。Java 接管后的食品老化沿用原生处理。两版离线回归通过，B42.22.2 游戏内验收待完成。
Supports single-player Lua on B42.21 and B42.22.2. The perf.8 compatibility identifier, equipment, cooling switches and payment records remain valid. On B42.22.2, Lua display coalescing supports the Workshop CleanUI 2.10.5 42.22 branch and its audited optional inventory wrappers (Transfer Performance 1.2.4, Proximity Selection 1.0.3, Search Enhancement 0.1.4-rc.3). Unknown renderers, Snake Utils and actual actions use immediate settlement. Active Java takeover retains native food aging. Offline regression passed on both versions; B42.22.2 gameplay testing is pending.
Mod ID: SuQingRefrigerationUpgrade_4221

Lua模式在大量冷藏食品时CPU开销可能较大，关闭背包后仍可能掉帧；大容量随身食品库存建议搭配独立Java性能补丁SuQingRefrigerationNative_4221。主模组可单独使用，工坊另行分发的 Java 0.1.0-rc.1 适用 B42.21.0，并需要 ZombieBuddy 2.3.4。Java采用原版FridgeFactor/FoodRotSpeed，RotSpeedPercent仅Lua生效。首次正常批准JAR，完整退出重启后启用。
Lua mode can be CPU-heavy with large refrigerated food inventories, including with inventory panels closed. For high-capacity portable food storage, the separate Java companion SuQingRefrigerationNative_4221 is recommended. The base remains standalone; The separately distributed Workshop Java 0.1.0-rc.1 targets B42.21.0 and requires ZombieBuddy 2.3.4. Java uses vanilla FridgeFactor/FoodRotSpeed; RotSpeedPercent is Lua-only. Approve its JAR normally and fully exit/restart.
Java补丁 / Java companion: https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443
用户单人实测确认接管和保存退出；实际FPS增益依场景，未给出受控比例。
User SP testing confirmed activation/save/exit; no controlled FPS percentage is claimed.

perf.7：完整显示快照仅为最近500真实毫秒内显示过的食品维护；后台食品保留弱容器归属，减少年龄、热量和老化时间的重复读取。首次／过期重开显示先严格结算；原生保护、食品数值、取放、开关和保存规则保持。纯Lua优化，无新增Java补丁或依赖；实机帧率仍待验证。
perf.7: Complete display snapshots are maintained only for food displayed within the last500 real milliseconds. Background food keeps weak container ownership, avoiding redundant age/heat/last-aged reads. First/expired display settles strictly. Native protection, food values, transfers, switching and saving are retained. Lua-only optimization; no added Java patch or dependency. In-game FPS remains unverified.

主物品栏：6节电池 + 4电线 + 4电子废料 + 2小金属板。
卸下目标、清空物品、排空液体后，制作→蘇清·冷藏升级→安装。
拆除也在同一制作分类。右键只保留已改造装备的制冷开关。
提示沿用原生与CleanUI，不添加自绘悬浮提示。
永久续航，每件可开关；开关时可穿戴，但须在角色主物品栏。
Lua模式沙盒“蘇清的冷藏升级”：总开关、腐坏速度0-100%，默认20%。
0保持现有新鲜度，不会返鲜；原生冰箱/冷冻与嵌套冷藏不重复叠乘。
拆除需卸下清空排液，返还实付50%，保留电池原电量凭据。
标准可穿戴容器自动识别；特殊过滤器/虚拟仓库可能需额外适配。

Lua模式常温食物约20个游戏分钟逐步降至冷藏温度，保鲜结算保持原规则。
保留rc.1原有冷藏、开关和付款账本，无须重新付费改造。
图标由内置imagegen生成：4类图标，6个游戏PNG资源（含制作分类）。
原生类和离线回归已检查；客户端完整功能与性能待集中验收。
请先用于新建测试档。停用不自动返料，也不删除装备或食物。

perf.1：复用受保护结算函数、固定腐坏倍率查表，减少容器检查的临时表和电池校验调用。
不缓存跨帧制冷结果，不降低逐帧结算频率，不推迟加载前保护扫描。
保留原有腐坏速度、逐步降温、冰箱/冷冻规则、改造记录、开关和返料规则。
离线回归与原生食物接口测试通过不代表已完成客户端性能验收。

perf.3：一分钟容器状态缓存、事件即时清算、必要逐Tick原生保护、纯绘制结算复用与预算发现。
perf.3: One-game-minute container state cache, immediate event settlement, required native Tick protection, display-only reuse and bounded discovery.

perf.4：修正真实Core版本API的42.21格式识别，保留对42.21.0的等价支持；其他未知版本仍停用显示复用。
perf.4: Recognizes the actual Core42.21 version string and its equivalent42.21.0 form; unknown versions still disable display reuse.

perf.5：按原生选择器匹配P4实际分支，并分别校验逻辑记录与原生物理温度快照，修复正常float舍入阻止显示复用的问题。
perf.5: Matches the native-selected P4 branch and validates ledger/native temperature against separate exact snapshots, preventing normal float rounding from blocking display reuse.

perf.6：兼容已审的融合选择修复1.0.1及搜索增强0.1.1绘制包装。等首次正常Tick的延迟安装完成、函数稳定后建立显示上下文；记录实际来源与行号。未知版本、分支或后续替换仍停用复用。食品结算规则不变，实机启用与帧率待验证。
perf.6: Supports the reviewed proximity-selection 1.0.1 and search-enhancement 0.1.1 drawing wrappers. Waits for deferred normal-Tick installation and a stable function before creating the display context; logs its actual source and line. Unknown versions, branches or later replacements disable reuse. Food settlement rules are unchanged; live activation and FPS remain unverified.
