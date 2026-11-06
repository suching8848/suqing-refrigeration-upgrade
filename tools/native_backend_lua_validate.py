"""Lua bridge lifecycle only, using the existing pure Kahlua host; no game/world."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,os,re,subprocess

ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,default=Path(r'D:\steam\steamapps\common\ProjectZomboid'))
    p.add_argument('--javac',type=Path,default=Path(r'E:\code\java-1.8.0-openjdk-1.8.0.392-1.b08.redhat.windows.x86_64\bin\javac.exe'))
    p.add_argument('--output',type=Path)
    p.add_argument('--legacy-regression',action='store_true')
    a=p.parse_args();game=a.game.resolve()
    out=a.output or ROOT/'validation'/('native_bridge_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    out.mkdir(parents=True,exist_ok=True);classes=out/'classes';classes.mkdir(exist_ok=True);home=out/'isolated_home';home.mkdir(exist_ok=True)
    lua=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua'
    files=[ROOT/'tests/mock_bootstrap.lua',ROOT/'tests/native_backend_bootstrap.lua',lua/'shared/SuQingRefrigeration/Core.lua',lua/'shared/SuQingRefrigeration/StateCache.lua',lua/'client/SuQingRefrigeration_Native.lua',lua/'client/SuQingRefrigeration_Runtime.lua',ROOT/'tests/native_backend_cases.lua']
    inputs=[*files,ROOT/'tests/KahluaValidation.java',game/'projectzomboid.jar']
    if a.legacy_regression:
        inputs += [ROOT/'tests/NativeCoolingProbe.java',ROOT/'tests/native_bootstrap.lua',ROOT/'tests/native_cases.lua',ROOT/'tests/mock_cases.lua',ROOT/'tests/crafting_cases.lua',lua/'client/SuQingRefrigeration_Display.lua',lua/'client/SuQingRefrigeration_UI.lua',lua/'shared/SuQingRefrigeration/Recipes.lua',lua/'client/SuQingRefrigeration_Crafting.lua']
    before={str(f):sha(f) for f in inputs}
    env=dict(os.environ);env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'))
    env['JAVA_TOOL_OPTIONS']='-Xms32m -Xmx256m -XX:ActiveProcessorCount=2 -XX:+UseSerialGC'
    report={'result':'FAIL','game_started':False,'world_created':False,'world_loaded':False,'java_patch_started':False,'output':str(out),'input_sha256':before,'scope':'Complete source Lua modules and controlled API/Food/ownership callbacks in existing standalone Kahlua host; no native API integration or FPS claim.'}
    def run(label,cmd):
        x=subprocess.run(list(map(str,cmd)),cwd=game,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=40)
        s=x.stdout+x.stderr;(out/(label+'.log')).write_text(s,encoding='utf-8')
        if x.returncode:raise RuntimeError(s[-9000:])
        return s
    try:
        run('compile_existing_host',[a.javac,'-encoding','UTF-8','-d',classes,ROOT/'tests/KahluaValidation.java'])
        cp=os.pathsep.join(map(str,(classes,game,game/'projectzomboid.jar',game/'*')))
        log=run('kahlua_lifecycle',[game/'jre64/bin/java.exe','--enable-native-access=ALL-UNNAMED','-Duser.home='+str(home),'-cp',cp,'KahluaValidation',*files])
        m=re.search(r'NATIVE_BRIDGE_SUMMARY cases=(\d+) assertions=(\d+) PASS',log)
        if not m:raise RuntimeError('Missing complete lifecycle summary')
        report.update(cases=int(m[1]),assertions=int(m[2]),inputs_unchanged=all(sha(Path(f))==h for f,h in before.items()))
        if not report['inputs_unchanged']:raise RuntimeError('Inputs changed during lifecycle run')
        if a.legacy_regression:
            run('compile_existing_native_host',[a.javac,'-encoding','UTF-8','-d',classes,ROOT/'tests/NativeCoolingProbe.java'])
            common=[lua/'shared/SuQingRefrigeration/Core.lua',lua/'shared/SuQingRefrigeration/StateCache.lua',lua/'client/SuQingRefrigeration_Native.lua',lua/'client/SuQingRefrigeration_Runtime.lua']
            old=[ROOT/'tests/mock_bootstrap.lua',*common,lua/'client/SuQingRefrigeration_Display.lua',lua/'client/SuQingRefrigeration_UI.lua',lua/'shared/SuQingRefrigeration/Recipes.lua',lua/'client/SuQingRefrigeration_Crafting.lua',ROOT/'tests/mock_cases.lua',ROOT/'tests/crafting_cases.lua']
            run('legacy_all_mock_with_absent_api',[game/'jre64/bin/java.exe','--enable-native-access=ALL-UNNAMED','-Duser.home='+str(home),'-cp',cp,'KahluaValidation',*old])
            run('legacy_native_food_with_absent_api',[game/'jre64/bin/java.exe','--enable-native-access=ALL-UNNAMED','-Duser.home='+str(home),'-cp',cp,'NativeCoolingProbe',ROOT/'tests/native_bootstrap.lua',*common,ROOT/'tests/native_cases.lua'])
            report['legacy_regression']={'result':'PASS','mock_and_crafting':True,'native_food':True,'new_native_module_loaded':True,'api_absent':True,'native_methods_initialized_without_world':True}
        report['inputs_unchanged']=all(sha(Path(f))==h for f,h in before.items())
        if not report['inputs_unchanged']:raise RuntimeError('Inputs changed during regression run')
        report['result']='PASS'
    except Exception as e:
        report['result']='FAIL'
        report['error']=str(e)
        raise
    finally:
        report['checked_utc']=datetime.now(timezone.utc).isoformat()
        (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
