from pathlib import Path
import datetime, hashlib, json, subprocess

ROOT = Path('E:/ChatGPT/水浒')
QA = ROOT / 'qa/zhu_wounded_20261005'
PREP = Path('E:/ChatGPT/night_wrap_preparation_20261008')
TARGET = QA / 'proposals/night_wrap_20261008'
BASE = '4b2ac20edfb5f6737bc4e3e29712fecf3c56f9a8'
files = []

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def remember(path, source=None):
    raw = path.read_bytes()
    row = {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw), 'sha256': sha(raw)}
    if source is not None:
        row['source'] = str(source)
    files.append(row)

def copy_exact(source, target):
    raw = source.read_bytes(); target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write(raw)
    assert target.read_bytes() == raw
    remember(target, source)

assert datetime.datetime.now(datetime.timezone.utc) >= datetime.datetime(2026, 10, 7, 22, tzinfo=datetime.timezone.utc)
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == BASE
actual = PREP / 'ACTUAL_CANDIDATE_RESTORATION_R4.json'
restored = json.loads(actual.read_text(encoding='utf-8'))
assert restored['complete'] is True and restored['qualified_JSON4_unchanged'] is True
assert len(restored['restored_files']) == 2
assert all(row['restored'] and row['candidate_retained_in_QA'] and row['original_retained_in_QA']
           and row['original_backup_retained'] for row in restored['restored_files'])
for row in restored['restored_files']:
    raw = (ROOT / row['path']).read_bytes()
    assert sha(raw) == row['expected_restored_sha256']
    assert raw == subprocess.check_output(['git', 'show', 'HEAD:' + row['path']], cwd=ROOT)
for name in ['FINAL_AUDIT_FIRST_CIM_ENCODING_FAILURE_FX.json', 'FINAL_AUDIT_SECOND_CIM_CAPTURE_FAILURE_FX.json',
             'FINAL_OWNED_BACKEND_AND_INPUT_AUDIT_FX.json', 'RESTORE_TOOL_REVIEW_R3_FX.json',
             'RESTORE_TOOL_REVIEW_R4_FX.json', 'ACTUAL_CANDIDATE_RESTORATION_R4.json']:
    copy_exact(PREP / name, TARGET / name)
for suffix in ['r3', 'r4']:
    source = Path('E:/ChatGPT') / ('restore_unqualified_night_candidates_20261008_' + suffix + '.py')
    copy_exact(source, TARGET / source.name)
copy_exact(Path(__file__), QA / 'harness' / Path(__file__).name)
remember(TARGET / 'NIGHT_FINAL_LEDGER_PREPARATION.json')

summary = ('<!-- night-final-20261008 -->\n'
           '## 2026-10-08 06:02：本夜开发截止收尾\n\n'
           '已到香港06:00，停止启动新开发批。所有本线程原生后台均真实终态；'
           '新六文件单人撤离候选未完成C/双方A/完整负例及BCD，整体资格仍false。'
           '最后71d4275a原生导入因共享Godot恢复占用退出1，锁已释放；'
           '原failures/profile/五个前序文件全部保留。原四文件JSON修复及限定办理半程ABC资格保留。\n\n'
           '06:02实际执行精确最新终态绑定的r4工具，逐文件复原本线程Core/UnitContract两份未资格生产候选；'
           '当前before逐字节等于备份/QAoriginal/HEAD，QA proposed与备份完整，JSON四文件SHA不变。'
           '没有reset/stash、没有控制其它任务或删除失败数据。原r3编码与自匹配阻断、两次只读审计采集失败'
           '均保存为独立记录，r4只排除本工具exact自身PID。\n\n'
           'Campaign真实保存回读v27b两文件提案与独立源码/API审查已存QA，current=proposed_b；'
           '未应用生产、未native解析、19条故障未执行。玩家失败UI、pending锁/安全重试、'
           '章节日志/终局gen2→cfg→ack与跨进程故障恢复仍未完成。'
           '完整动态/付费生产/船体运输、自然胜败奖励、九玩法发行程序、美术UI多尺寸、'
           '正常时钟长跑性能及Android真机计划全部保留。\n\n'
           '公司从 [OFFICE_START_20261008.md](OFFICE_START_20261008.md) 继续；'
           '最终实际结果见 [NIGHT_PROGRESS_20261008.md](NIGHT_PROGRESS_20261008.md) '
           '及qa/zhu_wounded_20261005/night_final_wrap_delivery_20261008.json。'
           '本收尾只源码/QA/文档同步stable，不发布新Steam/Android、不合并main。'
           '最终推送独立回读后暂停一次性心跳6，再关闭本夜有界任务；这些调度操作另以实际收据为准。\n\n')
for name in ['WORKLOG.md', 'SOURCE_SETUP.md', 'PROJECT_STATUS.md', 'DEVELOPMENT_PLAN.md',
             'DIRECTORY_INDEX.md', 'HANDOFF_20261007_OFFICE.md', 'DEVELOPMENT_AUDIT_20261007.md',
             'DAMING_SAFE_RETREAT_DESIGN_20261008.md']:
    path = ROOT / 'docs' / name; old = path.read_bytes(); assert b'night-final-20261008' not in old
    path.write_bytes(summary.encode('utf-8') + old)
    remember(path)

