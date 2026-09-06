# -*- coding: utf-8 -*-
from pathlib import Path
import hashlib, json, shutil
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'.godot/steam_update_20260907'
QA=ROOT/'qa/steam_update_20260907'
def read(path): return json.loads(path.read_text(encoding='utf8'))
def save(path, value): path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
status=read(BASE/'PUBLISH_STATUS.json')
assert status['build_id']==25154403 and status['manifest_id']=='596698599141519420'
status.update(default_activated=True,default_activation_verified=True,status='active_verified',blocker=None,
 verified_at_utc='2026-09-06T17:28:39Z',default_row_text='default / Public default branch / 25154403',
 verification_source='Steamworks current-build preview states current and next are 25154403; canonical builds page default row and new build row both show 25154403. Earlier Depot Manifest file name/size/SHA1 matched tested EXE.',
 activation_history=[
  'Automated browser dialog acceptance timed out. Native Computer Use stopped the prior turn due to uncertain browser URL; no security setting was changed.',
  'User supplied a screenshot of the ordinary 25154403/default confirmation and was guided to confirm it.',
  'Initial submittedbuild page and reload still showed old default25149197; a later preview reported current build already25154403, so no second actual activation was submitted.',
  'Canonical builds page then independently showed default25154403.'])
save(BASE/'PUBLISH_STATUS.json',status)
save(QA/'PUBLISH_STATUS.json',status)
script=ROOT/'scratchpad/archive_steam_update_20260907.py'
shutil.copyfile(script,QA/'archive_steam_update_20260907.py')
readme=(QA/'README.md').read_text(encoding='utf8')
readme=readme.replace('构建和验证完成，Steam 状态以 PUBLISH_STATUS.json 的实际阻塞记录为准。','已上传并切换 Steam default：BuildID 25154403，Manifest 596698599141519420。')
readme=readme.replace('本次上线精简特效','本次更新包含精简特效')
readme=readme.replace('从本归档恢复根目录6个构建助手到同一checkout下全新的', '从本归档恢复freeze_snapshot.py、build_windows.py、verify_package.py、package_contract.gd、prepare_upload_zip.py、finalize_archive_manifest.py到同一checkout下全新的')
readme=readme.replace('Godot由GODOT_PATH指定。依次运行', 'Godot由GODOT_PATH指定。verify_package.py还依赖同checkout已跟踪的qa/steam_test_build_20260905/run_package_smoke.py和package_visual_capture.gd（均存在于443e75e）。依次运行')
readme=readme.replace('助手拒绝覆盖原成品；不要直接从qa归档运行或套用历史passed收据。','助手拒绝覆盖原成品；不要直接从qa归档运行或套用历史passed收据。旧finalize_archive_manifest.py仅覆盖基础包范围，不可覆盖本批完整清单。')
(QA/'README.md').write_bytes(readme.encode())
save(QA/'source_scope_review.json',{'reviewer':'Codex playtest_checklist independent read-only audit','source_commit':status['source_commit'],
 'manifest_path_count':2463,'manifest_total_bytes':275501909,'source_manifest_sha256':sha(BASE/'source_manifest.json'),
 'all_manifest_paths_and_git_blob_ids_match_commit':True,'changed_runtime_files_verified_from_frozen_bytes_and_git':8,
 'independent_full_275MB_rehash_performed':False,
 'runtime_scope':'8 changed scripts, no new scenes, production artwork, project config or export presets. New standalone codec is included by scripts allowlist.',
 'source_verification':'Root full frozen-source hashes match manifest; production and importer sidecars unchanged, generated UIDs exactly9 known scripts.',
 'actual_settings_result':'Original6 checks contain1 failure due to QA startup-argument assumption; final33+28 pass with owned PIDs40880/41188 and unchanged EXE/player/source.',
 'archive_review':'Explicit allowlist preserves original failure/current success and required helpers; no profile, cache, export executable/archive or player save contents.'})
