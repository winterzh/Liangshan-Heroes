# 全库四向盘点与不合格候选

运行 `tools/character_direction4_inventory.gd` 重建清单。`inventory.json` 保存每个 key 的通用参考源、四个动作的精确方向路径和驻守波次权重；`inventory.csv` 是可筛选的缺口表。

当前164个可移动定义，24个有四向idle文件，walk/attack/death分别7/7/5。文件齐全不等于视觉/动画质量已验收。驻守42种敌军中32种缺通用四向idle；按实例统计仍是709/778，与此前口径一致。

`candidates/` 保留内置 image_gen 两次生成的原文件和四个输入参考，`prompts.json` 为完整提示词与拒收原因，`sha256.json` 为原始字节哈希。两次输出都是RGB棋盘格背景，不是真透明；没有生产安装。首稿还有前向重复，二稿仍须方向复核。这些候选不计入任何完成率。

当前等待用户选择是否允许本地程序透明化/裁切/对齐。未执行程序像素处理。后续范围与验收要求见 `docs/CHARACTER_DIRECTION4_20260905.md`。
