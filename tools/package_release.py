"""Package the retained mod without deploying it or overwriting an archive."""
from pathlib import Path
import argparse,hashlib,json,zipfile
from validate import main as validate
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 validate();target=a.output.expanduser().resolve()
 assert target.suffix.lower()=='.zip','Output must be a ZIP file'
 target.parent.mkdir(parents=True,exist_ok=True)
 files={f.relative_to(ROOT).as_posix():f for f in (ROOT/'mods').rglob('*') if f.is_file()}
 with target.open('xb') as stream:
  with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as z:
   for name,f in sorted(files.items()):z.write(f,name)
 with zipfile.ZipFile(target) as z:
  assert z.testzip() is None
  assert set(z.namelist())==set(files)
  for name,f in files.items():assert z.read(name)==f.read_bytes()
 print(json.dumps({'result':'PASS','file_count':len(files),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'installed':False}))
if __name__=='__main__':main()
