from pathlib import Path
import datetime, hashlib, json, subprocess
ROOT = Path('E:/ChatGPT/水浒')
QA = ROOT / 'qa/zhu_wounded_20261005'
SOURCE = Path('E:/ChatGPT/daming_safe_retreat_v25_proposal')
TARGET = QA / 'proposals/daming_safe_retreat_v25'
BASE = '4017b779bb8d0a85add5cc002b3d2460b4dab5da'
files = []

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def remember(path, source=None):
    raw = path.read_bytes()
    row = {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw), 'sha256': sha(raw)}
    if source is not None:
        row['source'] = str(source)
    files.append(row)

def copy_exact(source, target, expected=None):
    raw = source.read_bytes()
    if expected is not None:
        assert sha(raw) == expected
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert target.read_bytes() == raw
    else:
        with target.open('xb') as handle:
            handle.write(raw)
    assert target.read_bytes() == raw
    remember(target, source)

assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == BASE
delivery = SOURCE / 'EXTERNAL_DELIVERY_V25S_R2F_R2E1.json'
assert sha(delivery.read_bytes()) == 'eb1b0e3b84ab4787a7341517f8f1b025730b55fb83ab63e4233af8cb4faeda3b'
for row in json.loads(delivery.read_text(encoding='utf-8'))['files']:
    p = Path(row['path']); assert p.parent == SOURCE and p.stat().st_size == row['bytes']
    copy_exact(p, TARGET / p.name, row['sha256'])
for name in ['EXTERNAL_DELIVERY_V25S_R2F_R2E1.json', 'OFFLINE_PREPARE_REVIEW_V25S_R2F_FX.json',
             'OFFLINE_PREPARE_STARTED_71D4275A_FX.json', 'FOREIGN_GODOT_LIVE_CIM_20261007T2006_FX.json']:
    copy_exact(SOURCE / name, TARGET / name)
review = json.loads((SOURCE / 'OFFLINE_PREPARE_REVIEW_V25S_R2F_FX.json').read_text(encoding='utf-8'))
assert review['static_api_closure_passed'] is True and review['native_qualified'] is False
assert review['approved_stages'] == ['offline_prepare_then_prefix_C_both_A']
copy_exact(Path(__file__), QA / 'harness' / Path(__file__).name)
for row in json.loads((QA / 'second_prefix_interrupted_delivery_v25x9.json').read_text(encoding='utf-8'))['files']:
    p = ROOT / row['path']; assert sha(p.read_bytes()) == row['sha256']
    if row['path'] not in {entry['path'] for entry in files}:
        remember(p)
remember(QA / 'second_prefix_interrupted_delivery_v25x9.json')
remember(QA / 'night_wrap_restore_scope_review_v25x8.json')

note = ('<!-- offline-prepare-v25x10 -->\n'
        '## 2026-10-08 04:19：新离线准备入口已启动，待原生结果\n\n'
        '此前5284b47e也在import被共享引擎恢复占用中止，actual exit1、锁已释放，'
        '没有新C或双方撤离A；完整原失败证据见second_prefix_interrupted_delivery_v25x9.json。'
        '新的r2f/run71d4275a已唯一启动，Python206868；只把纯文件准备提前、合并相邻无写入的重复全树走读。'
        '原base约2.145GB独立复制、一次末尾完整Root/private5102/native9/QA9核验及所有native前后/空闲/lease/foreign守卫保留，'
        '真实import/guard/C342/bothA仍必须完成，目前没有新原生资格。\n\n'
        '原“每native约120秒全是空闲”措辞另存更正：连续空闲窗是60秒，其余主要为完整SHA守卫；'
        '准备优化收益尚未实测，不能称性能提升。新的r2e1仅准备接受r2f真实闭合来源，'
        '原942不改；当前缺实际C/bothA证明，full仍阻断。20:17只读CIM确证当次foreign是manghe工作树，'
        '不据此推断历史已退出PID身份，也未控制或消息其他任务。\n\n'
        '公司入口仍为 [OFFICE_START_20261008.md](OFFICE_START_20261008.md)。'
        '两生产候选仍未资格，不纳入生产提交；复原范围已独立预审但尚未执行，'
        '必须所有本线程后台真实终态且full仍false后才能逐文件回原。06:00按实际证据收尾，原开发计划完整保留。\n\n')
short = ('<!-- offline-prepare-v25x10 -->\n'
         '## 2026-10-08 04:19：最新恢复准备\n\n'
         '新r2f/run71d4275a已启动；纯文件准备提前，全部原生检查保留，暂无新资格。'
         '此前两次导入中断的完整证据均已保留。详细当前状态与公司入口见 '
         '[OFFICE_START_20261008.md](OFFICE_START_20261008.md)。完整计划继续保留。\n\n')
for name in ['WORKLOG.md', 'HANDOFF_20261007_OFFICE.md', 'DEVELOPMENT_AUDIT_20261007.md',
             'DAMING_SAFE_RETREAT_DESIGN_20261008.md', 'SOURCE_SETUP.md', 'PROJECT_STATUS.md',
             'DEVELOPMENT_PLAN.md', 'DIRECTORY_INDEX.md']:
    p = ROOT / 'docs' / name; old = p.read_bytes(); assert b'offline-prepare-v25x10' not in old
    p.write_bytes((note if name in ['WORKLOG.md', 'HANDOFF_20261007_OFFICE.md',
                                  'DEVELOPMENT_AUDIT_20261007.md', 'DAMING_SAFE_RETREAT_DESIGN_20261008.md'] else short).encode('utf-8') + old)
    remember(p)
p = ROOT / 'docs/OFFICE_START_20261008.md'
title, body = p.read_text(encoding='utf-8-sig').split('\n', 1)
p.write_text(title + '\n\n<!-- offline-prepare-v25x10 -->\n'
             '最新状态（04:19）：r2f/run71d4275a已启动，先做纯文件独立冻结，再按原守卫等待Godot。'
             '8f与5284两次导入中断都保留原证据，均未执行新C/双方撤离A。'
             '新准备入口的完整测试义务不变，暂无新native通过；r2e1全矩阵复用仍缺真实闭合A证明，'
             '不能称已完成。公司新机不能直接运行这些今夜固定截止/同机恢复入口。\n' + body,
             encoding='utf-8', newline='\n')
remember(p)
out = QA / 'offline_prepare_start_delivery_v25x10.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump({'schema': 'offline_prepare_start_delivery_v25x10',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'base_commit': BASE, 'files': files, 'new_run': 'daming_safe_retreat_v25s_r2f_offline_prefix_c_71d4275a',
               'new_native_success_claimed': False, 'overall_v25_qualified': False,
               'performance_improvement_measured': False, 'production_candidates_committed': False,
               'engine_started_by_collector': False, 'restoration_executed': False}, handle, ensure_ascii=False, indent=2)
remember(out)
assert len(files) == len({row['path'] for row in files})
with Path('E:/ChatGPT/offline_prepare_sync_v25x10_manifest.json').open('x', encoding='utf-8') as handle:
    json.dump({'base': BASE, 'branch': 'codex/sync-20260905-stable',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'files': files, 'qualified_runtime_paths': [],
               'scope': 'Exact failed import evidence, reviewed preparation successor/startup, corrected timing and office handoff; no new runtime qualification.'},
              handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'overall_v25_qualified': False}))
