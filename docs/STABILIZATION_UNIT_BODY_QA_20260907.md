# Unit 未命名余量细分（2026-09-07）

本轮在原 `c0285f91d4131e7631707fa59903d4b61fd460bb` 完整 M1 基线的私有源码上完成了 33 范围诊断。没有使用后续 Git HEAD 冒充受测版本，没有改生产、规则、RNG 或 60 Hz 配置；没有采用性能优化。

## 范围与验证

`scratchpad/stabilization_unit_body_20260907/` 的准备工具将 `_phys_body` 划为 8 个连续内联段，15 个外层提前返回均先关闭当前段。`_dust.filter` 的闭包 return 保持原样。另加入 9 个此前未单独测量的方法范围，原有 16 范围只用于排除已经命名的嵌套工作。共 4 个生产脚本派生，转换可逐字节反向还原。

独立审阅确认连续范围、返回处理和嵌套规则。发现并修正了 launcher 在检查允许目录之前写执行快照的问题：现在先对原路径检查 reparse/link，再 resolve 并检查专属私有根，所有读写前完成；也拒绝覆盖已有原生尝试。`unit_body_20260907_r1` 仅准备/预检，没有启动原生测试；修复后另建 `unit_body_20260907_r2`，未改写前一副本。

R2 import、timed、clockless 均 exit 0，严格日志无错误；真实玩家未变、无遗留 Godot、共享锁释放。timed 597 物理步、clockless 601 物理步均无缺漏，呈现间隔与同轮 M1 时钟逐项一致。每步根调用数等于 entry 段次数，后续段次数单调不增；每次 enter 恰有一次 leave（hooks=2×calls）；timed 每步所有 exclusive 之和等于根 inclusive。clockless 不含计时，守恒字段为 null。

## 实测成本及观测限制

所有值均为本次插桩结果的每物理步均值，不是生产绝对成本或可回收收益。

| 范围 | inclusive ms/步 | exclusive ms/步 |
| --- | ---: | ---: |
| `_phys_body` 根 | 7.274 | 1.409 |
| 动画、尘粒、命中段 | 1.099 | 0.517 |
| 入口、建筑、死亡段 | 0.651 | 0.408 |
| `_gameplay_rng_fault`（只计根内部调用） | 0.344 | 0.344 |
| 回复段 | 0.475 | 0.308 |
| 行为分派段 | 2.412 | 0.302 |
| 弹出/目标段 | 0.401 | 0.287 |
| `_queue_motion_redraw` | 0.346 | 0.275 |
| 技能/物品段 | 0.446 | 0.268 |
| 状态倒计时段 | 0.289 | 0.254 |
| 卡住看门狗段 | 0.093 | 0.083 |
| `_spawn_dust` | 0.0067 | 0.0067 |

timed 共 3656710 次记录钩子，记录器 enter/leave 内可观测的账本操作约 3.013 ms/步；这还不包含全部钩子调用、额外计时、根外被包装方法的成本。它与表中范围重叠，不能相减来推算生产耗时。根 exclusive 中也包含新增内联段记录操作，不能当成下一块未定位的生产成本。

记录器已明显影响这组观察：timed 的 10.002188 秒真实窗口完成 9.95 模拟秒、246 呈现帧，诊断 FPS 24.59；clockless 完成 10.016667 模拟秒、312 呈现帧，诊断 FPS 31.19。这两个值不作为游戏性能，不替代正常 M1，也不能互相相减算收益。原有效的正常 15 窗口基线仍在 `qa/stabilization_performance_20260907/`。

## 首个小型 A/B 假设

动画/尘粒段是此次最大的新命名余量。可先验证把 `_dust.filter(func(d): return d.t > 0.0)` 改为显式筛选循环，尝试移除匿名 Callable 的创建/调用。保持先完成所有尘粒递减、再筛选两遍处理，仍创建新 Array，保持元素对象与顺序；不得融合递减与筛选，因为重复 Dictionary 引用可能改变过期边界结果。

单独 filter 的成本尚未测量，因此这个候选只有范围证据和较小改动面，没有收益证据。下一步先做纯数据/边界/重复引用与 RNG 等价回归，再按主任务安排做同机固定据守的正常 60 秒三对交替 A/B。若压力段没有可信改善就停止，不直接投入五组全矩阵。健康检查的逐调用故障语义保持不变；生成尘粒本身只占约 0.0067 ms/步，不优化生成数量或 RNG。追击 fallback、建桶 fastpath、预加载路线继续停止。

## 证据与交付

`qa/stabilization_unit_body_20260907/` 保存 32 个原始结果/日志/截图/执行工具/准确插桩源码文件，约 7.14 MiB，另有摘要、SHA 归档清单与 `.gdignore`；不含缓存、profile 或完整生产副本。`native_r2/body_analysis.json` 是按原始观察数据验证覆盖和守恒后的分析，`native_r2/receipt.json` 是原生宿主收据。原始证据不改写。

```text
py -3 -B scratchpad/stabilization_unit_body_20260907/prepare.py --static-only
py -3 -B scratchpad/stabilization_unit_body_20260907/prepare.py --output <全新私有诊断目录>
py -3 -B scratchpad/stabilization_unit_body_20260907/run.py --prepared <该目录> --run
```

诊断 scratch 与 QA 根均有 `.gdignore`，避免普通工程扫描证据源码。公共文档、Git 提交与推送由主任务统一收尾。
