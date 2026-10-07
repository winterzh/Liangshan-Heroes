from pathlib import Path
import datetime, hashlib, json, subprocess

ROOT = Path('E:/ChatGPT/水浒')
SOURCE = Path('E:/ChatGPT/daming_safe_retreat_v25_proposal')
OFFICE = Path('E:/ChatGPT/office_handoff_review_20261008')
QA = ROOT / 'qa/zhu_wounded_20261005'
TARGET = QA / 'proposals/daming_safe_retreat_v25'
BASE = '265688901375589bbadaed7b45d6853594fd7ce4'
BRANCH = 'codex/sync-20260905-stable'
files = []

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()

def remember(path, source=None):
    raw = path.read_bytes()
    row = {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw), 'sha256': digest(raw)}
    if source is not None:
        row['source'] = str(source)
    files.append(row)
    return row

def copy_exact(source, target, expected=None):
    raw = source.read_bytes()
    if expected is not None:
        assert digest(raw) == expected, str(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert target.read_bytes() == raw, str(target)
    else:
        with target.open('xb') as handle:
            handle.write(raw)
    assert target.read_bytes() == raw
    return remember(target, source)

def prepend(path, content):
    old = path.read_bytes()
    assert 'office-prefix-v25x6' not in old.decode('utf-8-sig')
    path.write_bytes(content.encode('utf-8') + old)
    remember(path)

assert git('branch', '--show-current') == BRANCH
assert git('remote', 'get-url', 'origin') == 'https://github.com/winterzh/Liangshan-Heroes.git'
assert git('rev-parse', 'HEAD') == BASE
assert not git('diff', '--cached', '--name-only')
delivery = json.loads((SOURCE / 'EXTERNAL_DELIVERY_V25S_R2D_R2E.json').read_text(encoding='utf-8'))
for row in delivery['files']:
    source = Path(row['path'])
    assert source.parent == SOURCE and len(source.read_bytes()) == row['bytes']
    copy_exact(source, TARGET / source.name, row['sha256'])
for name in ['EXTERNAL_DELIVERY_V25S_R2D_R2E.json', 'PREFIX_C_REVIEW_V25S_R2D_FX.json',
             'PREFIX_C_STARTED_8F3D393D_FX.json', 'PREFIX_C_STARTUP_DATE_REJECTION_FX.json',
             'FULL_REUSE_REVIEW_V25S_R2E_FX.json', 'FULL_REUSE_REVIEWED_READY_V25S_R2E.json']:
    copy_exact(SOURCE / name, TARGET / name)
for name in ['OFFICE_START_NEXT.md', 'OFFICE_START_NEXT_R1.md',
             'READ_ONLY_OFFICE_PORTABILITY_REVIEW.json', 'OFFICE_START_CORRECTION_R1.json']:
    copy_exact(OFFICE / name, QA / 'proposals/office_handoff_review_20261008' / name)
office = OFFICE / 'OFFICE_START_NEXT_R1.md'
assert digest(office.read_bytes()) == '15b7bb51bbbd5eb322ae7d97b1d877abd0f599894e9ecda535604fe565a864db'
assert b'\r' not in office.read_bytes() and b'\t' not in office.read_bytes()
copy_exact(office, ROOT / 'docs/OFFICE_START_20261008.md')
copy_exact(Path(__file__), QA / 'harness' / Path(__file__).name)

short = ('<!-- office-prefix-v25x6 -->\n'
         '## 2026-10-08 公司续做入口\n\n'
         '先读 [公司启动与下一步](OFFICE_START_20261008.md)。正常启动、已验证生产四文件、'
         'QA 两份未验证候选和不可跨机复用的旧批次分别说明。新恢复批 8f3d393d 已启动并冻结工程，'
         '此条仅记录启动状态；实际原生结果以本次最终收据为准。完整开发计划继续保留。\n\n')
for name in ['SOURCE_SETUP.md', 'PROJECT_STATUS.md', 'DEVELOPMENT_PLAN.md', 'DIRECTORY_INDEX.md']:
    prepend(ROOT / 'docs' / name, short)
detail = ('<!-- office-prefix-v25x6 -->\n'
          '## 2026-10-08 03:35：恢复入口启动与公司续做准备\n\n'
          '新 r2d/run8f3d393d 已由本线程唯一观察者启动，Python220144，私有冻结阶段完成。'
          '严格回读原失败批 source6、私有5102、28证据和五个完整前序文件后，只复制到新profile；'
          '仍须实际 C342 与双方真实单人撤离 A，未宣称新的原生通过或 v25 整体资格。'
          '原run07ad37bf/producer/失败profile不改。准备与启动证据见 '
          '`qa/zhu_wounded_20261005/safe_retreat_prefix_preparation_delivery_v25x5.json` '
          '及 proposals/daming_safe_retreat_v25 的 PREFIX_C_STARTED_8F3D393D_FX.json。\n\n'
          'r2e 完整复用入口已独立静态闭合，继承 r2b2/e61 修正后的三消费者；'
          '缺真实双方A闭合证明时前置阻断、不创建原生批。全部52负例和双方BCD保留，'
          '不能用A探索代替自然终止、完整负例或Campaign真实写盘。两份生产候选仍仅本地未验证，'
          '不纳入生产提交。首次启动器日期转换被前置拒绝，原输出另存，随后保留原ISO字符串启动；'
          '原producer/审查未修改。\n\n'
          '公司最新简明入口为 [OFFICE_START_20261008.md](OFFICE_START_20261008.md)：'
          '正常Godot/原生依赖启动可用；旧QA物理缓存、固定今晚截止和同机时钟不能迁移，'
          '公司新批需建立本机基线与新后继。原稿两处路径控制字符已另存更正记录并修成原样命令，'
          '未执行文档里的公司命令。仍于香港06:00按实际结果收尾、逐文件同步，'
          '所有后续计划保留。\n\n')
for name in ['WORKLOG.md', 'HANDOFF_20261007_OFFICE.md', 'DEVELOPMENT_AUDIT_20261007.md',
             'DAMING_SAFE_RETREAT_DESIGN_20261008.md']:
    prepend(ROOT / 'docs' / name, detail)
prepend(ROOT / 'README.md', '<!-- office-prefix-v25x6 -->\n## 2026-10-08 公司继续开发\n\n'
        '最新启动与续做顺序见 [公司续做入口](docs/OFFICE_START_20261008.md)，'
        '详细阶段证据见 [办公室交接](docs/HANDOFF_20261007_OFFICE.md)。\n\n')

previous = json.loads((QA / 'safe_retreat_prefix_preparation_delivery_v25x5.json').read_text(encoding='utf-8'))
for row in previous['files']:
    path = ROOT / row['path']
    assert digest(path.read_bytes()) == row['sha256']
    if row['path'] not in {entry['path'] for entry in files}:
        remember(path)
remember(QA / 'safe_retreat_prefix_preparation_delivery_v25x5.json')
receipt = {'schema': 'office_prefix_source_sync_preparation_v25x6', 'base_commit': BASE,
           'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'files': files, 'production_candidates_committed': False,
           'new_native_success_claimed': False, 'overall_v25_qualified': False,
           'engine_started_by_collector': False, 'office_commands_executed': False}
out = QA / 'office_prefix_source_sync_preparation_v25x6.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump(receipt, handle, ensure_ascii=False, indent=2)
remember(out)
manifest = {'base': BASE, 'branch': BRANCH,
            'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'files': files, 'qualified_runtime_paths': [],
            'scope': 'Office startup handoff, immutable recovery preparation and actual startup evidence; two unqualified runtime candidates excluded.'}
assert len(files) == len({row['path'] for row in files})
with Path('E:/ChatGPT/office_prefix_sync_v25x6_manifest.json').open('x', encoding='utf-8') as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'manifest': 'E:/ChatGPT/office_prefix_sync_v25x6_manifest.json',
                  'overall_v25_qualified': False}))
