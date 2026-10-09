from pathlib import Path
import datetime, hashlib, json, subprocess
ROOT = Path('E:/ChatGPT/水浒')
QA = ROOT / 'qa/zhu_wounded_20261005'
SOURCE = Path('E:/ChatGPT/campaign_persistence_observability_v27_proposal')
TARGET = QA / 'proposals/campaign_persistence_observability_v27'
BASE = 'af1cbec94a98af70bfd7364641b4f318d750d6e3'
files = []

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def remember(path, source=None):
    raw = path.read_bytes()
    row = {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw), 'sha256': sha(raw)}
    if source is not None:
        row['source'] = str(source)
    files.append(row)

def copy_pin(source, target, digest=None, size=None):
    raw = source.read_bytes()
    if digest is not None:
        assert sha(raw) == digest
    if size is not None:
        assert len(raw) == size
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write(raw)
    assert target.read_bytes() == raw
    remember(target, source)

assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == BASE
delivery = SOURCE / 'EXTERNAL_DELIVERY_V27B.json'
assert sha(delivery.read_bytes()) == 'eb874e78f0d3078291eb52d45b715beaa3a363c45188578df2588fcbf3f23942'
d = json.loads(delivery.read_text(encoding='utf-8'))
assert d['public_sources_applied'] is False and d['overall_qualified'] is False
for row in d['files']:
    source = Path(row['path']); assert source.is_relative_to(SOURCE)
    copy_pin(source, TARGET / source.relative_to(SOURCE), row['sha256'], row['bytes'])
copy_pin(delivery, TARGET / delivery.name)
review = SOURCE / 'INDEPENDENT_SOURCE_API_REVIEW_V27B_FX.json'
assert sha(review.read_bytes()) == 'eaf681ae46356cc45d4f46fe1482d53f745d16d3d1a1a804035bceab3e1b20fd'
peer = json.loads(review.read_text(encoding='utf-8'))
assert peer['static_api_closure_passed'] is True and peer['native_qualified'] is False
assert peer['root_applied'] is False and peer['engine_started'] is False
copy_pin(review, TARGET / review.name)
historical_review = SOURCE / 'INDEPENDENT_SOURCE_API_REVIEW_V27_FX.json'
if historical_review.exists():
    copy_pin(historical_review, TARGET / historical_review.name)
for name in ['campaign.gd', 'battle.gd']:
    assert (ROOT / 'scripts' / name).read_bytes() == (SOURCE / 'original/scripts' / name).read_bytes()
copy_pin(Path(__file__), QA / 'harness' / Path(__file__).name)
for row in json.loads((QA / 'night_restore_tool_preparation_delivery_v25x17.json').read_text(encoding='utf-8'))['files']:
    path = ROOT / row['path']; assert sha(path.read_bytes()) == row['sha256']; remember(path)
remember(QA / 'night_restore_tool_preparation_delivery_v25x17.json')

note = ('<!-- campaign-proposal-v27x1 -->\n'
        '## 2026-10-08 05:12：战役真实保存回读收据提案完成源码审查\n\n'
        '新的v27b外部候选已完成Campaign/Battle两文件实现与独立源码/API审查，'
        '原best单局/no union、旧QA内存语义和Steam当局结算保持。候选将逻辑accepted、memory_applied、'
        '真实save+全新ConfigFile完整语义回读的persisted、QA suppressed分开；'
        '坏既有cfg/不支持数据写前拒绝，写后读回失败明确disk_state_unconfirmed而不声称回滚。'
        'Cloud callback在candidate内存安装后请求，不等于上传确认。\n\n'
        '当前仅源码提案，未应用Root、未运行Godot解析/真实磁盘/19条故障矩阵。'
        '玩家失败提示、pending锁/安全重试、终局gen2→cfg→ack与跨进程故障恢复仍未实现，'
        '不可当作战役持久恢复验收完成。当前提案目录为qa/zhu_wounded_20261005/proposals/'
        'campaign_persistence_observability_v27，使用proposed_b及V27B文档，oldff与原版证据保留。\n\n'
        '当前没有本线程原生后台；单人撤离两生产候选仍未资格。收尾精确双文件复原工具r2已独立静态审查，'
        '只可在22UTC后重新核最新71d终态、无own进程与全部字节条件后执行；目前未复原。'
        '完整剩余计划与06:00最终同步不变，公司续做先看[OFFICE_START_20261008.md](OFFICE_START_20261008.md)。\n\n')
