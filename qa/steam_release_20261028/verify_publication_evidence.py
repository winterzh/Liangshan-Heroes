"""Check raw provenance and the explicit publication commit scope; never run the game."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def read(name):return json.loads((HERE/name).read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in read('evidence_copy_manifest.json')['files']+read('gui_observations.json')['files']:
 p=HERE/row['path'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],str(p)
for row in read('delivery_complete.json')['evidence']:assert sha(HERE/row['path'])==row['sha256'],row['path']
FILES='''README.md
announcement_public_verified.json
client.godot.log
client_acceptance.json
client_main_menu.jpg
client_player_backup.json
client_process_evidence.log
correct_steampipe_mapping.py
default_active_readback.json
delivery_complete.json
finalize_publication.py
patch_notes_published.json
public_schinese.jpg
server_download_verified.json
server_manifest_verified.json
server_menu.console.log
server_menu.godot.log
server_runtime_verified.json
steamcmd_preview.json
steamcmd_preview/5088121_preview.manifest.txt
steamcmd_preview/depot_build_first_mapping.log
steamcmd_preview_corrected.json
steamcmd_preview_corrected/5088121_preview.manifest.txt
steamcmd_preview_corrected/app_build_5088120.log
steamcmd_preview_corrected/depot_build_5088121.log
steamcmd_upload.json
steamcmd_upload/app_build_5088120.log
steamcmd_upload/depot_build_5088121.log
steampipe_mapping_correction.json
verify_server_delivery.py
verify_publication_evidence.py'''.splitlines()
DOCS='''CHANGELOG.md
README.md
docs/DEVELOPMENT_PLAN.md
docs/DIRECTORY_INDEX.md
docs/HUANGNIGANG_SEVEN_CARTS_ELEVEN_LOADS_20261018.md
docs/PROJECT_STATUS.md
docs/README.md
docs/SOURCE_SETUP.md
docs/STEAM_RELEASE_GUIDE.md
docs/STEAM_UPDATE_20261028.md
docs/WORKLOG.md
qa/README.md
qa/huangnigang_production_20261020/README.md'''.splitlines()
paths=[HERE/name for name in FILES]+[ROOT/name for name in DOCS]
secret=re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{32,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----')
for p in paths:
 assert p.is_file() and p.stat().st_size<10_000_000,str(p)
 data=p.read_bytes();assert not secret.search(data),str(p)
 if p.suffix=='.py':ast.parse(data.decode('utf8'),filename=str(p))
 if p.suffix=='.json':json.loads(data)
 if p.suffix=='.png':assert data.startswith(b'\x89PNG\r\n\x1a\n')
 if p.suffix=='.jpg':assert data.startswith(b'\xff\xd8\xff')
diff=subprocess.check_output(['git','diff','--unified=0','--','*.md'],cwd=ROOT).decode('utf8')
current=None
for line in diff.splitlines():
 if line.startswith('+++ b/'):current=ROOT/line[6:]
 elif line.startswith('+') and not line.startswith('+++') and current:
  for target in re.findall(r'\]\(([^)]+)\)',line):
   target=target.strip('<>').split('#')[0]
   if not target or re.match(r'^[a-z]+:',target) or target.startswith('/'):continue
   assert (current.parent/target).exists(),(current,target)
rows=[]
for p in paths:
 name=p.relative_to(ROOT).as_posix();working=p.read_bytes()
 # QA artifacts are -text and byte-bound. Documentation follows Git's
 # configured text filters; bind its published blob, not Windows CRLF bytes.
 oid=subprocess.check_output(['git','hash-object','-w','--path',name,'--stdin'],input=working,cwd=ROOT).decode().strip()
 blob=subprocess.check_output(['git','cat-file','blob',oid],cwd=ROOT)
 if p.is_relative_to(HERE):assert blob==working,name
 rows.append({'path':name,'bytes':len(blob),'sha256':hashlib.sha256(blob).hexdigest(),'working_copy_sha256':hashlib.sha256(working).hexdigest()})
inventory={'complete':True,'scope':'published Build26260970 and independent server/client/language evidence','hash_scope':'Git-filtered published blobs; QA -text originals additionally match exact working bytes','files':rows,'file_count':len(rows),'bytes':sum(r['bytes'] for r in rows),'raw_preparation_and_gui_evidence_unchanged':True,'credentials_player_payloads_and_binaries_excluded':True,'public_screenshot_account_header_excluded':True}
(HERE/'publication_evidence_inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'complete':True,'files':len(rows),'bytes':inventory['bytes']}))
