# 冷藏四项发布记录 / Cooling release record

记录时间 / Recorded: 2026-11-07T06:54:55.694107+08:00。这是该时点状态，不替代后续在线读回。 / Point-in-time state; later online readback takes precedence.

| 项目 / Item | 版本 / Version | Workshop | 状态 / State |
| --- | --- | --- | --- |
| 冷藏升级 / Refrigeration Upgrades | `1.0.0-rc.2-perf.8` | [3832223788](https://steamcommunity.com/sharedfiles/filedetails/?id=3832223788) | 已公开核对 / Verified public |
| 冷藏性能补丁 / Refrigeration Performance Patch | `0.1.0-rc.1` | [3834960443](https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443) | 已上传，等待Steam自动内容检测；仍隐藏 / Uploaded; Steam automated content review pending; still hidden |
| 返鲜餐盒 / Freshness Lunchbox | `0.1.0-rc.8-perf.8` | [3834693433](https://steamcommunity.com/sharedfiles/filedetails/?id=3834693433) | 已公开核对 / Verified public |
| 返鲜冰箱 / Freshness Fridge | `0.1.0-rc.2-perf.1` | [3834692923](https://steamcommunity.com/sharedfiles/filedetails/?id=3834692923) | 已公开核对 / Verified public |

三个现有条目保持公开并已更新。新Java补丁独立上传，完整内容、无图要求和两项依赖已核对，但公开提交返回AccessDenied(15)；用户提供的作者页面同时显示等待自动内容检测。两项事实分别记录，不将失败提交写成公开成功。无需重复建条目、重传或补封面。检测完成后仍需设为公开并读回确认。

The three existing items stayed public and were updated. The separate new Java companion has verified content, no artwork and exactly two dependencies. Its public-visibility submit returned AccessDenied(15); the owner-page screenshot also shows pending automated content analysis. These facts are recorded separately, and the failed visibility submit is not represented as successful publication. Do not recreate the item, reupload content or add substitute artwork. Set it public after review and verify the live result.

Java补丁依赖冷藏主模组perf.8和ZombieBuddy2.3.4；餐盒可选。主模组仍可独立运行Lua模式，中英README、模组介绍和工坊说明均已提示大量Food的CPU开销并推荐Java性能补丁。Java采用原版FridgeFactor/FoodRotSpeed，自定义RotSpeedPercent仅Lua生效。

The Java companion requires the baseperf.8 and ZombieBuddy2.3.4; Lunchbox is optional. The base remains independently usable in Lua mode. Bilingual README/mod/Workshop descriptions explain the many-Food CPU cost and recommend the optional companion. Native mode uses vanilla FridgeFactor/FoodRotSpeed; custom RotSpeedPercent is Lua-only.

用户已进行本轮单人测试并报告改善；06:26会话日志确认Native激活、保存退出，返鲜冰箱容量警告仅初始化两次和保存一次，稳定运行期间为0。没有受控FPS增幅；完整保存后重进、特殊自动化、长期及联机仍按各项目边界验收。当前搜索增强0.1.2使可选Lua显示合并安全停用，Java接管不依赖该显示功能。

User single-player testing and subjective improvement are recorded. The06:26 session confirms Native activation and normal save/exit; Fridge capacity warnings occur twice at initialization and once on saving, with none during stable gameplay. No controlled FPS percentage is claimed. Complete reload, special automation, long-term and multiplayer behavior retain their stated validation boundaries. Search Enhancement0.1.2 safely disables optional Lua display coalescing; native takeover is independent.

本次发布未更改个人运行文件、存档、配置、加载器批准或两份启用名单及顺序。冻结包中11个执行文件与用户实测安装逐字一致；Java补丁仅JAR、mod.info和README三文件，无封面、poster或icon。

Publication did not change the personal runtime, save, configuration, loader approval or either enabled list/order. The frozen eleven executable files match the user-tested installation byte-for-byte. The Java package contains only its JAR,mod.info and README: no cover,poster or icon.

详细内容哈希、实际SDK回调与逐项读回路径见[cooling-release-20261107.json](cooling-release-20261107.json)。SDK验证不等于远端逐文件下载核验，也不替代游戏实测。

See the JSON record for content hashes, actual SDK callbacks and per-item readback paths. SDK verification is not a remote per-file download and does not replace gameplay acceptance.
