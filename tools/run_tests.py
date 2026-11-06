"""Run local-game offline probes with explicit game/compiler paths; no deployment."""
from pathlib import Path
import argparse,os,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game-dir',type=Path,required=True);p.add_argument('--javac',type=Path,required=True)
 p.add_argument('--java',type=Path);p.add_argument('--native-food',action='store_true');a=p.parse_args()
 game=a.game_dir.expanduser().resolve();out=ROOT/'validation';classes=out/'classes';classes.mkdir(parents=True,exist_ok=True)
 jar=game/'projectzomboid.jar';assert jar.is_file(),'Game JAR not found'
 java=a.java or game/'jre64/bin/java.exe'
 def run(cmd,name):
  x=subprocess.run([str(v) for v in cmd],cwd=game,capture_output=True,text=True,encoding='utf-8',errors='replace')
  (out/(name+'.log')).write_text(x.stdout+x.stderr,encoding='utf-8')
  assert x.returncode==0,name+' failed; inspect ignored validation log'
 sources=['KahluaValidation.java','NativeCraftingAudit.java','NativeCoolingProbe.java']
 run([a.javac,'-encoding','UTF-8','-d',classes,*[ROOT/'tests'/s for s in sources]],'compile')
 cp=str(classes)+os.pathsep+str(game)+os.pathsep+str(jar);lua=ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/lua'
 modules=[lua/'shared/SuQingRefrigeration/Core.lua',lua/'shared/SuQingRefrigeration/StateCache.lua',lua/'client/SuQingRefrigeration_Runtime.lua',lua/'client/SuQingRefrigeration_Display.lua',lua/'client/SuQingRefrigeration_UI.lua',lua/'shared/SuQingRefrigeration/Recipes.lua',lua/'client/SuQingRefrigeration_Crafting.lua']
 run([java,'-Duser.home='+str(out/'model_home'),'-cp',cp,'KahluaValidation',ROOT/'tests/mock_bootstrap.lua',*modules,ROOT/'tests/mock_cases.lua',ROOT/'tests/crafting_cases.lua'],'kahlua')
 run([java,'-Duser.home='+str(out/'recipe_home'),'-cp',cp,'NativeCraftingAudit',ROOT/'mods/SuQingRefrigerationUpgrade_4221/42/media/scripts/SuQingRefrigeration.txt'],'native_recipe')
 if a.native_food:run([java,'-Duser.home='+str(out/'native_home'),'-cp',cp,'NativeCoolingProbe',ROOT/'tests/native_bootstrap.lua',*modules[:3],ROOT/'tests/native_cases.lua'],'native_food')
 print('PASS: offline probes; no client gameplay acceptance was performed')
if __name__=='__main__':main()
