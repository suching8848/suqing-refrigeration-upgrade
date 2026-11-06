# 可选原生冷藏接管 / Optional native refrigeration backend

发布候选：`SuQingRefrigerationNative_4221` **0.1.0-rc.1**，配套主模组 **1.0.0-rc.2-perf.8**。已完成源码、离线原生/Kahlua验证和用户单人激活、正常保存退出测试；用户报告明显改善。当前按用户授权准备独立公开工坊发布，没有同负载受控FPS百分比、长时或联机验收。主模组仍可独立运行Lua。

Release candidate: version0.1.0-rc.1 with baseperf.8. Source/offline and user SP activation/save/exit checks passed, with a subjective improvement. Prepared for an independently authorized public Workshop release; no controlled FPS percentage, long-term or multiplayer acceptance is claimed. The base remains independently usable in Lua mode.

Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443

## 适用范围 / Supported scope

- 仅 **Project Zomboid B42.21.0 单人**，配套 **ZombieBuddy 2.3.4**。不声明联机、服务器、其他游戏或加载器版本兼容。
- `mod.info` 使用 `require=SuQingRefrigerationUpgrade_4221,ZombieBuddy`、`zbVersionMin=2.3.4` 与 `zbVersionMax=2.3.4`。当前实际ZB解析器包含上下限检查；其unknown开发版本有特殊放行，因此元数据之外仍有独立精确版本、JAR SHA和目标Food字节码门禁。
- 沿用主模组已有付费改造、装备开关、ItemID和保存schema，不新增物品、配方或美术；可选补丁不附封面、poster或icon，不自动启用。

- **Project Zomboid B42.21.0 single-player only**, paired with **ZombieBuddy2.3.4**. Multiplayer, servers and other game/loader versions are outside this declaration.
- `mod.info` requires the base and ZombieBuddy, with both ZB bounds set to2.3.4. The installed ZB parser checks both bounds but specially allows its unknown development version, so bootstrap independently verifies the exact version, JAR SHA and target Food bytecode.
- Existing paid upgrades, switches, ItemIDs and save schema remain. No items, recipes or artwork are added; the optional companion has no cover/poster/icon and is never enabled automatically.

## 行为与接管 / Behavior and handover

原生模式使用游戏的 `FridgeFactor`、`FoodRotSpeed` 与食品调度处理年龄、温度和冻融。总开关继续生效；自定义 `RotSpeedPercent` 只在Lua模式生效。Lua模式保留原有自定义封顶与约20游戏分钟的降温路径；原生模式不承诺相同温度过渡时长。目标是移除Lua每Tick全食品循环，不以微基准代替加载世界的性能测试。

主模组的Lua桥接只在OnGameStart、旧Runtime已ready并扫描玩家后请求bootstrap。bootstrap只安装并保持inactive；旧Lua FlushAll成功后才activate，并确认isActive后停止旧食品循环。Native Tick与暂停回调只检查健康、总开关和全局history/lastSeen，不遍历食品；转移、整包与开关仍按实际受影响子树即时清算，保存调用flushKnown。Food保存入口写回旧schema1检查点（当前age、lastAged时间、当前heat），全局历史记录原版倍率，以供无Java重启后的Lua路径衔接。完整游戏读档/序列化仍需用户实测。

Native mode uses the game's `FridgeFactor`, `FoodRotSpeed` and food scheduler for aging, temperature and freezing/thawing. The master switch remains effective; custom `RotSpeedPercent` applies only in Lua mode. Lua retains its custom cap and roughly20-game-minute cooling path; native mode does not promise the same temperature-transition duration. The goal is to remove the Lua full-food Tick loop, without treating a microbenchmark as a loaded-world performance test.

Lua requests bootstrap only during OnGameStart, after the legacy Runtime is ready and has scanned players. Bootstrap installs inactive; legacy FlushAll must succeed before activation, and isActive must confirm ownership before the old loop stops. Native Tick/paused callbacks only check health, the master switch and global history/lastSeen. Transfers, whole-bag moves and switches settle the affected subtree immediately; saving calls flushKnown. The Food save hook writes a legacy schema1 checkpoint using current age, lastAged time and heat; global history uses vanilla factors for a later Lua-only restart. Normal user game loading/save/exit is evidenced; complete item-level serialization acceptance remains separate.

## ZB私有ABI与批准 / Private ABI and approval

补丁通过ZB正常发现、批准和装载流程进入。Main本身不安装/激活接管；Lua握手才请求安装。不添加 `-javaagent`、JVM参数或其他启动参数，也不绕过ZombieBuddy批准。代码只读反射取得 `Loader.g_instrumentation`，不写该字段。这个句柄是ZB **私有ABI**，不是稳定的公开扩展接口。

当前审核绑定ZombieBuddy2.3.4，JAR SHA-256：

