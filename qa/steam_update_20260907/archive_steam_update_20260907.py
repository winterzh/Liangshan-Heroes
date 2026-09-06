"""Archive this release's explicit evidence only; never its EXE, ZIP or profiles."""
from pathlib import Path
import datetime, hashlib, json, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / '.godot/steam_update_20260907'
DEST = ROOT / 'qa/steam_update_20260907'
EXTRA = ROOT / 'scratchpad/steam_update_extra_20260907'
COMMIT = '443e75e887afd76f9569cae17b0527a72408aedc'
def read(path): return json.loads(path.read_text(encoding='utf8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path, data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
build=read(BASE/'build_receipt.json')
package=read(BASE/'package_verification.json')
upload=read(BASE/'upload_zip_receipt.json')
extra=read(BASE/'settings_extra_v2/receipt.json')
status=read(BASE/'PUBLISH_STATUS.json')
assert build['source_commit'] == package['source_commit'] == extra['source_commit'] == status['source_commit'] == COMMIT
assert all(r['passed'] for r in [build, package, upload, extra])
assert extra['complete'] and extra['lock_released'] and extra['production_unchanged'] and extra['player_unchanged']
assert extra['checks'] == 61 and len(extra['modes']) == 2
assert sha(Path(upload['zip'])) == upload['zip_sha256']
assert sha(Path(build['executable'])) == build['sha256'] == upload['executable_sha256'] == extra['executable_sha256_after']
assert not DEST.exists(), 'Do not overwrite an existing archive'
DEST.mkdir(parents=True)
(DEST/'.gdignore').write_bytes(b'')
rows=[]
def copy(source, relative):
    target=DEST/relative
    assert source.is_file() and not target.exists()
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)
    assert sha(target) == sha(source)
    rows.append({'path':relative,'size_bytes':target.stat().st_size,'sha256':sha(target)})
names='''build_progress.json build_receipt.json build_windows.py contract.console.log export.log freeze_snapshot.py import.log package_contract.gd package_contract.json package_expected.json package_verification.json package_verification_progress.json package_visual_capture.gd prepare_upload_zip.py run_package_smoke.py smoke_driver.console.log source_manifest.json source_verification.json upload_zip_receipt.json verify_package.py visual.console.log visual_review.json finalize_archive_manifest.py helper_preparation.json strict_log_review.json release_scope.json PUBLISH_STATUS.json'''.split()
for name in names: copy(BASE/name,name)
for case in ['level'+str(i) for i in range(1,9)]+['defense','cleanup','main_menu']:
    for suffix in ['.console.log','.godot.log']: copy(BASE/'smoke'/(case+suffix),'smoke/'+case+suffix)
copy(BASE/'smoke/package_smoke.json','smoke/package_smoke.json')
for name in ['package_main_menu_1280x720.png','package_liangshan_defense_1280x720.png','package_visual_capture.json']:
    copy(BASE/'visual'/name,'visual/'+name)
for run_name, modes in [('settings_extra',['write']),('settings_extra_v2',['write','read'])]:
    copy(BASE/run_name/'receipt.json',run_name+'/receipt.json')
    for mode in modes:
        for name in ['configuration.json','process.log','process_receipt.json','godot.log','report.json']:
            copy(BASE/run_name/mode/name,f'{run_name}/{mode}/{name}')
copy(BASE/'settings_extra_v2/settings_1280x720.png','settings_extra_v2/settings_1280x720.png')
for relative in ['README.md','run_settings_qa.py','package_settings_qa.gd','runner_review/static_checks.py','runner_review/receipt.json','prior_cli_check/package_settings_qa.gd.txt','prior_cli_check/run_settings_qa.py.txt']:
    copy(EXTRA/relative,'settings_qa/'+relative)
for relative in ['scratchpad/chase_path_diag/run_generation.py','scratchpad/separation_sections_diag/frozen/process_safety.py','tools/run_polish_performance.py']:
    copy(ROOT/relative,'settings_qa/frozen_helpers/'+relative+'.txt')
copy(Path(__file__),'archive_steam_update_20260907.py')
copy(ROOT/'scratchpad/review_steam_package_20260907.py','review_steam_package_20260907.py')
copy(ROOT/'scratchpad/setup_steam_release_20260907.py','setup_steam_release_20260907.py')
review={'passed':True,'reviewer':'Codex root','source_commit':COMMIT,'executable_sha256':build['sha256'],
 'screenshot_sha256':extra['screenshot']['sha256'],'human_playtest':False,
 'result':'Opened actual 1280x720 Vulkan PNG with view_image. Display section and both effects buttons visible; reduced selected, explanatory text and save/back button legible and unclipped.',
 'scope':'Image review plus actual two-process input/persistence checks. Synthetic paused menu fixture is not full battle pause or human testing.'}
assert sha(BASE/'settings_extra_v2/settings_1280x720.png') == review['screenshot_sha256']
save(DEST/'settings_visual_review.json',review)
save(DEST/'settings_qa_revision.json',{'original_qa_sha256':'18e27a1882640d9853998e23f62cd367e84041eed7310782bed13f54735bb50a',
 'current_qa_sha256':sha(EXTRA/'package_settings_qa.gd'),'current_runner_sha256':sha(EXTRA/'run_settings_qa.py'),
 'original_failure':'First actual PID28656 exited1 after6 checks: QA incorrectly required OS.get_cmdline_args to retain the consumed --main-pack flag. All original evidence and scripts preserved.',
 'correction':'Owned Popen command verifies one --main-pack, exact path and no --path; actual QA verifies EXE bytes, production Settings/menu/codec loads and reports remaining arguments separately. Game EXE unchanged.',
 'validation':'New actual write/read processes passed33+28=61 checks, strict logs, distinct PID, isolated profile, exact settings byte continuity and EXE/player/source guards.',
 'static_receipt_scope':'44 synthetic/static preparation checks belong to original runner/GD, not this later revision; final revision is supported by the actual two-process result.'})
active=status.get('default_activated') is True
state=f"已上传并切换 Steam default：BuildID {status['build_id']}，Manifest {status['manifest_id']}。" if active else '已上传 Build25154403，default 仍待确认；实际阻塞见 PUBLISH_STATUS.json。'
readme=f'''# Windows Steam 更新证据：2026-09-07

{state}

源码为 `{COMMIT}`，来自已同步 stable 分支。Git 对象冻结 2,463 个运行文件、275,501,909 字节；描述树 `d58bd55c0ae3ebe210ab396a06e173b23f845fe9a8aeecd285970e5ab8a57937`。独立复核确认所有路径/Git对象一致，并复核8个运行变更的实际冻结字节。全量来源校验、导出后生产字节及导入侧车均无差异；只新增9个已知脚本UID。

## 成品与验收

- EXE：{build['size_bytes']:,} 字节，SHA256 `{build['sha256']}`，SHA1 `{upload['executable_sha1']}`。Godot4.6.3官方Windows x86_64 release，嵌入PCK；既有版本字段仍为1.8.0.0。
- ZIP：{upload['zip_size_bytes']:,} 字节，SHA256 `{upload['zip_sha256']}`；根目录仅LiangshanHeroes.exe，CRC与内部EXE哈希一致。
- 全新导入169.605秒、导出122.061秒，均退出0，无错误警告。包内437项覆盖36TRES、100排帧、22生产图片和开发文件排除。
- 实际EXE11次短测覆盖八关、驻守、末波清理、主菜单；驻守9项与末波清理12项通过。菜单、驻守的2张同包Vulkan画面已打开目检；27份日志严格复查无错误警告。
- 新包设置双进程33+28=61项通过：实际精简按钮输入、返回保存、独立进程恢复、配置字节、模态关闭和基础codec可加载；第三张1280×720设置图已目检。首轮QA误判引擎启动参数的失败及修正原文保留，见settings_qa_revision.json。

不能把这些检查称为完整八关通关、完整30波、30分钟稳定性、真人试玩、性能或商业美术来源验收。当前没有保存退出/继续本局功能。新设置的暂停检查是菜单夹具，未覆盖全部战斗暂停调用链。没有另做Steam客户端完整下载；上传后以服务端清单文件名、大小、SHA1和default行核对。

## 范围与复现

运行源码仅8个脚本变化，没有新增关卡/美术；本次更新包含精简特效、野猪林/祝家庄提示与飞斧失效目标修复。压力帧率门槛仍未通过，续局/追击诊断/RNG草稿未晋级。

原始成品在被忽略的 `.godot/steam_update_20260907/windows/`。EXE、ZIP、source/project副本、private_profile、玩家文件和缓存不进入Git。

从本归档恢复freeze_snapshot.py、build_windows.py、verify_package.py、package_contract.gd、prepare_upload_zip.py、finalize_archive_manifest.py到同一checkout下全新的 `.godot/<新名字>/`，Godot由GODOT_PATH指定。verify_package.py还依赖该checkout已跟踪的qa/steam_test_build_20260905/run_package_smoke.py与package_visual_capture.gd，两者均存在于443e75e。依次运行freeze_snapshot.py freeze、build_windows.py、verify_package.py；重新目检新图并写与新包和图片SHA绑定的visual_review.json后运行prepare_upload_zip.py。助手拒绝覆盖原成品；不要直接从qa归档运行或套用历史passed收据。旧finalize_archive_manifest.py只覆盖基础包证据，不能用来覆盖本批含补充设置与Steam记录的完整清单。

设置复现：恢复settings_qa下两个当前源文件到scratchpad/steam_update_extra_20260907；frozen_helpers中的三份文本按相对路径恢复原名，禁止覆盖已有不匹配版本。要求兼容的443e75e运行源码和已验证新build_receipt。入口默认只读预检，--run申请共用锁，在--out指定的新目录顺序执行两进程。原44项静态准备收据对应修正前版本，不混称当前验证。所有实际测试输出重新生成，不复制profile或玩家数据。

浏览器最初自动选择文件被扩展拒绝；用户手动选择本ZIP后继续。Steam操作详情见PUBLISH_STATUS.json。商店宣传素材由另一任务处理，本目录不记录其未完成状态。
'''
(DEST/'README.md').write_text(readme,encoding='utf8')
for name in ['.gdignore','README.md','settings_visual_review.json','settings_qa_revision.json']:
    p=DEST/name; rows.append({'path':name,'size_bytes':p.stat().st_size,'sha256':sha(p)})
save(DEST/'archive_manifest.json',{'source_commit':COMMIT,'file_count':len(rows),'total_bytes':sum(r['size_bytes'] for r in rows),'files':sorted(rows,key=lambda r:r['path']),
 'excluded_directories':['source','project','windows','userdata','private_profile'],'scope':'Explicit current build, QA, helper and Steam status evidence; no game exports, user profiles or browser credentials.'})
print(json.dumps({'archive':str(DEST),'file_count':len(rows),'bytes':sum(r['size_bytes'] for r in rows)},ensure_ascii=False))
