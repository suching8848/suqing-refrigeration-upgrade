"""Build the optional source-tree candidate only; never installs or launches PZ."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, zipfile
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,default=Path(r'D:\steam\steamapps\common\ProjectZomboid'))
    p.add_argument('--jdk',type=Path,default=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64'))
    p.add_argument('--zombie-buddy',type=Path,default=Path(r'D:\steam\steamapps\workshop\content\108600\3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar'))
    p.add_argument('--output',type=Path,help='Destination JAR outside the source tree for offline validation')
    a=p.parse_args()
    package=ROOT.parent/'mods/SuQingRefrigerationNative_4221/42'
    metadata=dict(line.split('=',1) for line in (package/'mod.info').read_text(encoding='utf-8-sig').splitlines() if '=' in line)
    jar=a.output.resolve() if a.output else package/'media/java/client/SuQingRefrigerationNative.jar'
    if a.output and jar.exists():
        p.error(f'Output already exists: {jar}')
    receipt_path=jar.with_suffix('.build.json') if a.output else ROOT/'build/build-receipt.json'
    work=jar.parent if a.output else ROOT/'build'
    compiler=a.jdk/'bin/javac.exe'
    game_jar=a.game/'projectzomboid.jar'
    # Fresh output for every build prevents removed nested classes from an older
    # compiler run being included by the source-prefix inventory below.
    classes=work/('classes_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    classes.mkdir(parents=True,exist_ok=False)
    sources=sorted((ROOT/'src/main/java').rglob('*.java'))
    cp=os.pathsep.join(map(str,[game_jar,a.zombie_buddy]))
    subprocess.run([str(compiler),'--release','25','-encoding','UTF-8','-cp',cp,'-d',str(classes),*map(str,sources)],check=True)
    jar.parent.mkdir(parents=True,exist_ok=True)
    # Use only classes corresponding to this build's current source set, so stale
    # files from another build cannot silently enter the candidate.
    entries=[]
    for source in sources:
        rel=source.relative_to(ROOT/'src/main/java').with_suffix('')
        entries.extend((classes/rel.parent).glob(rel.name+'*.class'))
    with zipfile.ZipFile(jar,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        manifest=('Manifest-Version: 1.0\r\nImplementation-Title: SuQing Refrigeration Native Backend\r\n'
                  f"Implementation-Version: {metadata['modversion']}\r\n\r\n")
        for name,data in [('META-INF/MANIFEST.MF',manifest.encode()),*[(f.relative_to(classes).as_posix(),f.read_bytes()) for f in sorted(set(entries))]]:
            info=zipfile.ZipInfo(name,(2026,11,7,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,data)
    receipt={'candidate':str(jar),'sha256':hashlib.sha256(jar.read_bytes()).hexdigest(),'class_count':len(set(entries)),
        'source_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sources},'installed':False,'game_launched':False}
    receipt.update(version=metadata['modversion'], compiler=subprocess.check_output([str(compiler),'-version'],text=True).strip(),
        game_jar_sha256=hashlib.sha256(game_jar.read_bytes()).hexdigest(),
        zombie_buddy_sha256=hashlib.sha256(a.zombie_buddy.read_bytes()).hexdigest())
    receipt_path.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False))

if __name__=='__main__':main()
