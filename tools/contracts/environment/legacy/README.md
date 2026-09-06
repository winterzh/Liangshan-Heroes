# 待恢复的历史原件

此目录目前不包含下面两个原件。相关门禁会报缺失并返回非零退出码。

| 文件 | 必须匹配的 SHA256 |
|---|---|
| `environment_batch_manifest.json` | `162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf` |
| `static_self_check.json` | `f8e562d4aeebbd64519acf83ecfb54385742b3d7f89dd72684149a953386aa77` |

历史位置是办公室外层 `implementation_20260902/environment_prompt_drafts_v2/`。如果在办公室找到原件，按原字节复制到此处，并保留清单所引用九份提示词的相对文件名与目录。也可以显式提供 `--batch-manifest`，无需改写公共工具中的机器路径。

素材接入旧自测还需要原 `qa/environment_runtime_router_20260902/report.json`，SHA256 `16dda6894bfc1bb54584ac90180de2227d6df6a34174192a6638fd8068405f43`。旧映射中的消费者 SHA 及源码行已经过时，恢复后仍须重新验证，不能直接认定可导入。

`environment_map_clamped_contract.py` 另外需要原安装清单、normalization 报告、候选和原图。复制后的历史报告如包含办公室绝对路径，使用 `--evidence-map` 明确映射到仓库内相对路径；保持历史文件原字节，不改写来源 SHA。工具拒绝绝对目标、越界映射和哈希不符。

当前生产映射只能用于独立的路由检查，不能替代这里的原提示词清单或作为生产接入授权。
