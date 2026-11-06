"""Standalone state-cache regression; no game client, world, save or deployment."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,default=Path('D:/steam/steamapps/common/ProjectZomboid'))
    parser.add_argument('--javac',type=Path,default=Path('E:/code/java-1.8.0-openjdk-1.8.0.392-1.b08.redhat.windows.x86_64/bin/javac.exe'))
    args=parser.parse_args();game=args.game.resolve()
    java=game/'jre64/bin/java.exe';jar=game/'projectzomboid.jar'
    source=ROOT/'tests/KahluaValidation.java'
    bootstrap=ROOT/'tests/mock_bootstrap.lua'
    lua=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua/shared/SuQingRefrigeration'
    core=lua/'Core.lua';module=lua/'StateCache.lua';cases=ROOT/'tests/state_cache_cases.lua'
    for path in (java,jar,args.javac,source,bootstrap,core,module,cases):
        if not path.is_file(): raise RuntimeError(f'Missing existing input: {path}')
    output=ROOT/'validation'/('state_cache_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    output.mkdir(parents=True,exist_ok=False);classes=output/'classes';classes.mkdir()
    home=output/'isolated_home';home.mkdir()
    env=os.environ.copy();env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'))
    report={'result':'FAIL','checked_utc':datetime.now(timezone.utc).isoformat(),
        'game_started':False,'world_created':False,'world_loaded':False,'user_save_read':False,'deployed':False,
        'results':str(output),'input_sha256':{str(path):sha(path) for path in (jar,source,bootstrap,module,cases)}}
    def execute(label,command):
        result=subprocess.run(list(map(str,command)),cwd=game,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
        content=result.stdout+result.stderr;(output/(label+'.log')).write_text(content,encoding='utf-8')
        if result.returncode: raise RuntimeError(f'{label} failed; see {output/(label+".log")}\n{content[-7000:]}')
        return content
    try:
        execute('javac',[args.javac,'-encoding','UTF-8','-d',classes,source])
        cp=os.pathsep.join(map(str,(classes,game,jar,game/'*')))
        log=execute('kahlua',[java,'-Duser.home='+str(home),'-cp',cp,'KahluaValidation',bootstrap,core,module,cases])
        summary=re.search(r'STATE_CACHE cases=(\d+) assertions=(\d+) PASS',log)
        if not summary: raise RuntimeError('Missing complete state-cache PASS summary')
        report.update(result='PASS',cases=int(summary[1]),assertions=int(summary[2]),
            ttl_game_hours=1/60,foods=571,direct_containers=6,strict_calls_per_ttl_window=6,
            limits=['Standalone method/object fixtures only; no in-game FPS measurement.',
                    'Weak-key mode and scalar-only entry structure are verified; no GC timing is claimed.',
                    'Known mutations require caller invalidation; unknown bypass changes may remain cached for at most one game minute.'])
        if any(sha(Path(path))!=value for path,value in report['input_sha256'].items()):
            raise RuntimeError('A tested input changed while the regression ran')
    except Exception as error:
        report['result']='FAIL';report['error']=str(error);raise
    finally:
        (output/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__': main()