office = ROOT / 'docs/OFFICE_START_20261008.md'
old_office = office.read_text(encoding='utf-8-sig')
body = old_office[old_office.index('## 1. 确认代码与本机入口'):]
body = body.replace('两份未资格提案在', '两份未资格生产候选已于本夜收尾逐文件复原；完整提案仍在')
body = body.replace('最新 r2e 继承实际 e61 全链，已静态 peer；因尚缺真实 A 来源仍为 blocked，不能称公司可直接运行。',
                    '最新r2e1继承e61完整链并只扩展精确r2f来源，已静态peer；r2f实际import中断、C和双方A缺失，因此真实proof不存在、full未启动，公司不能直接复用今夜入口。')
body += ('\n## 5. 已准备的下一计划项\n\n'
         '保存结果可观察性的v27b代码与独立源码/API审查在 '
         '`qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27/`，'
         'current=`proposed_b`。先完成本机基线，再实现/运行19条真实ConfigFile故障矩阵；'
         '该提案未应用生产，未解析/native/真实写盘验收，不能当作完整持久恢复。'
         '失败UI、pending锁与安全重试、真实章节context、终局intent/ack和跨进程恢复继续在完整计划内。\n')
office.write_text('# 公司电脑续做入口（2026-10-08最终交接）\n\n'
                  '本夜已于香港06:00截止开发并完成两份未资格生产候选的精确复原。'
                  'stable保留已通过限定原生验证的四文件JSON修复；完整候选和全部失败证据存QA，'
                  '单人撤离完整验收、自然终局/持久进度及其它原计划仍未完成。'
                  '没有本线程运行中的原生后台。具体最终推送SHA以独立远端收据为准。\n\n' + body,
                  encoding='utf-8', newline='\n')
remember(office)

progress = ROOT / 'docs/NIGHT_PROGRESS_20261008.md'
s = progress.read_text(encoding='utf-8-sig')
s = s.replace('本页更新到05:12源码提案；06:00最终交接会按实际后台终态更新。',
              '本页记录06:02实际收尾：原生后台已终态，未资格两生产候选已精确复原，QA候选/备份/失败证据保留。')
s = s.replace('完整代码和原字节备份已保留在QA；尚未取得完整新候选资格',
              '完整代码和原字节备份保留在QA；未取得完整资格，已实际复原两生产文件至HEAD原字节')
start = s.index('到香港时间06:00不启动新开发批。')
s = s[:start] + ('已于香港06:00停止启动新开发批，06:02在当前无本线程消费者、最新71d失败收据及全部SHA门槛成立后，'
                 '用受审r4逐文件复原Core/UnitContract；before等于HEAD/备份/QAoriginal，'
                 'candidate仍存QA，JSON四文件不变。实际收据见 '
                 '`qa/zhu_wounded_20261005/proposals/night_wrap_20261008/ACTUAL_CANDIDATE_RESTORATION_R4.json`。\n\n'
                 '本夜最终同步只源码/QA/文档，不新发布Steam/Android、不合并main。公司继续须建立新机器基线和新截止后继，'
                 '不能复用今夜固定截止、同机时钟和物理缓存。完整开发计划继续开放，保存回读v27b仅源提案，'
                 '其19故障/玩家失败UI/pending重试/跨进程故障恢复仍待完成。\n')
progress.write_text(s, encoding='utf-8', newline='\n'); remember(progress)

out = QA / 'night_final_wrap_delivery_20261008.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump({'schema': 'night_final_wrap_delivery_20261008',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'authorized_deadline_utc': '2026-10-07T22:00:00+00:00', 'deadline_reached': True,
               'base_commit': BASE, 'files': files, 'owned_backends_terminal': True,
               'runtime_candidates_exactly_restored': True, 'candidate_QA_preserved': True,
               'qualified_JSON4_unchanged': True, 'overall_v25_qualified': False,
               'v27b_production_applied': False, 'v27b_native_qualified': False,
               'original_remaining_plan_preserved': True, 'new_engine_started': False,
               'steam_or_android_published': False, 'final_push_readback_pending': True,
               'heartbeat6_pause_pending': True, 'bounded_goal_complete_claimed': False},
              handle, ensure_ascii=False, indent=2)
remember(out)
assert len(files) == len({row['path'] for row in files})
with Path('E:/ChatGPT/night_final_sync_20261008_manifest.json').open('x', encoding='utf-8') as handle:
    json.dump({'base': BASE, 'branch': 'codex/sync-20260905-stable',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'files': files, 'qualified_runtime_paths': [],
               'scope': 'Actual deadline wrap, exact two-file restoration evidence and final office handoff. Runtime restored to HEAD; candidates retained in QA.'},
              handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'restoration_complete': True, 'final_push_pending': True, 'heartbeat_pause_pending': True}))
