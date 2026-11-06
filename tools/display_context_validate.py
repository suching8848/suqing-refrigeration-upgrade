"""Standalone Kahlua display-context regression. Does not launch a game/world."""
from pathlib import Path
import argparse,datetime,hashlib,json,os,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--javac',type=Path,required=True)
 p.add_argument('--java',type=Path);p.add_argument('--output-dir',type=Path)
 a=p.parse_args();game=a.game_dir.resolve();java=a.java or game/'jre64/bin/java.exe'
 out=(a.output_dir or ROOT/'validation/display_context').resolve();out.mkdir(parents=True,exist_ok=True);classes=out/'classes';classes.mkdir(exist_ok=True)
 module=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua/client/SuQingRefrigeration_Display.lua'
 source=module.read_text(encoding='utf-8');eq='='
 while ']'+eq+']' in source:eq+='='
 fixture=out/'module_source.lua';fixture.write_text('DISPLAY_MODULE_SOURCE=['+eq+'['+source+']'+eq+']\nDISPLAY_MODULE_PATH='+json.dumps(str(module),ensure_ascii=False)+'\n',encoding='utf-8')
 cmds=[[str(a.javac),'-encoding','UTF-8','-d',str(classes),str(ROOT/'tests/KahluaValidation.java'),str(ROOT/'tests/CoreVersionReadback.java')],
  [str(java),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out/'isolated_java_home'),'-cp',str(classes)+os.pathsep+str(game)+os.pathsep+str(game/'projectzomboid.jar'),'CoreVersionReadback',str(out/'native_core_version.lua')],
  [str(java),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out/'isolated_java_home'),'-cp',str(classes)+os.pathsep+str(game)+os.pathsep+str(game/'projectzomboid.jar'),'KahluaValidation',str(fixture),str(out/'native_core_version.lua'),str(ROOT/'tests/display_context_cases.lua')]]
 logs=[]
 for i,cmd in enumerate(cmds):
  r=subprocess.run(cmd,cwd=game,capture_output=True,text=True,encoding='utf-8',errors='replace');(out/('step'+str(i)+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8');logs.append(r.stdout+r.stderr)
  if r.returncode:raise SystemExit(r.stdout+r.stderr)
 if 'PASS display context cases=' not in logs[-1]:raise SystemExit('No display context PASS marker')
 receipt={'time':datetime.datetime.now().astimezone().isoformat(),'status':'PASS','commands':cmds,'cwd':str(game),'module':str(module),'moduleSha256':hashlib.sha256(module.read_bytes()).hexdigest(),'testSha256':hashlib.sha256((ROOT/'tests/display_context_cases.lua').read_bytes()).hexdigest(),'nativeCoreReadbackSha256':hashlib.sha256((ROOT/'tests/CoreVersionReadback.java').read_bytes()).hexdigest(),'nativeCoreVersionFixture':str(out/'native_core_version.lua'),'scope':'Standalone current PZO Kahlua mocks only; no game/world/UI acceptance.'}
 (out/'result.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
 print(logs[-1]);print('PASS: '+str(out/'result.json'))
if __name__=='__main__':main()
