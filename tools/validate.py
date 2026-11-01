"""Read-only package validation; no game or save access."""
from pathlib import Path
import hashlib, json, struct
ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/'mods/SuQingRefrigerationUpgrade_4221'
def main():
 expected=json.loads((ROOT/'docs/source-manifest.json').read_text(encoding='utf-8'))
 actual={p.relative_to(MOD).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in MOD.rglob('*') if p.is_file()}
 assert actual==expected['sha256'],'Package differs from retained source snapshot'
 fields=dict(line.split('=',1) for line in (MOD/'42/mod.info').read_text(encoding='utf-8-sig').splitlines() if '=' in line)
 assert fields['id']=='SuQingRefrigerationUpgrade_4221' and fields['modversion']=='1.0.0-rc.2-perf.1'
 for p in ROOT.rglob('*.json'):
  if '.git' not in p.parts and 'validation' not in p.parts:json.loads(p.read_text(encoding='utf-8-sig'))
 assets=json.loads((ROOT/'docs/asset-manifest.json').read_text(encoding='utf-8'))
 for spec in assets['exports']:
  p=MOD/'42'/spec['file'];raw=p.read_bytes()
  assert raw[:8]==b'\x89PNG\r\n\x1a\n'
  assert list(struct.unpack('>II',raw[16:24]))==spec['size']
  assert hashlib.sha256(raw).hexdigest()==spec['sha256']
 print(json.dumps({'result':'PASS','mod_id':fields['id'],'version':fields['modversion'],'source_files':len(actual),'game_started':False}))
if __name__=='__main__':main()
