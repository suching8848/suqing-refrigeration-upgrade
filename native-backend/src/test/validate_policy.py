"""Read native data objects with existing engine classes; no world/game/save/deployment."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,os,re,subprocess
BASE=Path(__file__).resolve().parents[2]
PACKAGE=Path('suqing/refrigeration/nativebackend')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,default=Path('D:/steam/steamapps/common/ProjectZomboid'))
    parser.add_argument('--javac',type=Path,default=Path('E:/code/kp_1016/lab2_evidence/ide-extensions/redhat.java-1.58.0-win32-x64/jre/25.0.4.1-win32-x86_64/bin/javac.exe'))
    args=parser.parse_args();game=args.game.resolve()
    production=[BASE/'src/main/java'/PACKAGE/(n+'.java')for n in('NativeColdEligibility','ColdContainerCache','NativeRuntime','NativeHooks')]
    tests=[BASE/'src/test/java'/PACKAGE/(n+'.java')for n in('NativePolicyTest','NativeContainerPolicyTest')]
    out=BASE/'validation'/('native_policy_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'));out.mkdir(parents=True)
    classes=out/'classes';classes.mkdir();home=out/'isolated_home';home.mkdir()
    env=os.environ.copy();env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'))
    report={'result':'FAIL','results':str(out),'game_started':False,'world_created':False,'cell_created':False,'save_loaded':False,'installed':False,'source_sha256':{str(p):sha(p)for p in production+tests}}
    def run(label,command):
        p=subprocess.run(list(map(str,command)),cwd=game,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=28)
        log=p.stdout+p.stderr;(out/(label+'.log')).write_text(log,encoding='utf-8')
        if p.returncode:raise RuntimeError(label+' failed; '+log[-5500:])
        return log
    try:
        cp=os.pathsep.join(map(str,(game,game/'projectzomboid.jar',game/'*')))
        run('javac',[args.javac,'--release','25','-encoding','UTF-8','-cp',cp,'-d',classes,*production,*tests])
        cp=os.pathsep.join(map(str,(classes,game,game/'projectzomboid.jar',game/'*')))
        for name,marker in [('NativePolicyTest','NATIVE_POLICY'),('NativeContainerPolicyTest','NATIVE_CONTAINER_POLICY')]:
            log=run(name,[game/'jre64/bin/java.exe','-Duser.home='+str(home),'-cp',cp,'suqing.refrigeration.nativebackend.'+name])
            m=re.search(marker+r' checks=(\d+) PASS',log)
            if not m:raise RuntimeError('Incomplete '+name)
            report[name]={'checks':int(m[1])}
            status=re.search(r'NATIVE_RUNTIME_STATUS (\{[^\r\n]+\})',log)
            if status:report['status_after_lifecycle_tests']=json.loads(status[1])
        report['inputs_unchanged']=all(sha(Path(p))==value for p,value in report['source_sha256'].items());assert report['inputs_unchanged']
        report['limits']=['Actual current engine classes and Kahlua tables; native InventoryContainer/Food objects use isolated fixture fields.', 'No Food bytecode transformation in these policy tests; transformed native aging is validated by the separate production Bootstrap suite.', 'No performance measurement; this run does not prove game UI/world/FPS behavior.']
        report['result']='PASS'
    except Exception as error:report['error']=str(error);raise
    finally:
        (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
