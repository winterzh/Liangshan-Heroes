# 公司本机继续开发（2026-10-08）

## 新完整执行器当前入口

V1—V3独立失败审查保留；V4实际JSON533/OwnedSlot76通过，但A启动前竞争导致整批失败退出，锁已释放。V5只在尚无自有子进程时释放锁重等自然空闲，启动后原失败策略不变，用户授权独立复审通过。当前唯一新批office_full_8499098a/PID37484已启动；必须按它的真实后续终态判断。执行器要求 `--source-bridge`，独立review同时绑定producer/preparation/source-bridge三个SHA，两端5132项runtime/50QA及实际基线核对保持。[新审查与启动QA](../qa/office_campaign_full_20261008/README.md)。以下首轮准备描述保留当时状态。

完整目标仍为 `DEVELOPMENT_PLAN.md` 和 `DEVELOPMENT_AUDIT_20261006.md` 的全部未完成项。

## 当前实际结果

- 基线源码为 GitHub stable `31354faccba96cd638bd02e68b7d510ecd9a3893`。本机原工作分支名仍为 `codex/classic30-closeout-20260924`；旧本地 stable 分叉保留，收尾只按明确 refspec 同步远端既定 stable。
- 官方 Godot `4.6.3.stable.official.7d41c59c4` 的源码导入、正常主场景180帧启动、真实1280×720菜单绘制均实际终态0、错误0。5031份已有输入前后SHA不变；实际菜单截图已目检。新用户目录与玩家档案隔离。
- 生成的资源侧车和UID留在本机；本轮不将它们与已通过旧机器的来源身份混同。已按本机实际字节复制到新候选并建立来源清单；既有UID的LF/CRLF差异仅在候选中精确对齐，原字节备份保留。
- 源码启动工具为 `tools/run_workstation_baseline.py`。首个PowerShell中间进程导入因归属观察中止，失败原记录保留。后继直接绑定真实Godot进程，完成导入、正常入口和图形视口。
- 工程外独立Git候选 `D:/CodexTemp/lsh-office-candidate-20261008` 基于同一提交；只装入原提案Core/UnitContract两份改动，正式工程这两文件未变。原四文件JSON修复按SHA核对保持。
- 原完整消费者及其已完成独立静态审查按不可变SHA回读。本机新执行器的Python AST与只读预检通过；新执行器独立审查待完成，原生完整矩阵尚未启动、未通过。

原始记录见 [QA](../qa/office_baseline_20261008/README.md)。

## 完整续玩新执行器

`tools/run_office_campaign_restore_qa.py` 导入四份SHA固定的旧消费者模块，仅继承原JSON/OwnedSlot/ABC/双角色ABCD和完整负例验证方法。新本机类重新建立源码/引擎/原生依赖/私有profile/当前runtime身份，未修改旧producer、原失败、旧deadline或固定矩阵。

始终保留：JSON11案533项、OwnedSlot76项、办理半程三个真实独立进程39/351/342、两角色的world264/component362/live24，双方自然ABCD、新进程旧槽拒绝及合计52负例进程。最后的全矩阵终态、日志、来源、私有profile与原生依赖审计仍执行；准备或单阶段成功不关闭完整资格。

旧JSON Node场景未归档，本机准备工具明确记录缺失，并生成一个新的 `Node` 场景绑定原字节GD。新场景SHA与来源归档单独登记，必须纳入新执行器的独立审查；不伪称旧场景回读成功。

完整执行需要：

1. 本机已完成基线收据 `--baseline`，引擎SHA与该收据一致；真实稳定4.6.3版本取原生报告，不在共享引擎占用时另起version进程。
2. 新执行器独立审查 `--independent-review`：schema为 `office_campaign_restore_independent_review_v1`，`independent=true`、`static_api_closure_passed=true`、`approved_stages=["full"]`，精确绑定当前producer和preparation SHA。旧A-only审查不能替代，新工具不自动写批准文件。
3. 本次新的有界 `--deadline-utc`；它仅控制这次测试批的结束，不缩小完整开发目标。旧06:00截止和旧物理E盘cache/profile/PID不复用。
4. 新UUID私有运行目录。每个原生阶段前持续自然空闲60秒，完整源码/私有输入/原生依赖守卫；自有子进程启动前竞争只释放自己的锁并重等，启动后其它Godot恢复占用仍终止自己整批并保留失败。

只读预检示例：

```powershell
python -X utf8 -B tools/run_office_campaign_restore_qa.py --preparation D:/CodexTemp/lsh-office-candidate-preparation-20261008/preparation.json --source-bridge D:/CodexTemp/lsh-office-candidate-preparation-20261008/complete_inputs_seal_v5.json --godot <本机Godot.exe>
```

加 `--run` 之前须具备上述实际收据和新审查。当前本机准备文件与侧车清单分别在 `D:/CodexTemp/lsh-office-candidate-preparation-20261008/`，Git归档副本见QA。原生包按生产vendor清单逐文件核验后供给候选；不上传vendor二进制、编辑器缓存、玩家/登录数据或导出包。

## 后续目标保持完整

完成新本机全链后再处理真实章节语义、正常非QA的进度持久写盘、19故障、失败UI/pending锁/安全重试及跨进程恢复；继续八关动态、生产/船体运输、自然胜败和奖励一次、全库美术与完整UI流程、同版九玩法发行程序、正常时钟约10分钟尾帧与切换清理、Android手机和平板实际验收。

本机普通启动通过不代表上述事项完成，也不开放战役玩家继续入口。每批修正、实际验证、交接及白名单源码同步按现行AGENTS执行。
