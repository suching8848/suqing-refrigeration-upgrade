"""Verify the candidate in isolated JVMs; never run a game main or create a Cell."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, os, re, shutil, subprocess, zipfile

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(r'D:\steam\steamapps\common\ProjectZomboid')
JDK=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64')
ZB=Path(r'D:\steam\steamapps\workshop\content\108600\3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')

def digest(path):
    if not path.exists():return None
    return {'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'mtime_ns':path.stat().st_mtime_ns,'size':path.stat().st_size}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path)
    p.add_argument('--candidate',type=Path)
    p.add_argument('--game-jar',type=Path,default=GAME/'projectzomboid.jar')
    p.add_argument('--zombie-buddy',type=Path,default=ZB)
    p.add_argument('--native-agent',type=Path,default=GAME/'zbNative.dll')
    p.add_argument('--historical-checkpoint',type=Path)
    p.add_argument('--provenance-tests',action='store_true',help='Exercise 42.22.2 whole-JAR and mixed-code-source refusal')
    a=p.parse_args()
    out=a.output or ROOT/'validation'/('native_integration_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    out=out.resolve()
    out.mkdir(parents=True,exist_ok=False);home=out/'isolated_home';home.mkdir();classes=out/'test_classes';classes.mkdir()
    buddy=out/'ZombieBuddy.jar'
    shutil.copyfile(a.zombie_buddy,buddy)
    shutil.copyfile(GAME/'stdlib.lua',out/'stdlib.lua')
    env=dict(os.environ);env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'),TEMP=str(home/'Temp'),TMP=str(home/'Temp'))
    (home/'Temp').mkdir();env['JAVA_TOOL_OPTIONS']='-Xms64m -Xmx512m -XX:ActiveProcessorCount=2 -XX:+UseSerialGC'
    profile=Path(r'C:\Users\15792\Zomboid')
    protected=[profile/f for f in ['options.ini','latestSave.ini','console.txt','pzopt/options.ini','pzopt/mod-compat.txt','mods/default.txt','Saves/Sandbox/2026-10-09_18-19-22/mods.txt','Saves/Sandbox/2026-10-09_18-19-22/map_sand.bin']]
    protected+=[GAME/'ProjectZomboid64.json',GAME/'projectzomboid.jar',a.game_jar,a.zombie_buddy,a.native_agent,
        profile/'mods/SuQingRefrigerationNative_4221/42/media/java/client/SuQingRefrigerationNative.jar',
        profile/'mods/SuQingRefrigerationNative_4221/42/mod.info',
        profile/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua/client/SuQingRefrigeration_Native.lua']
    before={str(f):digest(f)for f in protected}
    report={'result':'FAIL','game_started':False,'world_created':False,'production_installed':False,'real_zombie_buddy_agent':True,'test_only_premain_for_rejection_cases':True,'source_build':False,'protected_before':before}
    def run(label,args):
        result=subprocess.run(list(map(str,args)),cwd=out,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        log=result.stdout+result.stderr;(out/(label+'.log')).write_text(log,encoding='utf-8')
        if result.returncode:raise RuntimeError(label+' failed: '+log[-7000:])
        return log
    try:
        jar=a.candidate.resolve() if a.candidate else out/'SuQingRefrigerationNative.jar'
        if not a.candidate:
            run('build',[os.sys.executable,ROOT/'tools/build.py','--zombie-buddy',a.zombie_buddy,'--output',jar])
            report['source_build']=True
        game_jar=a.game_jar.resolve()
        cp=os.pathsep.join(map(str,[classes,jar,game_jar,buddy]))
        tests=[ROOT/'src/test/java'/f for f in ['OfflineInstrumentation.java','NativeIntegrationTest.java','NativeFailureTest.java']]
        run('compile_tests',[JDK/'bin/javac.exe','--release','25','-encoding','UTF-8','-cp',cp,'-d',classes,*tests])
        agent=out/'TEST_ONLY_instrumentation.jar'
        with zipfile.ZipFile(agent,'w')as z:
            z.writestr('META-INF/MANIFEST.MF','Manifest-Version: 1.0\r\nPremain-Class: OfflineInstrumentation\r\nCan-Retransform-Classes: true\r\n\r\n')
            z.write(classes/'OfflineInstrumentation.class','OfflineInstrumentation.class')
        java=[GAME/'jre64/bin/java.exe','--enable-native-access=ALL-UNNAMED','-Xverify:all',
              '-Duser.home='+str(home),'-Djava.io.tmpdir='+str(home/'Temp')]
        checkpoint=out/'food-checkpoint.bin'
        legacy=[a.historical_checkpoint.resolve()] if a.historical_checkpoint else []
        log=run('native_execution',[*java,'-agentpath:'+str(a.native_agent.resolve()),'-cp',cp,
                                    'NativeIntegrationTest',checkpoint,*legacy])
        if '[ZB] Agent installed.' not in log:
            raise RuntimeError('Actual ZombieBuddy did not report installation')
        binary=re.search(r'FOOD_BINARY worldVersion=(\d+) historicalRead=(\w+)',log)
        if not binary:raise RuntimeError('Missing native Food binary readback evidence')
        match=re.search(r'NATIVE_INTEGRATION assertions=(\d+) PASS',log)
        if not match:raise RuntimeError('Missing complete native integration summary')
        report.update(assertions=int(match[1]),candidate=digest(jar),jvm_verifier=True,real_retransform=True,checkpoint_table_roundtrip=True,
            full_item_serialization=True,world_version=int(binary[1]),historical_read=binary[2],checkpoint=digest(checkpoint),
            game_jar=digest(game_jar),zombie_buddy=digest(buddy),native_agent=digest(a.native_agent),
            scope='Actual ZombieBuddy and real native Food/Instrumentation and item serialization on isolated fixtures. No game, world, player, UI or save loading.')
        failures={}
        for mode in ['unknown-build','missing-handle','initial-conflict','later-conflict']:
            agentarg='-javaagent:'+str(agent)+('=no-handle'if mode=='missing-handle'else'')
            log=run(mode,[*java,agentarg,'-cp',cp,'NativeFailureTest',mode])
            m=re.search(r'NATIVE_FAILURE mode='+mode+r' assertions=(\d+) PASS',log)
            if not m:raise RuntimeError('Missing failure summary for '+mode)
            failures[mode]=int(m[1])
        if a.provenance_tests:
            modified=out/'TEST_ONLY_changed_stock.jar'
            shutil.copyfile(game_jar,modified)
            with zipfile.ZipFile(modified,'a') as z:
                z.writestr('TEST_ONLY_COMPATIBILITY_FIXTURE.txt','Same classes, distinct archive hash')
            overlay=out/'TEST_ONLY_split_dependency.jar'
            with zipfile.ZipFile(game_jar) as original, zipfile.ZipFile(overlay,'w') as split:
                for name in ['META-INF/MANIFEST.MF','META-INF/PROJECTZ.EC','META-INF/PROJECTZ.SF',
                             'zombie/scripting/objects/ItemBodyLocation.class']:
                    split.writestr(name,original.read(name))
            for mode, archives in [('stock-jar',[modified]),('mixed-origin',[overlay,game_jar])]:
                negative_cp=os.pathsep.join(map(str,[classes,jar,*archives,buddy]))
                log=run(mode,[*java,'-javaagent:'+str(agent),'-cp',negative_cp,'NativeFailureTest',mode])
                m=re.search(r'NATIVE_FAILURE mode='+mode+r' assertions=(\d+) PASS',log)
                if not m:raise RuntimeError('Missing provenance failure summary for '+mode)
                failures[mode]=int(m[1])
        report['failure_assertions']=failures
        report['result']='PASS'
    except Exception as e:report['error']=str(e);raise
    finally:
        after={str(f):digest(f)for f in protected};report['protected_after']=after;report['protected_unchanged']=before==after
        if not report['protected_unchanged']:report['result']='FAIL';report['protected_change_detected']=True
        report['checked_utc']=datetime.now(timezone.utc).isoformat();(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items()if not k.startswith('protected_')},ensure_ascii=False))
    if not report['protected_unchanged']:raise RuntimeError('Protected live state changed')

if __name__=='__main__':main()
