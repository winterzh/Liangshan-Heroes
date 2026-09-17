# 刽子手基础动作与肖像 QA：2026-09-15

最终批次 `native/20260915_155056_7d7baaac/receipt.json` 为 complete=true。Godot 4.6.3、gl_compatibility、独立工程和玩家目录；原始输出保持字节不变。

| 验证 | 结果与范围 |
| --- | --- |
| 来源与切片 | 258项通过；8张原生RGBA动作图、32个独立姿态、透明区、前景完整核算、选用与退回区域、参考哈希与20份TRES |
| 原生角色检查 | 644项通过；四向真实移动、攻击伤害、受击、倒地及终态，姿态切换、关闭重复程序挥动、实际图鉴方向切换与新肖像来源 |
| 共享路由 | 8项通过；生产据守阵容54种、30波；检查文件对应和旧资源回退顺序，缺图覆盖门槛仍明确为false |
| 截图 | 27张原始PNG；代理逐图目检11张，见下方准确清单 |
| 本地证据回读 | `verify_evidence.py` 核对原始输出、冻结生产文件和肖像来源，结果写入validation_summary.json |

最终导入复用了上一轮的imported缓存；源码、脚本类缓存、玩家目录重新建立。首轮全新导入已成功，但其后导入描述符规范化触发源文件保护而停止，不能称最终批次为全新无缓存导入。最终receipt记录source_changes/private_source_changes为空，QA/驱动/引擎未变，进程结束且锁释放。

## 目检

本批最终图中已逐图查看：`unit_pose_matrix_1.png`、`unit_pose_matrix_2.png`、`unit_pose_matrix_3.png`、`codex_se.png`、`codex_sw.png`、`codex_ne.png`、`codex_nw.png`、`melee_ne.png`、`melee_nw.png`、`melee_sw.png`、`terminal_ne.png`。其余16张留作证据，没有冒称逐图目检。

矩阵展示全部32个独立姿态：四向面背可分，刀与肢体未被切片裁断，落地姿态保持朝向；实际图鉴新头像、移动和攻击同一身份，没有继续显示旧蒙面赤膊肖像。实际战斗截图确认新画稿和头像生效。图像为1440×960的放大QA视图，不等于1280×720或正常缩放的整局验收。

动作仍是低帧基础版：跨步/收步尚非完整左右腿交替，东北/西北的下劈收势刀尖位于侧下方，尚缺单独的前方接触及过渡帧。伤害触发通过不能证明刀刃逐像素接触目标；上述两项列为下一轮动画细化。未追加真人手感、长局性能或全库美术验收。

## 失败记录

- `diagnostics/20260915_154010_84add889/`：全新导入后4个新import UID被Godot规范化，源保护停止。采用Godot输出的规范UID再跑，PNG没有修改。
- `diagnostics/20260915_154152_dc423156/`：角色642项通过，但共享检查仍认旧idle PNG优先，整批未通过；同时目检发现旧头像不一致。修正本角色明确的新TRES优先规则、增加新肖像及2项实际图鉴断言后重跑。
- 两批保留非PNG原始报告、日志、harness与receipt；旧截图仍在对应 `D:/CodexTemp/character_art_20260915/` 目录，不当最终证据。最终27张PNG全部在本目录native内。

## 覆盖统计与复现

最终库存164种移动定义中：四向idle 28、walk 12、attack 12、death 10。它们是库存计数，不是全部画稿质量验收。缺图和旧候选仍按共享报告的coverage_gates与逐单位清单解读。

```powershell
py -3 -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/guan_zhanzi_20260915.json
py -3 -X utf8 -B tools/directional_character_sources.py assets/direction4/guan_zhanzi_20260915.json tools/contracts/guan_zhanzi_direction4_20260915/generation.json --out qa/character_art_20260915/sources.json
py -3 -X utf8 -B tools/run_character_art_qa.py --repo . --work-root D:/CodexTemp/character_art_20260915 --manifest guan_zhanzi=assets/direction4/guan_zhanzi_20260915.json --shared-checks --run
py -3 -X utf8 -B qa/character_art_20260915/verify_evidence.py
```

最后一条读取现有证据，不启动游戏；生产后续修改导致冻结文件哈希变化时应解释版本差异，不能改旧收据让其通过。第三条在新设备按godot.local.txt配置本地引擎，不要求复用本机缓存。

本批没有改属性、伤害、攻速、移动速度、碰撞、剧情或波次。素材、代码与相关证据同步stable，Steam尚未发布此批。来源提示词、所有退回理由见[生成契约](../../tools/contracts/guan_zhanzi_direction4_20260915/README.md)。