short = ('<!-- campaign-proposal-v27x1 -->\n'
         '## 2026-10-08 05:12：下一计划项源码提案\n\n'
         'Campaign真实保存回读收据v27b已实现并独立源码/API审查；仅存QA提案，未应用/未native。'
         '19条故障、玩家失败UI和跨进程故障恢复仍待完成。详细当前结果与全部剩余顺序见 '
         '[NIGHT_PROGRESS_20261008.md](NIGHT_PROGRESS_20261008.md)。06:00按实际状态最终收尾。\n\n')
for name in ['WORKLOG.md', 'SOURCE_SETUP.md', 'PROJECT_STATUS.md', 'DEVELOPMENT_PLAN.md',
             'DIRECTORY_INDEX.md', 'HANDOFF_20261007_OFFICE.md', 'DEVELOPMENT_AUDIT_20261007.md']:
    p = ROOT / 'docs' / name; old = p.read_bytes(); assert b'campaign-proposal-v27x1' not in old
    p.write_bytes((note if name in ['WORKLOG.md', 'HANDOFF_20261007_OFFICE.md',
                                  'DEVELOPMENT_AUDIT_20261007.md'] else short).encode('utf-8') + old)
    remember(p)
p = ROOT / 'docs/OFFICE_START_20261008.md'
s = p.read_text(encoding='utf-8-sig'); title, body = s.split('\n', 1)
p.write_text(title + '\n\n<!-- campaign-proposal-v27x1 -->\n'
             '下一计划项已备妥：v27b保存回读收据代码与独立源码审查存QA proposals/campaign_persistence_observability_v27。'
             'current=proposed_b，未native/未Rootapply。公司先建立新基线，再做19条真实ConfigFile故障验收；'
             '它不代替单人撤离完整负例/终局与日志持久恢复。收尾工具r2静态闭合，仍待06:00实际门槛和执行。\n' + body,
             encoding='utf-8', newline='\n')
remember(p)
p = ROOT / 'docs/NIGHT_PROGRESS_20261008.md'
s = p.read_text(encoding='utf-8-sig').replace('本页更新到04:36终态；', '本页更新到05:12源码提案；')
anchor='| 公司普通启动 |'
assert s.count(anchor) == 1
s = s.replace(anchor, '| Campaign保存回读收据v27b | 两文件源码提案与独立API审查完成；未应用/未解析/19故障未执行 | `campaign_observability_source_delivery_v27x1.json` |\n' + anchor)
s += '\n保存回读提案 current 为 `proposals/campaign_persistence_observability_v27/proposed_b`；只补保存结果可观察性。玩家失败UI、pending锁/安全重试、跨进程恢复仍是后续要求。\n'
p.write_text(s, encoding='utf-8', newline='\n'); remember(p)
out = QA / 'campaign_observability_source_delivery_v27x1.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump({'schema': 'campaign_observability_source_delivery_v27x1',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'base_commit': BASE, 'files': files, 'current_candidate': 'proposed_b',
               'independent_static_API_closure_passed': True, 'production_applied': False,
               'native_parse_executed': False, 'fault_cases_executed': 0, 'fault_cases_planned': 19,
               'durable_campaign_progress_qualified': False, 'restoration_executed': False,
               'engine_started_by_collector': False}, handle, ensure_ascii=False, indent=2)
remember(out)
assert len(files) == len({row['path'] for row in files})
with Path('E:/ChatGPT/campaign_observability_sync_v27x1_manifest.json').open('x', encoding='utf-8') as handle:
    json.dump({'base': BASE, 'branch': 'codex/sync-20260905-stable',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'files': files, 'qualified_runtime_paths': [],
               'scope': 'Reviewed source-only persistence observability proposal, conditional restoration preparation and complete office next-step handoff; no production/native qualification added.'},
              handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'production_applied': False, 'native_qualified': False}))
