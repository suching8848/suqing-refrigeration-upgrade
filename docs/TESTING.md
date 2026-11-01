# 测试与维护 / Testing and maintenance

中文：本次Git整理只复制并核对开发包，不进行游戏验收。`python tools/validate.py`验证Mod ID/版本、全部25个源包文件哈希、JSON及PNG导出；它不启动游戏。`python tools/run_tests.py --game-dir <游戏目录> --javac <编译器>`在本机游戏Kahlua执行受控引擎fixture与真实原生配方解析；`--native-food`另运行Food原生类探针。测试输出保留在忽略的validation目录；不会读取正式存档、安装模组或改启用名单。

English: This Git preparation copies and hashes the development package without in-game acceptance. `python tools/validate.py` checks identity/version, all 25 source-package hashes, JSON and PNG exports without starting the game. `python tools/run_tests.py --game-dir <game directory> --javac <compiler>` runs controlled-engine Kahlua fixtures and the actual native recipe parser using the local game. `--native-food` additionally runs a native Food probe. Outputs go to ignored validation storage; no personal save, installed mod or enabled list is read or changed.

## 游戏验收 / In-game acceptance

1. 原生制作只出现安装/拆除两项；右键只对已改造目标显示制冷开关。 / Native crafting exposes install/remove; right-click offers the cooling switch only for upgraded equipment.
2. 正常扣6电池/4电线/4废料/2小金属板；拆除返3/2/2/1，电池不刷满。取消不扣料。 / Pay 6 batteries/4 wires/4 scrap/2 small sheets; recover 3/2/2/1 without refilling batteries. Cancellation does not charge.
3. 普通及超级容量、减重和原ModData保留。 / Ordinary/super capacity, reduction and other ModData remain.
4. 温度渐变约20游戏分钟；关闭后回温；沙盒0/20/100与冰箱/冷冻不叠乘。 / Roughly 20-game-minute cooling transition, native warming when off, sandbox 0/20/100 and no fridge/freezer multiplication.
5. 验证保存重进、容器转移、地图卸载、车内、换位/尺寸转换、暂停/睡觉/加速。 / Check save/reload, transfers, world unloading, vehicles, position/size conversions, pause/sleep/fast-forward.

`tools/build_translations.py`重建已有中英翻译；运行前检查diff。`tools/package_release.py --output <zip>`只打包仓库中的mods，拒绝覆盖既有zip。旧私人部署、读档审计、沙盒修改、备份与恢复脚本不纳入公开仓库。

`tools/build_translations.py` rebuilds existing Chinese/English translations; review its diff. `tools/package_release.py --output <zip>` packages repository mods only and refuses to overwrite a ZIP. Old personal deployment, save auditing, sandbox mutation, backup and recovery scripts are excluded.
