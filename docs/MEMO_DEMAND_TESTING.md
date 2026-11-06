# 按需显示快照验证 / On-demand display memo validation

在仓库目录运行 `python tools/memo_demand_validate.py`。工具直接读取当前源码，执行16个显示订阅／失效／占位清理场景、13个原有Runtime不变量场景及2个真实NativeFood方法场景。输出在 `validation/memo_demand_<UTC>/report.json`，同时保留逐步日志与被测输入哈希。

Run `python tools/memo_demand_validate.py` from the repository. It reads current source and checks 16 display-interest/invalidation/placeholder cases, 13 preceding Runtime invariant cases, and two real NativeFood method scenarios. Results, logs, and tested input hashes are saved under `validation/memo_demand_<UTC>/`.

可用 `--game PATH`、`--javac PATH` 指定现有游戏与Java编译器；`--expected-runtime-sha256 HASH` 绑定待交付代码；`--reference-log PATH` 可与冻结的 `MEMO_VECTOR` 日志逐食品比较Age/Heat/LastAged。默认不依赖审计目录。

Use `--game PATH` and `--javac PATH` to select existing installations, `--expected-runtime-sha256 HASH` to bind release acceptance to reviewed code, and optionally `--reference-log PATH` for exact item-by-item Age/Heat/LastAged comparison with a frozen `MEMO_VECTOR` log. The default run needs no external audit directory.

这里只复用仓库已有KahluaValidation和NativeCoolingProbe离线测试类，不制作Java补丁、不启动游戏、不创建World/Cell、不读存档或部署。571食品负载的调用计数使用可信plain mock；原生场景验证真实float/double、首显严格调用和后续命中。帧率与世界／UI验收由用户游戏内完成。

Only the repository's existing KahluaValidation and NativeCoolingProbe test harnesses are used. No Java patch, game startup, World/Cell creation, save access, or deployment is performed. The 571-food operation counts use trusted plain mocks; native scenarios check real float/double behavior, strict first display, and subsequent reuse. FPS and world/UI acceptance remain user in-game checks.

perf.7采用依据的配对方法微基准保存在 `D:\steam\steamapps\common\ProjectZomboid\CodexAssets\CoolingLuaPerf7_20261107_0405\native_paired_v2\20261106T202059_741483Z`。该实验使用perf.6 Core及新Runtime，正式perf.7的Core只改变版本字符串。它复用单个真实Food，不能换算成571个独立原生食品的Tick时间或FPS；本工具不重复运行该计时。

The paired method benchmark supporting perf.7 is archived at `D:\steam\steamapps\common\ProjectZomboid\CodexAssets\CoolingLuaPerf7_20261107_0405\native_paired_v2\20261106T202059_741483Z`. It used the perf.6 Core with the new Runtime; the formal perf.7 Core changes only the version string. Its one reused native Food cannot predict a Tick over 571 distinct native objects or FPS. This validation tool does not repeat that timing experiment.
