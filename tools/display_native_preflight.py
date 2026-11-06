# Native Display.Install input check. Does not render or load a save/world.
from pathlib import Path
import argparse,datetime,hashlib,json,os,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--javac',type=Path,required=True)
 p.add_argument('--mods-list',type=Path,required=True);p.add_argument('--mod-root',action='append',required=True,help='Actual ID=installed-root; repeat for four wrappers')
 p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--expect',choices=['enabled','disabled'],required=True)
 a=p.parse_args();game=a.game_dir.resolve();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=True);classes=out/'classes';classes.mkdir(exist_ok=True)
 roots=[(x.split('=',1)[0],Path(x.split('=',1)[1]).resolve()) for x in a.mod_root];mapping=dict(roots)
 perf=mapping['Codex_InventoryTransferPerformance_4221']/'42/media/lua/client/Codex_InventoryTransferPerformance.lua'
 content=perf.read_text(encoding='utf-8-sig');start=content.index('    ISInventoryPane.renderdetails = function');end=content.index('    local paneInputs =',start)
 expression='return '+content[start:end].strip().split('=',1)[1].strip()+'\n';expression_file=out/'actual_renderer_expression.lua';expression_file.write_text(expression,encoding='utf-8')
 perf_version=re.search(r'M\.version\s*=\s*"([^"]+)"',content).group(1)
 core=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua/shared/SuQingRefrigeration/Core.lua';mod_version=re.search(r'C\.version\s*=\s*"([^"]+)"',core.read_text(encoding='utf-8-sig')).group(1)
 display=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua/client/SuQingRefrigeration_Display.lua'
 fixture=out/'dependency_fixture.lua';fixture.write_text('''-- Native gate APIs are deliberately untouched.
require=function(name)assert(name=="SuQingRefrigeration_Runtime");return true end
Events={OnTickEvenPaused={Add=function()end},OnMainMenuEnter={Add=function()end}}
SuQingRefrigeration={Runtime={ready=true},SP=function()return not isClient() and not isServer()end,version='''+json.dumps(mod_version)+'''}
ISInventoryPane={renderdetails=ProbeRenderer}
CodexInventoryTransferPerformance={installed=true,version='''+json.dumps(perf_version)+'''}
''',encoding='utf-8')
 assertions=out/'native_assertions.lua';expected='true' if a.expect=='enabled' else 'false'
 assertions.write_text('''local D=SuQingRefrigeration.Display
local ok,reason=D.Install()
assert(ok=='''+expected+''',"Unexpected install result: "..tostring(ok).." "..tostring(reason))
assert(SuQingRefrigeration.Runtime.displayDepth==0,"context leaked without rendering")
local info=getModInfoByID("P4HasBeenRead")
return "enabled="..tostring(ok).."; reason="..tostring(reason).."; game="..tostring(getCore():getVersionNumber()).."; build="..tostring(getCore():getGameAndBuildVersion()).."; renderer="..tostring(getFilenameOfClosure(ProbeRenderer)).."; P4="..tostring(info:getModVersion()).."; P4dir="..tostring(info:getVersionDir())
''',encoding='utf-8')
 commands=[[str(a.javac),'-encoding','UTF-8','-d',str(classes),str(ROOT/'tests/DisplayNativePreflight.java')],
 [str(game/'jre64/bin/java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out/'isolated_java_home'),'-Djava.library.path='+str(game/'win64')+os.pathsep+str(game),'-cp',str(classes)+os.pathsep+str(game)+os.pathsep+str(game/'projectzomboid.jar'),'DisplayNativePreflight',str(display),str(expression_file),str(perf),str(a.mods_list.resolve()),str(fixture),str(assertions)]]
 for id,path in roots:commands[-1]+=[id,str(path)]
 logs=[]
 for i,cmd in enumerate(commands):
  r=subprocess.run(cmd,cwd=game,capture_output=True,text=True,encoding='utf-8',errors='replace');(out/('step'+str(i)+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8');logs.append(r.stdout+r.stderr)
  if r.returncode:raise SystemExit(r.stdout+r.stderr)
 if 'PASS native gate preflight only' not in logs[-1]:raise SystemExit('No native preflight PASS marker')
 metadata=[]
 for line in logs[-1].splitlines():
  if not line.startswith('NATIVE_METADATA\t'):continue
  _,id,version,directory=line.split('\t',3);selected=Path(directory)/'mod.info'
  row={'id':id,'version':version,'versionDir':directory,'modInfo':str(selected),'modInfoSha256':hashlib.sha256(selected.read_bytes()).hexdigest()}
  if id=='P4HasBeenRead':
   source=Path(directory)/'media/lua/client/P4HasBeenRead.lua';row.update({'renderer':str(source),'rendererSha256':hashlib.sha256(source.read_bytes()).hexdigest()})
  metadata.append(row)
 files=[display,perf,core,a.mods_list.resolve(),ROOT/'tests/DisplayNativePreflight.java',fixture,assertions,expression_file]
 result={'time':datetime.datetime.now().astimezone().isoformat(),'status':'PASS','nativeMetadata':metadata,'expectedDisplayEnabled':a.expect=='enabled','commands':commands,'cwd':str(game),'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in files},'scope':'Actual native metadata/Core/active IDs/source APIs. Only runtime readiness/event bookkeeping is a controlled fixture; renderer compiled, never called. No world/gameplay acceptance.'}
 (out/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(logs[-1]);print('PASS '+str(out/'result.json'))
if __name__=='__main__':main()
