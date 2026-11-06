"""Freeze source-only review package. Does not install, enable, publish or commit."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, zipfile

ROOT=Path(__file__).resolve().parents[2]
LUNCH=Path(r'D:\steam\steamapps\common\ProjectZomboid\CodexRepos\suqing-freshness-lunchbox')
def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();out.parent.mkdir(parents=True,exist_ok=True)
    sources={}
    def add_tree(folder,prefix):
        for f in sorted(folder.rglob('*')):
            if f.is_file() and '__pycache__' not in f.parts:sources[prefix+'/'+f.relative_to(folder).as_posix()]=f
    for name in ['SuQingRefrigerationUpgrade_4221','SuQingRefrigerationNative_4221']:
        add_tree(ROOT/'mods'/name,'mods/'+name)
    add_tree(LUNCH/'mods/SuQingFreshnessLunchbox','mods/SuQingFreshnessLunchbox')
    for part in ['src','tools','docs']:add_tree(ROOT/'native-backend'/part,'native-backend/'+part)
    for part in ['tests','tools','docs']:add_tree(ROOT/part,part)
    for name in ['README.md','README.en.md','CHANGELOG.md','native-backend/README.md']:
        sources[name]=ROOT/name
    content={name:f.read_bytes()for name,f in sorted(sources.items())}
    manifest={'created_utc':datetime.now(timezone.utc).isoformat(),'installed':False,'enabled':False,'published':False,
        'status':'SOURCE_REVIEW_CANDIDATE_OFFLINE_ONLY','main_version':'1.0.0-rc.2-perf.8','native_version':'0.1.0-rc.1',
        'sources':{name:str(sources[name])for name in content},'sha256':{name:sha(data)for name,data in content.items()}}
    content['CANDIDATE-MANIFEST.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    with out.open('xb')as stream:
        with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1,allowZip64=True)as z:
            for name,data in content.items():z.writestr(name,data)
    with zipfile.ZipFile(out)as z:
        assert set(z.namelist())==set(content)
        for name,data in content.items():assert sha(z.read(name))==sha(data),name
    assert all(f.read_bytes()==content[name]for name,f in sources.items()),'Source changed during freeze'
    receipt={'result':'PASS','archive':str(out),'sha256':sha(out.read_bytes()),'file_count':len(content),
        'bytes':out.stat().st_size,'full_member_readback':True,'installed':False,'enabled':False,'published':False}
    out.with_suffix('.receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False))

if __name__=='__main__':main()