doc=ROOT/'docs/STEAM_UPDATE_20260907.md'
body=doc.read_text(encoding='utf8')
body=body.replace('当前 default 上线确认仍待完成，不能将“上传成功”称为“已上线”；实际状态见','已回读确认 default 为25154403，Windows更新已上线；实际状态见')
body=body.replace('最后的上线确认需要完成并回读default行，完成后更新本页及发布收据。','上线确认已完成：预览显示当前构建已为25154403，随后canonical builds页default行及新版本行均回读25154403。')
body=body.replace('用户截图确认该普通确认框仍打开。没有绕过安全校验或改变扩展权限。','用户提供普通确认框截图并协助确认。初期版本列表仍返回旧值，随后预览和canonical列表均核实新default，未再次提交实际切换。没有绕过安全校验或改变扩展权限。')
doc.write_bytes(body.encode())
prefixes={
 'WORKLOG.md': '## 2026-09-07 Windows Steam 更新完成\n\n已从443e75e冻结、导出并上传Build25154403（Manifest596698599141519420）；default行及预览均确认新版本，服务端EXE哈希与本地一致。437项包内、11次EXE短测、61项双进程设置及3张Vulkan目检通过，保留原外部QA误判的6项中1项失败。完整状态见[本次更新](STEAM_UPDATE_20260907.md)。仅同步本批文档/证据，不合并main；续局、正式性能和持续目标保持开放。\n\n',
 'SOURCE_SETUP.md': '## 2026-09-07 Windows 更新成品与复现\n\nSteam default已确认为Build25154403，源443e75e；完整状态见[更新记录](STEAM_UPDATE_20260907.md)。本地EXE和单文件ZIP在忽略目录 `.godot/steam_update_20260907/windows/`；[QA归档](../qa/steam_update_20260907/README.md)提供精确来源和复现步骤。构建助手需恢复到全新忽略目录并使用GODOT_PATH，不覆盖历史产物或沿用旧passed收据。新增设置已验证跨进程保存，整局继续入口仍未实现。\n\n',
 'DIRECTORY_INDEX.md': '## 2026-09-07 Steam Windows 更新证据\n\n- `docs/STEAM_UPDATE_20260907.md`：本轮已上线Windows包、功能变化、验证范围和Steam状态。\n- `qa/steam_update_20260907/`：逐文件归档、437项资源、11次短测、61项设置复验、3图、原QA失败和发布收据；不含成品、缓存或profile。\n- `.godot/steam_update_20260907/windows/`：仅本地EXE与已校验ZIP，不进入Git。\n\n',
 'PROJECT_STATUS.md': '## 2026-09-07 Steam Windows 更新完成\n\n源443e75e已发布为Steam Build25154403，default行及服务端SHA1均核实一致。包内437项、EXE11次短测、设置双进程61项及3图通过，见[发布记录](STEAM_UPDATE_20260907.md)。本批交付已验证的特效/反馈/飞斧修复；续局、正式性能、完整真人流程和持续目标继续保持开放。\n\n'}
for name,prefix in prefixes.items():
    p=ROOT/'docs'/name
    old=p.read_text(encoding='utf8')
    assert old.startswith('## 2026-09-07 ')
    next_heading=old.find('\n## ',1)
    assert next_heading>0
    p.write_bytes((prefix+old[next_heading+1:]).encode())
shutil.copyfile(Path(__file__),QA/'finalize_steam_release_20260907.py')
manifest=read(QA/'archive_manifest.json')
known={row['path'] for row in manifest['files']}
known.update(['source_scope_review.json','finalize_steam_release_20260907.py'])
rows=[]
for relative in sorted(known):
    p=QA/relative
    assert p.is_file() and not any(part in ('private_profile','userdata','windows','project','source') for part in Path(relative).parts)
    rows.append({'path':relative,'size_bytes':p.stat().st_size,'sha256':sha(p)})
manifest.update(files=rows,file_count=len(rows),total_bytes=sum(r['size_bytes'] for r in rows))
save(QA/'archive_manifest.json',manifest)
print(json.dumps({'published':status['default_activated'],'build':status['build_id'],'archive_files':len(rows),'archive_bytes':manifest['total_bytes']}))
