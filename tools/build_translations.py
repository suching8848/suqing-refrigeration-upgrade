"""Build localized resources and a reproducible test package; no installation."""
from pathlib import Path
import json, hashlib, shutil, zipfile
ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/'mods/SuQingRefrigerationUpgrade_4221'
CN={
 'IGUI_CraftingCategories_SuQingRefrigeration':'蘇清·冷藏升级',
 'IGUI_SQR_install':'安装蘇清冷藏升级',
 'IGUI_SQR_remove':'拆除冷藏升级（返还一半实付材料）',
 'IGUI_SQR_toggle':'切换制冷',
 'IGUI_SQR_switch_on':'开启制冷', 'IGUI_SQR_switch_off':'关闭制冷',
 'IGUI_SQR_installed':'蘇清的冷藏升级：已安装 / 永久续航',
 'IGUI_SQR_on':'制冷中', 'IGUI_SQR_off':'制冷已关闭',
 'IGUI_SQR_global_off':'沙盒总开关已关闭',
 'IGUI_SQR_rate':'冷藏腐坏速度：百分之%1（相对常温）',
 'IGUI_SQR_materials':'需要主物品栏中的非收藏材料：6节电池、4电线、4电子废料、2小金属板。电池按件数消耗，不按电量用量。',
 'IGUI_SQR_main_inventory':'请将目标装备放入角色主物品栏。',
 'IGUI_SQR_equipped':'安装或拆除前，请卸下装备并从双手移开。',
 'IGUI_SQR_not_empty':'安装或拆除前，请清空全部内容物。',
 'IGUI_SQR_fluid':'安装或拆除前，请排空储液组件。',
 'IGUI_SQR_not_wearable':'仅支持有实际储物空间的标准可穿戴装备容器。',
 'IGUI_SQR_food_filter':'该容器的专用过滤规则不允许食物。',
 'IGUI_SQR_custom_filter':'特殊过滤器尚未确认：先放入该容器允许的食物，右键检查一次，再清空并安装。虚拟仓库需要单独适配。',
 'IGUI_SQR_already_installed':'此件已经安装冷藏升级。',
 'IGUI_SQR_not_installed':'此件未安装冷藏升级。',
 'IGUI_SQR_disabled':'沙盒总开关已关闭。',
 'IGUI_SQR_not_ready':'冷藏运行接口尚未准备好；请检查日志并重进测试档。',
 'IGUI_SQR_invalid_record':'冷藏记录异常，已停止本次操作以保留物品和材料。',
 'IGUI_SQR_already_refunded':'此笔材料已经返还，无法重复返料。',
 'IGUI_SQR_invalid_material':'材料电量数据异常，未进行扣料。',
 'IGUI_SQR_multiplayer':'此测试版只支持单人游戏。',
 'IGUI_SQR_failed':'本次操作未完成，请检查前置条件与日志。',
 'IGUI_SQR_busy':'角色正在处理另一笔冷藏改造。',
}
EN={
 'IGUI_CraftingCategories_SuQingRefrigeration':'SuQing Refrigeration',
 'IGUI_SQR_install':'Install SuQing refrigeration',
 'IGUI_SQR_remove':'Remove refrigeration (half of paid materials)',
 'IGUI_SQR_toggle':'Toggle cooling',
 'IGUI_SQR_switch_on':'Enable cooling','IGUI_SQR_switch_off':'Disable cooling',
 'IGUI_SQR_installed':'SuQing refrigeration: installed / unlimited runtime',
 'IGUI_SQR_on':'Cooling enabled','IGUI_SQR_off':'Cooling disabled',
 'IGUI_SQR_global_off':'Disabled by sandbox master switch',
 'IGUI_SQR_rate':'Refrigerated spoilage speed: %1 percent of ambient',
 'IGUI_SQR_materials':'Main inventory: 6 batteries, 4 electric wires, 4 electronics scrap, 2 small metal sheets. Batteries count as objects, not charge uses; favorites are excluded.',
 'IGUI_SQR_main_inventory':'Move the equipment into your main inventory.',
 'IGUI_SQR_equipped':'Unequip and remove from both hands first.',
 'IGUI_SQR_not_empty':'Empty all stored items first.',
 'IGUI_SQR_fluid':'Drain the fluid component first.',
 'IGUI_SQR_not_wearable':'Requires a standard wearable inventory container.',
 'IGUI_SQR_food_filter':'This dedicated container does not accept food.',
 'IGUI_SQR_custom_filter':'Unknown filter: place an accepted food inside, inspect this menu once, then empty and install. Virtual storage needs an adapter.',
 'IGUI_SQR_already_installed':'Refrigeration is already installed.',
 'IGUI_SQR_not_installed':'Refrigeration is not installed.',
 'IGUI_SQR_disabled':'Disabled in sandbox settings.',
 'IGUI_SQR_not_ready':'Cooling hooks are unavailable. Check logs and reload the test save.',
 'IGUI_SQR_invalid_record':'Invalid cooling data; operation blocked to preserve items.',
 'IGUI_SQR_already_refunded':'This payment has already been refunded.',
 'IGUI_SQR_invalid_material':'Invalid battery data; no materials consumed.',
 'IGUI_SQR_multiplayer':'This test version supports single-player only.',
 'IGUI_SQR_failed':'Operation failed. Check prerequisites and logs.',
 'IGUI_SQR_busy':'Another refrigeration transaction is in progress.',
}
for lang,labels in [('CN',CN),('CH',CN),('EN',EN)]:
 d=PKG/'42/media/lua/shared/Translate'/lang; d.mkdir(parents=True,exist_ok=True)
 (d/'IG_UI.json').write_text(json.dumps(labels,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 recipes={'InstallCooling':'安装蘇清冷藏升级' if lang!='EN' else 'Install SuQing refrigeration',
          'RemoveCooling':'拆除冷藏升级并返还一半实付材料' if lang!='EN' else 'Remove refrigeration and recover half of paid materials'}
 (d/'Recipes.json').write_text(json.dumps(recipes,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 sandbox={
  'Sandbox_SuQingRefrigeration':'蘇清的冷藏升级' if lang!='EN' else 'SuQing Refrigeration',
  'Sandbox_SuQingRefrigeration_Enabled':'启用冷藏功能' if lang!='EN' else 'Enable refrigeration',
  'Sandbox_SuQingRefrigeration_Enabled_tooltip':'关闭后保留改造记录；食物按正常环境继续腐坏。' if lang!='EN' else 'Keeps upgrade records while returning food to ordinary aging.',
  'Sandbox_SuQingRefrigeration_RotSpeedPercent':'冷藏腐坏速度（百分比）' if lang!='EN' else 'Refrigerated spoilage speed (percent)',
  'Sandbox_SuQingRefrigeration_RotSpeedPercent_tooltip':'0=保持当前新鲜度；20=常温百分之二十的腐坏速度；100=正常速度。不会返鲜，不与冰箱或冷冻效果重复相乘。' if lang!='EN' else '0 preserves current freshness; 20 is twenty percent of ambient spoilage; 100 is normal. No rejuvenation or multiplicative stacking with fridges or freezers.',
 }
 (d/'Sandbox.json').write_text(json.dumps(sandbox,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Localized resource generation complete; package not installed.')
