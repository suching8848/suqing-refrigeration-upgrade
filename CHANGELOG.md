# 更新记录 / Changelog

## 1.0.0-rc.2-perf.1

中文：复用受保护食物结算函数和固定腐坏倍率查表，减少临时对象与普通容器检查。没有跨帧制冷结果缓存，没有降低结算频率或推迟加载前保护。ModData、保鲜、温度、制作和返料规则保持。历史离线记录覆盖原版/候选各44场景、507断言及真实Food.updateAge；模拟负载结果不代表实机涨帧，客户端性能仍待验收。

English: Reuses protected food-settlement functions and fixed spoilage-rate lookup to reduce temporary objects and ordinary-container work. No cross-frame cooling-result cache, reduced settlement frequency or delayed pre-load protection. ModData, freshness, temperature, crafting and refunds are retained. Historical offline records cover 44 cases/507 assertions for baseline and candidate plus native Food.updateAge. Simulated improvements are not measured FPS gains; client performance remains pending.

## 1.0.0-rc.2

中文：新增原生制作分类及安装/拆除配方；右键只保留制冷开关，去掉自绘物品悬浮提示。按件消耗6电池/4电线/4电子废料/2小金属板，避免重复扣料；渐变降温约20游戏分钟。修复翻译裸百分号，保留rc.1改造、开关、电池凭据及其他容器数据。

English: Added native crafting category and install/remove recipes. Right-click retains only the cooling switch; custom item tooltips were removed. Consumes 6 batteries/4 wires/4 scrap/2 small metal sheets by object count without duplicate payment. Cooling transitions take roughly 20 game minutes. Fixed bare percent signs in translations; retained rc.1 upgrades, switches, battery evidence and other container data.
