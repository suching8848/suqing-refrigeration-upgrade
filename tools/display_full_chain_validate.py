"""Complete installed local registrar lifecycle in native Kahlua, with controlled UI/event dependencies."""
from pathlib import Path
import argparse,datetime,hashlib,json,os,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--javac',type=Path,required=True)
 p.add_argument('--mods-list',type=Path,required=True);p.add_argument('--output-dir',type=Path,required=True)
 a=p.parse_args();game=a.game_dir.resolve();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=True);classes=out/'classes';classes.mkdir(exist_ok=True)
 roots={
 'P4HasBeenRead':Path(r'D:\steam\steamapps\workshop\content\108600\2544353492\mods\P4HasBeenRead'),
 'CleanUI':Path(r'D:\steam\steamapps\workshop\content\108600\3437629766\mods\CleanUI'),
 'PinyinSearch_SafeSources_4221_LocalFix':Path(r'C:\Users\15792\Zomboid\mods\Pinyin_UI_4221_LocalCompat'),
 'Codex_InventoryTransferPerformance_4221':Path(r'C:\Users\15792\Zomboid\mods\InventoryTransferPerformance_4221_Local'),
 'NeatUI_Equipment':Path(r'D:\steam\steamapps\workshop\content\108600\3790656296\mods\NeatUI_Equipment'),
 'SuQingUIInteractionFixes':Path(r'C:\Users\15792\Zomboid\mods\SuQingUIInteractionFixes'),
 'SuQingSearchEnhancement':Path(r'C:\Users\15792\Zomboid\mods\SuQingSearchEnhancement'),
 'SuQingRefrigerationUpgrade_4221':ROOT/'mods/SuQingRefrigerationUpgrade_4221'}
 mapping=out/'native_roots.tsv';mapping.write_text(''.join(k+'\t'+str(v)+'\n'for k,v in roots.items()),encoding='utf-8')
 search=roots['SuQingSearchEnhancement']/'42/media/lua';cold=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua'
 paths=[mapping,a.mods_list.resolve(),cold/'shared/SuQingRefrigeration/Core.lua',ROOT/'tests/display_full_chain_dependencies.lua',
 search/'shared/SuQingSearch/Core.lua',search/'shared/SuQingSearch/Text.lua',search/'client/SuQingSearch/Settings.lua',search/'client/SuQingSearch/Ordering.lua',
 roots['SuQingUIInteractionFixes']/'42/media/lua/client/SuQing_ProximitySelectionFix.lua',search/'client/SuQingSearch/Runtime.lua',cold/'client/SuQingRefrigeration_Display.lua',ROOT/'tests/display_full_chain_cases.lua']
 before={str(x):sha(x)for x in paths};config=[]
 for display_first in[False,True]:
  for search_first in[False,True]:
   for even_first in[False,True]:
    label='display'+('first'if display_first else'last')+'_'+('searchfirst'if search_first else'proxfirst')+'_'+('evenfirst'if even_first else'normalfirst')
    path=out/(label+'.lua');path.write_text('CHAIN_OPTIONS={label='+json.dumps(label)+',displayFirst='+str(display_first).lower()+',searchFirst='+str(search_first).lower()+',evenFirst='+str(even_first).lower()+',lateHelper=false}\n',encoding='utf-8');config.append(path)
 helper=out/'late_helper.lua';helper.write_text('CHAIN_OPTIONS={label="late_helper",displayFirst=true,searchFirst=false,evenFirst=true,lateHelper=true}\n',encoding='utf-8');config.append(helper)
 commands=[[a.javac,'-encoding','UTF-8','-d',classes,ROOT/'tests/DisplayFullChainNative.java'],
 [game/'jre64/bin/java.exe','--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out/'isolated_java_home'),'-Djava.library.path='+str(game/'win64')+os.pathsep+str(game),'-cp',str(classes)+os.pathsep+str(game)+os.pathsep+str(game/'projectzomboid.jar'),'DisplayFullChainNative',*paths,*config]]
 env=os.environ.copy();home=out/'isolated_java_home';home.mkdir(exist_ok=True);env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'))
 last=''
 for i,command in enumerate(commands):
  r=subprocess.run([str(x)for x in command],cwd=game,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180);last=r.stdout+r.stderr;(out/('step'+str(i)+'.log')).write_text(last,encoding='utf-8')
  if r.returncode:raise RuntimeError(last[-14000:])
 after={str(x):sha(x)for x in paths}
 if before!=after:raise RuntimeError('Sources changed during validation')
 cases=re.findall(r'FULL_CHAIN_CASE (\S+) checks=(\d+) PASS; source=([^;]+); firstline=(\d+); proxline=(\d+); installedFrame=(\d+)',last)
 if len(cases)!=len(config)or'CHAIN_NATIVE_PASS'not in last:raise RuntimeError('Missing complete-chain success evidence')
 report={'result':'PASS','time':datetime.datetime.now().astimezone().isoformat(),'cases':len(cases),'checks':sum(int(x[1])for x in cases),'case_results':[dict(name=x[0],checks=int(x[1]),renderer_source=x[2],renderer_firstline=int(x[3]),proximity_firstline=int(x[4]),installed_frame=int(x[5]))for x in cases],
 'source_sha256':after,'game_started':False,'world_loaded':False,'ui_created':False,'native_core_and_metadata':True,'active_ids_copied_from_saved_list':231,
 'scope':'Complete unchanged installed UIInteraction and Search registrar files plus complete Search Core/Text/Settings/Ordering. Native Kahlua/source/firstline/Core/ModInfo for eight roots and 231 saved IDs; controlled base renderer, ModOptions, zero players and event dispatch timing. No actual game UI, world, render geometry, performance or gameplay acceptance.'}
 (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
