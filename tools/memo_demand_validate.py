"""Focused on-demand display-memo regression, bound to current mod source only."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,os,re,subprocess

ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def state_vector(text,prefix='MEMO_VECTOR'):
    match=re.search(prefix+r' ([^\r\n]+)',text)
    if not match:raise RuntimeError('Missing complete '+prefix)
    return [[float(value)for value in row.split(':')]for row in match[1].split(',')]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,default=Path('D:/steam/steamapps/common/ProjectZomboid'))
    parser.add_argument('--javac',type=Path,default=Path('E:/code/java-1.8.0-openjdk-1.8.0.392-1.b08.redhat.windows.x86_64/bin/javac.exe'))
    parser.add_argument('--expected-runtime-sha256',help='Optional exact reviewed candidate binding for release acceptance.')
    parser.add_argument('--reference-log',type=Path,help='Optional frozen MEMO_VECTOR log for exact physical state comparison.')
    args=parser.parse_args();game=args.game.resolve();java=game/'jre64/bin/java.exe';jar=game/'projectzomboid.jar'
    source=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua'
    files={'core':source/'shared/SuQingRefrigeration/Core.lua','cache':source/'shared/SuQingRefrigeration/StateCache.lua','runtime':source/'client/SuQingRefrigeration_Runtime.lua'}
    tests=ROOT/'tests'
    inputs=[*files.values(),tests/'mock_bootstrap.lua',tests/'native_bootstrap.lua',tests/'KahluaValidation.java',tests/'NativeCoolingProbe.java',tests/'memo_demand_cases.lua',tests/'memo_runtime_review_cases.lua',tests/'native_memo_demand_cases.lua',jar]
    if args.reference_log:inputs.append(args.reference_log.resolve())
    for path in(java,args.javac,*inputs):
        if not path.is_file():raise RuntimeError('Missing existing input: '+str(path))
    out=ROOT/'validation'/('memo_demand_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    out.mkdir(parents=True);classes=out/'classes';classes.mkdir();home=out/'isolated_home';home.mkdir()
    env=os.environ.copy();env.update(USERPROFILE=str(home),APPDATA=str(home/'AppData/Roaming'),LOCALAPPDATA=str(home/'AppData/Local'))
    report={'result':'FAIL','results':str(out),'checked_utc':datetime.now(timezone.utc).isoformat(),'game_started':False,'world_created':False,'world_loaded':False,'user_save_read':False,'source_or_deployment_modified':False,'java_patch_created':False,'input_sha256':{str(p):sha(p)for p in inputs},'source_sha256':{key:sha(p)for key,p in files.items()}}
    def execute(label,command):
        run=subprocess.run(list(map(str,command)),cwd=game,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=28)
        content=run.stdout+run.stderr;(out/(label+'.log')).write_text(content,encoding='utf-8')
        if run.returncode:raise RuntimeError(label+' failed; see '+str(out/(label+'.log'))+'\n'+content[-5500:])
        return content
    try:
        if args.expected_runtime_sha256 and report['source_sha256']['runtime'].lower()!=args.expected_runtime_sha256.lower():
            raise RuntimeError('Current Runtime does not match the explicitly reviewed hash')
        # Existing, unchanged offline test harnesses, not Java mod/patch code.
        execute('javac_existing_harnesses',[args.javac,'-encoding','UTF-8','-d',classes,tests/'KahluaValidation.java',tests/'NativeCoolingProbe.java'])
        cp=os.pathsep.join(map(str,(classes,game,jar,game/'*')));report['classpath_order']=cp
        common=[files['core'],files['cache'],files['runtime']]
        focused=execute('focused',[java,'-Duser.home='+str(home),'-cp',cp,'KahluaValidation',tests/'mock_bootstrap.lua',*common,tests/'memo_demand_cases.lua'])
        match=re.search(r'MEMO_REVIEW cases=(\d+) assertions=(\d+) PASS',focused)
        counts=re.search(r'MEMO_LOAD ([^\r\n]+)',focused)
        if not match or not counts:raise RuntimeError('Incomplete focused memo result')
        report['focused']={'cases':int(match[1]),'assertions':int(match[2]),'counts':{key:int(value)for key,value in re.findall(r'(\w+)=(\d+)',counts[1])}}
        vector=state_vector(focused)
        if len(vector)!=571:raise RuntimeError('Expected all 571 food physical states')
        report['focused']['food_states']=len(vector)
        if args.reference_log:
            reference=state_vector(args.reference_log.read_text(encoding='utf-8'))
            if len(reference)!=len(vector):raise RuntimeError('Reference vector length differs')
            difference=max(abs(x-y)for a,b in zip(vector,reference)for x,y in zip(a,b))
            report['reference_age_heat_lastaged_max_difference']=difference
            if difference!=0:raise RuntimeError('Physical state differs from the frozen reference')
        review=execute('prior_runtime_review',[java,'-Duser.home='+str(home),'-cp',cp,'KahluaValidation',tests/'mock_bootstrap.lua',*common,tests/'memo_runtime_review_cases.lua'])
        match=re.search(r'STATE_RUNTIME_REVIEW cases=(\d+) assertions=(\d+) PASS',review)
        if not match:raise RuntimeError('Incomplete prior runtime invariant review')
        report['prior_review']={'cases':int(match[1]),'assertions':int(match[2])}
        native=execute('native_food',[java,'-Duser.home='+str(home),'-cp',cp,'NativeCoolingProbe',tests/'native_bootstrap.lua',*common,tests/'native_memo_demand_cases.lua'])
        scenarios=re.findall(r'NATIVE_DEMAND scenario=(\w+) first_native=(\d+) reopen_native=(\d+) same_physical=true same_freezing=true',native)
        if len(scenarios)!=2 or 'NATIVE_DEMAND scenarios=2 PASS'not in native:raise RuntimeError('Incomplete actual native Food scenarios')
        report['native']={'scenarios':[{'name':name,'first_native':int(first),'reopen_native':int(reopen)}for name,first,reopen in scenarios],'physical_and_freezing_preserved':True}
        report['inputs_unchanged']=all(sha(Path(path))==value for path,value in report['input_sha256'].items())
        if not report['inputs_unchanged']:raise RuntimeError('A tested input changed during the run')
        version=re.search(r'C.version\s*=\s*"([^"]+)"',files['core'].read_text(encoding='utf-8'))
        report['source_version']=version[1]if version else None
        report['limits']=['Focused and prior invariant tests use actual current PZO Kahlua with trusted plain ownership mocks.', 'Native scenarios use real Food/GameTime and the real exposed ageWrapper without a world, cell or game client.', 'The first unobserved display intentionally performs one strict same-clock settlement, then subscribes to full signatures.', 'No timing/FPS claim is made by this runner; the archived paired benchmark is a separate experiment over one reused native Food.']
        report['result']='PASS'
    except Exception as error:report['error']=str(error);raise
    finally:
        (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
