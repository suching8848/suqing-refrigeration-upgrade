# 更新记录 / Changelog

## 1.0.0-rc.2-perf.8 / Native companion0.1.0-rc.1 — 2026-11-07

中文：配套独立Java冷藏性能补丁，原生调度接管后停止Lua逐Tick全食品扫描。主模组说明明确大量食品CPU开销，建议大容量库存搭配补丁；Java可选，需原主模组和ZombieBuddy2.3.4。沿用物品、费用、付款记录及schema；Java采用原版FridgeFactor/FoodRotSpeed，RotSpeedPercent仅Lua生效。真实单人日志及用户反馈确认接管和正常退出，不宣称受控FPS比例。搜索增强0.1.2仍保守停用可选Lua显示合并；没有放宽未审核门禁。Java补丁独立工坊条目，不附封面、poster或icon。

English: independent optional Java performance companion stops the Lua full-food Tick sweep after native handover. Documents CPU cost with many foods and recommends the companion for large inventories. Requires the original base and ZombieBuddy2.3.4; items, costs, records and schema remain. Java uses vanilla factors; RotSpeedPercent stays Lua-only. User SP logs/feedback confirm takeover and normal exit without a controlled FPS percentage. Search Enhancement0.1.2 still disables optional display coalescing conservatively. The companion is a separate Workshop item without cover/poster/icon.

## 1.0.0-rc.2-perf.7

中文：完整显示memo仅为最近500ms显示过的食品采集，后台保留弱归属供发现检查，减少三次getter／食品／Tick。首显严格结算，继续检查外部编辑与原生float快照；原生保护、数值、取放和保存不变。纯Lua优化，实机FPS待验证。

English: Collects complete display memos only for food displayed within500ms. Background food retains weak ownership for discovery, avoiding three getters per food per Tick. First display settles strictly; external-edit and native-float checks remain. Native protection, values, transfers and saving are retained. Lua-only; measured FPS is pending.

## 1.0.0-rc.2-perf.6

中文：支持已审融合选择1.0.1及搜索增强0.1.1的真实分支绘制包装；等首次正常Tick延迟包装完成、入口稳定后安装显示上下文，并记录来源及行号。未知版本及后续替换保留严格结算。食品机制和数值不变；实机启用与FPS待验证。

English: Supports the selected-branch render wrappers from proximity selection1.0.1 and search enhancement0.1.1. Installs the display context after deferred normal-Tick wrapping and a stable entry, logging its actual source and line. Unknown versions or later replacements retain strict settlement. Food mechanics and values are unchanged; live activation/FPS remain pending.

## 1.0.0-rc.2-perf.5

中文：精确匹配原生选中的P4 3.8.1／42.15分支；分开校验逻辑与物理温度快照，正常float舍入不再阻止显示复用，外部微小修改仍走严格入口。

English: Precisely matches the native-selected P4 3.8.1/42.15 branch and validates ledger/physical temperature snapshots separately. Normal float rounding no longer blocks display reuse; tiny external edits remain strict.

## 1.0.0-rc.2-perf.4

中文：按真实Core版本API兼容42.21与42.21.0，修复显示合并误停用；保留未知版本拒绝与原查询错误。缓存和食品结算逻辑不变。

English: Accepts the actual Core42.21 string and equivalent42.21.0, fixing display reuse being disabled. Unknown versions and original query errors remain visible. Cache and food settlement are unchanged.

## 1.0.0-rc.2-perf.3

中文：按容器缓存一分钟冷藏状态，事件即时失效与逐件清算；Tick保留原生老化／冻结／腐坏保护，但共享本批配置与积分。已审阅物品栏绘制复用未变化的本Tick结算（500ms上限），未知包装器回退。发现扫描按32项／约1ms分帧，保存强制清算并报告失败。原ID、记录、数值、材料和付款凭据保持；联机和实机FPS仍由对应验收确认。

English: Adds one-game-minute container state caching with immediate event invalidation and per-item settlement. Tick retains native aging/freezing/spoilage protection while sharing batch configuration and integration. Audited inventory drawing reuses unchanged same-Tick results within500ms; unknown wrappers fall back. Discovery is bounded to32 entries/about1ms per frame; save settlement reports failures. IDs, records, values, materials and payments remain. Multiplayer and measured FPS require their own acceptance.

## 1.0.0-rc.2-perf.1

中文：复用受保护食物结算函数和固定腐坏倍率查表，减少临时对象与普通容器检查。没有跨帧制冷结果缓存，没有降低结算频率或推迟加载前保护。ModData、保鲜、温度、制作和返料规则保持。历史离线记录覆盖原版/候选各44场景、507断言及真实Food.updateAge；模拟负载结果不代表实机涨帧，客户端性能仍待验收。

English: Reuses protected food-settlement functions and fixed spoilage-rate lookup to reduce temporary objects and ordinary-container work. No cross-frame cooling-result cache, reduced settlement frequency or delayed pre-load protection. ModData, freshness, temperature, crafting and refunds are retained. Historical offline records cover 44 cases/507 assertions for baseline and candidate plus native Food.updateAge. Simulated improvements are not measured FPS gains; client performance remains pending.

## 1.0.0-rc.2

中文：新增原生制作分类及安装/拆除配方；右键只保留制冷开关，去掉自绘物品悬浮提示。按件消耗6电池/4电线/4电子废料/2小金属板，避免重复扣料；渐变降温约20游戏分钟。修复翻译裸百分号，保留rc.1改造、开关、电池凭据及其他容器数据。

English: Added native crafting category and install/remove recipes. Right-click retains only the cooling switch; custom item tooltips were removed. Consumes 6 batteries/4 wires/4 scrap/2 small metal sheets by object count without duplicate payment. Cooling transitions take roughly 20 game minutes. Fixed bare percent signs in translations; retained rc.1 upgrades, switches, battery evidence and other container data.
