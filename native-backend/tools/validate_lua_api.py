"""Real installed ZB exposure + source Lua handover in an isolated test JVM."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,os,re,subprocess,zipfile

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(r'D:\steam\steamapps\common\ProjectZomboid')
JDK=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64')
ZB=Path(r'D:\steam\steamapps\workshop\content\108600\3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')
def digest(p):
    if not p.exists():return None
    s=p.stat();return {'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mtime_ns':s.st_mtime_ns,'size':s.st_size}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path)
    p.add_argument('--candidate',type=Path,default=ROOT.parent/'mods/SuQingRefrigerationNative_4221/42/media/java/client/SuQingRefrigerationNative.jar')
    a=p.parse_args();out=a.output or ROOT/'validation'/('lua_api_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    out.mkdir(parents=True,exist_ok=False);home=out/'isolated_home';home.mkdir();classes=out/'test_classes';classes.mkdir();temp=home/'Temp';temp.mkdir()
    env=dict(os.environ);env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'),TEMP=str(temp),TMP=str(temp))
    env['JAVA_TOOL_OPTIONS']='-Xms64m -Xmx512m -XX:ActiveProcessorCount=2 -XX:+UseSerialGC'
    lua=ROOT.parent/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua'
    files=[ROOT/'src/test/lua/native_api_dependencies.lua',lua/'shared/SuQingRefrigeration/Core.lua',lua/'shared/SuQingRefrigeration/StateCache.lua',lua/'client/SuQingRefrigeration_Native.lua',lua/'client/SuQingRefrigeration_Runtime.lua',ROOT/'src/test/lua/native_api_cases.lua']
    hosts=[ROOT/'src/test/java/OfflineInstrumentation.java',ROOT/'src/test/java/NativeLuaIntegrationTest.java']
    inputs=[a.candidate,ZB,GAME/'projectzomboid.jar',*files,*hosts]
    bound={str(f):digest(f) for f in inputs}
    profile=Path(r'C:\Users\15792\Zomboid')
    protected=[profile/f for f in ['options.ini','latestSave.ini','console.txt','pzopt/options.ini','pzopt/mod-compat.txt','mods/default.txt','Saves/Sandbox/2026-10-09_18-19-22/mods.txt','Saves/Sandbox/2026-10-09_18-19-22/map_sand.bin','mods/SuQingRefrigerationUpgrade_4221/42/media/lua/client/SuQingRefrigeration_Runtime.lua','mods/SuQingFreshnessLunchbox/42/media/lua/shared/SuQingFreshnessLunchbox/Core.lua']]
    protected += [GAME/'ProjectZomboid64.json',GAME/'projectzomboid.jar',ZB]
    before={str(f):digest(f) for f in protected}
    report={'result':'FAIL','game_started':False,'world_created':False,'world_loaded':False,'production_installed':False,'test_only_premain':True,'source_build':False,'protected_before':before,'input_before':bound}
    def run(label,args):
        x=subprocess.run(list(map(str,args)),cwd=GAME,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        log=x.stdout+x.stderr;(out/(label+'.log')).write_text(log,encoding='utf-8')
        if x.returncode:raise RuntimeError(label+' failed: '+log[-9000:])
        return log
    try:
        cp=os.pathsep.join(map(str,[classes,a.candidate,GAME,GAME/'projectzomboid.jar',GAME/'*',ZB]))
        run('compile_existing_agent_and_new_test',[JDK/'bin/javac.exe','--release','25','-encoding','UTF-8','-cp',cp,'-d',classes,*hosts])
        agent=out/'TEST_ONLY_instrumentation.jar'
        with zipfile.ZipFile(agent,'w') as z:
            z.writestr('META-INF/MANIFEST.MF','Manifest-Version: 1.0\r\nPremain-Class: OfflineInstrumentation\r\nCan-Retransform-Classes: true\r\n\r\n')
            z.write(classes/'OfflineInstrumentation.class','OfflineInstrumentation.class')
        log=run('actual_zb_exposure_and_lua_handover',[GAME/'jre64/bin/java.exe','--enable-native-access=ALL-UNNAMED','-Xverify:all','-Duser.home='+str(home),'-Djava.io.tmpdir='+str(temp),'-javaagent:'+str(agent),'-cp',cp,'NativeLuaIntegrationTest',*files])
        m=re.search(r'NATIVE_LUA_API assertions=(\d+) PASS',log)
        if not m:raise RuntimeError('Missing complete actual API handover summary')
        report.update(result='PASS',assertions=int(m[1]),classpath_order=cp,jvm_verifier=True,real_zb_exposer=True,actual_static_function_type_and_identity=True,real_production_bootstrap=True,real_food_settle=True,real_lua_shutdown=True,
            scope='Installed ZB Exposer.exposeClass and real candidate API/Instrumentation/Food plus complete source Lua bridge. Controlled event bus, zero players, no World/Cell/UI/save loading. Manual test exposure does not prove normal mod discovery or user approval; test-only premain is not a product launch method.')
    except Exception as e:report['error']=str(e);raise
    finally:
        report['protected_after']={str(f):digest(f) for f in protected};report['protected_unchanged']=before==report['protected_after']
        report['input_after']={str(f):digest(f) for f in inputs};report['inputs_unchanged']=bound==report['input_after']
        if not report['protected_unchanged'] or not report['inputs_unchanged']:report['result']='FAIL'
        report['checked_utc']=datetime.now(timezone.utc).isoformat();(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items() if not k.startswith('protected_') and not k.startswith('input_')},ensure_ascii=False))
    if report['result']!='PASS':raise RuntimeError('Actual Lua API test did not pass with stable protected inputs')
if __name__=='__main__':main()
