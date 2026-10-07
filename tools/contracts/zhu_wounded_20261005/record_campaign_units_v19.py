"""Record actual original Unit graphs, native compact snapshots and scoped qualification."""
from pathlib import Path
import hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';QA=ROOT/'qa/zhu_wounded_20261005'
CASES=['level5 initial','level5 Liu embarked','level5 wave sent','level8 initial','level8 exposed scout','level8 gate open rescued','level8 paid support dying']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    locator=json.loads((BASE/'campaign_units_v19c_run.json').read_text(encoding='utf-8'));run=Path(locator['run']);rp=run/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and r['private_runtime_patches']==r['root_input_drift']==r['private_input_drift']==0
    assert r['unit_graph_qualified'] and r['result']['passed'] and not r['full_world_qualified'] and r['result']['checks']>=250
    assert len(r['source_files'])==5038 and [x['case'] for x in r['result']['runtime']]==CASES
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    log=run/'skills.log';text=log.read_text(encoding='utf-8');assert '[rts] FAIL' not in text and 'SCRIPT ERROR:' not in text
    for label in CASES:
        assert '[rts] PASS '+label+' exact complete Unit and Level payload preserved' in text
    p=QA/'campaign_units_qualified_v19c.json';assert not p.exists();shutil.copy2(rp,p)
    p=QA/'campaign_units_verified_log_v19c.txt';assert not p.exists();shutil.copy2(log,p)
    directory=QA/'campaign_units_native_snapshots_v19c';directory.mkdir(exist_ok=False);snapshots=[]
    for row in r['result']['runtime']:
        source=Path(row['snapshot_path']);assert sha(source)==row['snapshot_sha256']
        snapshot=json.loads(source.read_text(encoding='utf-8'));assert snapshot['source_graph']['schema']==('level5_unit_graph_v1' if row['chapter']=='level5' else 'level8_unit_graph_v1')
        assert len(snapshot['source_graph']['records'])==row['units']
        p=directory/source.name;shutil.copy2(source,p);assert sha(p)==sha(source)
        snapshots.append({'case':row['case'],'chapter':row['chapter'],'units':row['units'],'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
    review={'passed':True,'receipt_sha256':sha(rp),'log_sha256':sha(log),'checks':r['result']['checks'],'inputs':5038,'cases':snapshots,
      'scope':r['scope'],'full_world_qualified':False,'full_goal_qualified':False,'platform_released':False,
      'findings':['Actual original actors preserve health, position, art/story identity, full Unit/Level payload and root/active order after native state construction and new-reference binding in all seven cases.',
      'Gao root definition key kind/order/value is preserved, including native StringName; new explicit key entry wire only in level5 Unit schema. Shared bounded codec and old chapter schemas unchanged.',
      'Original paid60wood Liu embark, water/land wave orders, disguise break, authored gate/prison rescue and paid support/death transitions are explicit contact/stage fixtures; not natural campaign success.',
      'Daming workers refer to fresh actual mineral Units; malformed/false mineral IDs and missing active captive membership rejected; valid expired reference binds to owned released tombstone. Duplicate Gao wave slots rejected.',
      'Detached disabled owner/map shell and saved Node flag replay prevent _ready/physics. No root/map/scenery/clock/Mission/FX or independent-process world qualification.'],
      'next':'Complete native Liangshan/Daming scenery, lighting/passages and map, visual partition, battle root/core and delayed Mission button binding; actual independent save/exit/continue/resave, natural endings/reward once and full plan remain required.'}
    p=QA/'campaign_units_review_v19c.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    body=f'''<!-- campaign-units-v19c-current -->
## 2026-10-07 两关真实Unit图/矿点引用/船体定义复验通过

level5/8专属Unit契约和图schema已本地接入。原高太尉波次/登船、船体/押俘角色，大名府乔装/俘虏/工人与矿点按实际关卡声明校验；高太尉角色/波次不接受重复槽位，大名府死亡援军虽被原调度器移出池仍保留正在死亡的源lane。daming_mine只在level8按entity/expired/none标签保存，完整注册表建立后绑定新对象，不把旧世界Object或保存标签留给游戏逻辑。

当前正式生产脚本复制、零私有运行时补丁、正常时钟1.0：{r['result']['checks']}项通过、5038来源零漂移，7原章状态（Gao初态/付60木刘唐登船/波次已发，Daming初态/暴露/开门救人/付费援军死亡）。原Unit全部值与引用实例化、注册表绑定后再次捕获，完整Unit/Level payload一致；两个工人矿点指向新矿点，失效标签由本任务tombstone绑定/释放；未知或伪矿点、重复波次和遗漏活体俘虏成员拒绝。证据campaign_units_qualified_v19c.json、campaign_units_verified_log_v19c.txt、campaign_units_review_v19c.json和7紧凑原生快照。

保留实际v19b失败：83项/3失败，Gao定义键StringName虽已通过Unit定义规则但通用Codec不支持，大名府初态61真Unit精确重建通过后误调测试_spy_tick。v19c修正新level5 Unit wire，按有界条目保留String/StringName键类型、顺序和值；旧Unit schema/公共Codec未改，测试改用原_cover_tick。原producer/失败报告、导入前取消v19和准备工具失败记录均保留，不改写为通过。

脱离场景树的禁用owner/map空壳、保存Node旗标重放、接触和阶段调度均为明确夹具；已证明真实Unit字段与引用恢复，**未证明地图/场景/灯光/FX/时钟/完整Mission/跨进程世界恢复或自然通关**。下一阶段完成原梁山/大名府场景、灯光/通道/地图、表现分区、root/core及Gao按钮延后绑定，再实际保存、退出、独立进程继续/再保存、自然结局/奖励一次。公开战役继续仍关闭；全项目人物拥挤/连续演出、同版九玩法/发行程序、性能/切换清理、Android真机门槛继续。

当前源码/证据/属性与七份交接尚待本轮白名单同步；上一远端e1d546d0。未新增清理或平台发布。
<!-- /campaign-units-v19c-current -->

'''
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8');s,n=re.subn(r'<!-- campaign-units-v19c-pending -->.*?<!-- /campaign-units-v19c-pending -->\s*','',s,count=1,flags=re.S);assert n==1
        p.write_bytes((body+s).encode('utf-8'))
    print(json.dumps({'checks':r['result']['checks'],'cases':7,'inputs':5038,'native_snapshots':7,'full_world_qualified':False}))
if __name__=='__main__':main()