`eb79b9876332010733a8e0d7ce4fe0377846059a9e28859029e2a0fb449f6cf2`

还会核对候选来源/JAR哈希、API/主版本、Food类和逐方法指纹，拒绝不匹配而非猜测兼容。启动前不匹配保留Lua；运行中失效仅在确认原生已停用后重建Lua登记并要求正常重启，不能确认停用则隔离报错，避免两条账本同时运行。不得视为无缝热卸载。

The companion follows normal ZB discovery, approval and loading. Main does not install or activate it; the Lua handshake requests installation. It adds no `-javaagent`, JVM or other launch arguments and bypasses no ZombieBuddy approval. It reflectively reads `Loader.g_instrumentation` without writing that field. This is a **private ZB ABI**, not a stable public extension interface.

The audited loader is ZombieBuddy2.3.4 with the JAR SHA-256 above. Bootstrap also checks candidate origin/JAR hash, API/base version, Food class and per-method fingerprints. A pre-activation mismatch retains Lua. A later failure rebuilds Lua ownership only after confirmed native deactivation and requires a normal restart; unconfirmed deactivation isolates and reports an error, avoiding two concurrent ledgers. Seamless hot-unloading is unsupported.

## 源码与离线验证 / Source and offline validation

- `src/main/java`：生产接管源码；`src/test/java`：离线测试host与TEST_ONLY instrumentation入口。
- `tools/build.py`：仅在SOURCE的可选补丁目录生成候选JAR与构建收据，不安装。
- `tools/validate_integration.py`：隔离JVM里运行真实Instrumentation/字节码校验和Food方法；测试专用premain不属于产品启动方式。
- `../tools/native_backend_lua_validate.py`：既有Kahlua host中的Lua生命周期/失败边界与无API回退回归。

- `src/main/java` contains production sources; `src/test/java` contains offline hosts and TEST_ONLY instrumentation.
- `tools/build.py` creates the candidate JAR and build receipt only inside SOURCE; it does not install it.
- `tools/validate_integration.py` verifies real Instrumentation/bytecode and Food methods in isolated JVMs. Its test-only premain is not a product launch method.
- `../tools/native_backend_lua_validate.py` tests Lua lifecycle/failure boundaries and API-absent fallback in the existing standalone Kahlua host.

离线方法验证、Lua mock、实际ZB暴露与完整游戏启动是不同层级，最终交付以具体回执为准；不能用其中一项冒充另一项。当前已有用户实际启动、接管和正常保存退出证据；逐食品完整读回、长期性能、受控FPS和联机仍未验证。新增、更换、禁用或移除Java补丁必须完整退出并重启游戏，不在运行中替换JAR。发布与Git回执以本轮release记录为准；不会因发布改动玩家名单。

Offline methods, Lua mocks, actual ZB exposure and full game startup are separate evidence levels, recorded in their specific receipts. None substitutes for another. User startup, activation and normal save/exit are evidenced; item-level readback, sustained performance, controlled FPS and multiplayer remain unverified. Fully exit and restart before adding, replacing, disabling or removing the Java companion; never replace its JAR while running. Publication/Git results are recorded in the release receipts; publishing does not alter player enabled lists.

## 本机验证收据 / Local validation receipts (2026-11-07)

- Lua生命周期 **22场景／122断言**，含激活后ClearLegacy失败的停用重建与重建失败隔离，以及加载新模块但无Java API时的旧mock/crafting/原生Food回归：`D:/steam/steamapps/common/ProjectZomboid/CodexAssets/CoolingNativeBackend_20261107_0500/lua_lifecycle_perf8_final/report.json`。
- 实际ZB Exposer、13静态方法type/身份、生产bootstrap、Lua交接、原生Food结算/checkpoint与退出 **317断言**：`D:/steam/steamapps/common/ProjectZomboid/CodexAssets/CoolingNativeBackend_20261107_0500/actual_lua_api_first/report.json`。带JVM字节码校验，受保护运行文件和输入首尾哈希/时间保持；使用测试专用premain及手动class暴露，不证明正常发现/批准流程或游戏内运行。
- 餐盒精确perf.1–8门禁（每版本17场景／666断言，未知9初装/漂移拒绝）与完整三模组离线组合：同审计目录下 `lunchbox_validation/gates-validation.json`、`lunchbox_validation/combination-validation.json`。

The receipts above bind the specific tested source/JAR hashes. The22-case/122-assertion Lua suite includes post-activation cleanup failure and API-absent legacy regressions. The317-assertion run uses actual ZB exposure and real native methods with JVM verification, while controlled dependencies still exclude a world/player/UI and normal loader discovery/approval acceptance. Lunchbox gates and full offline combinations are recorded separately. Later source changes require matching validation receipts.
