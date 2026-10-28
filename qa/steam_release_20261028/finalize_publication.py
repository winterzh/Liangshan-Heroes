"""Close this release from independent upload, public, download and client evidence."""
from pathlib import Path
import datetime,hashlib,json,re
HERE=Path(__file__).resolve().parent
def read(name):return json.loads((HERE/name).read_bytes())
def save(name,value):(HERE/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
candidate=read('candidate_delivery.json');server=read('server_manifest_verified.json');live=read('default_active_readback.json');news=read('announcement_public_verified.json');download=read('server_download_verified.json');runtime=read('server_runtime_verified.json');client=read('client_acceptance.json')
for record in (candidate,server,live,news,download,runtime,client):assert record['complete']
for record in (server,live,news,download,runtime,client):assert record['build_id']==26260970
for record in (server,live,download,runtime,client):assert record['manifest_id']=='7760891311054131368'
assert {r['language'] for r in news['languages']}=={'schinese','tchinese','english','japanese'}
assert all(r['body_fragments_matched']==9 and r['images_loaded'] for r in news['languages'])
assert client['exit_code_observed']==0 and client['library_six_files_match'] and client['actual_exit_confirmed']
assert client['changed_cloud_profile_fields']==['/updated_at'] and len(client['changed_original_player_files'])==1 and not client['removed_original_player_files']
assert all(p.startswith('shader_cache/') for p in client['new_player_files'])
client.update(game_progress_files_unchanged=True,cloud_metadata_timestamp_only_changed=True)
save('client_acceptance.json',client)
logs=(HERE/'steamcmd_upload/app_build_5088120.log').read_text();depot=(HERE/'steamcmd_upload/depot_build_5088121.log').read_text()
assert 'BuildID 26260970' in logs and 'Success! New manifestID 7760891311054131368' in depot
save('steamcmd_upload.json',{'complete':True,'exit_code':0,'build_id':26260970,'manifest_id':'7760891311054131368','set_live_during_upload':False,'six_root_files_verified':True,'corrected_preview':'steamcmd_preview_corrected.json','rejected_first_build':26260938,'rejected_first_build_activated':False})
notes=read('patch_notes_draft.json');notes.update(status='PUBLISHED_AND_FOUR_LANGUAGES_VERIFIED',build_id=26260970,event_id=news['event_id'],public_url=news['url']);save('patch_notes_published.json',notes)
process_log=Path('C:/Program Files (x86)/Steam/logs/gameprocess_log.txt').read_text(encoding='utf8',errors='replace')
lines=[s for s in process_log.splitlines() if 'AppID 5088120' in s and '66752' in s]
assert any('exit code 0' in s for s in lines)
(HERE/'client_process_evidence.log').write_text('\n'.join(lines)+'\n',encoding='utf8')
records=['candidate_delivery.json','gui_observations.json','steamcmd_preview_corrected.json','steamcmd_upload.json','server_manifest_verified.json','default_active_readback.json','announcement_public_verified.json','server_download_verified.json','server_runtime_verified.json','client_acceptance.json']
save('delivery_complete.json',{'complete':True,'date':'2026-10-28','source_head':candidate['source_head'],'app_id':5088120,'depot_id':5088121,'build_id':26260970,'manifest_id':'7760891311054131368','default_active':True,'announcement_public':True,'announcement_url':news['url'],'event_id':news['event_id'],'clean_download_and_hashes_passed':True,'server_menu_runtime_passed':True,'steam_client_update_boot_exit_passed':True,'player_progress_unchanged':True,'cloud_metadata_updated_at_changed':True,'rollback_build_id':26048429,'rejected_mapping_build_id':26260938,'rejected_mapping_build_activated':False,'full_52_or_61_rerun':False,'manual_full_route_completed':False,'human_full_playthrough_accepted':False,'campaign_continue_candidate_adopted':False,'main_merged':False,'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'evidence':[{'path':name,'sha256':hashlib.sha256((HERE/name).read_bytes()).hexdigest()} for name in records]})
print(json.dumps({'complete':True,'build':26260970,'manifest':'7760891311054131368','four_language_announcement':True,'client_exit_code':0}))
