"""Package the retained mod without deploying it or overwriting an archive."""
from pathlib import Path
import argparse,hashlib,json,zipfile
from validate import main as validate
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--mod-id',choices=['SuQingRefrigerationUpgrade_4221','SuQingRefrigerationNative_4221'],default='SuQingRefrigerationUpgrade_4221')
 a=p.parse_args()
 validate();target=a.output.expanduser().resolve()
 assert target.suffix.lower()=='.zip','Output must be a ZIP file'
 target.parent.mkdir(parents=True,exist_ok=True)
 selected=ROOT/'mods'/a.mod_id
 files={f.relative_to(ROOT).as_posix():f for f in selected.rglob('*') if f.is_file()}
 manifest='native-source-manifest.json' if a.mod_id=='SuQingRefrigerationNative_4221' else 'source-manifest.json'
 expected=json.loads((ROOT/'docs'/manifest).read_text(encoding='utf-8'))
 assert expected['mod_id']==a.mod_id
 assert {f.relative_to(selected).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in files.values()}==expected['sha256']
 if a.mod_id=='SuQingRefrigerationNative_4221':
  assert not any(f.suffix.lower() in {'.png','.jpg','.jpeg','.gif','.ico'} for f in files.values()),'Java companion has no artwork'
 with target.open('xb') as stream:
  with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as z:
   for name,f in sorted(files.items()):z.write(f,name)
 with zipfile.ZipFile(target) as z:
  assert z.testzip() is None
  assert set(z.namelist())==set(files)
  for name,f in files.items():assert z.read(name)==f.read_bytes()
 print(json.dumps({'result':'PASS','mod_id':a.mod_id,'file_count':len(files),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'installed':False}))
if __name__=='__main__':main()
