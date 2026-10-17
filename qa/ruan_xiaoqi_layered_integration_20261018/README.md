# 阮小七分层实际接入验收

实际运行批`20261018_054606_5890ee3e`完成：1592检查/0失败、118张原生实景，主代理直接查看48张；已采用本地生产路由，最终握指/步态/身体连续性与整库美术仍未完成。详见[实现与限定](../../docs/RUAN_XIAOQI_LAYERED_INTEGRATION_20261018.md)。

- `native/receipt.json`、7份原日志：实际Godot导入、解析、原生纹理参考、导出新补丁、包内身份、真实Battle运行；原日志SHA和执行命令保留。
- `native/inputs.json`、`expected_identity.json`、`texture_references.json`、`pack_chain.json`：6913冻结来源、6904规范身份、180纹理原生像素/mipmap、实际5包链。PCK留在原外置位置，不进仓库。
- `native/visual_report.json`：1592条原始检查、运动距离/步相和118图SHA；`screenshot_inventory.json`记录全部原图路径/哈希及目检标志。`direct_visual_review.json`明确48直接看图与未完成项，非独立审查。`screenshots/`6张字节相同代表实景。
- `native/prior_inputs_restore.json`：复用旧工程前的恢复清单；6480保留Git来源+359外置ZIP输入+48额外冻结文件。ZIP3,693,138字节，SHA `47aa36c9710f4e8f6315f516b8697c51a8f9086d8e095d05e03f651a9d8b0344`；旧上下文6839规范输入可按清单恢复。原ZIP留工程外，不误称当前私有树仍是旧树。
- `resource_preview/`四批独立导入资源检查，前2批失败原样保留，后2批各138项通过/4张原图。索引含所有16图SHA、失败原因纠正及维度类型证据；失败批图保留外置。此范围不是Battle/PCK验收。
- `registration/`配准前14文件、前后索引、13PNG基线和20手工近似握点/平移记录。配准只改Atlas平移元数据，未改PNG、缩放或车变换。前后原生纹理完整像素/mipmap一致。
- `runtime_inventory.json`实际代码/资源SHA；`applied_for_native.json`6文件接入来源。`preservation/`16保护文件/81无关未跟踪导入文件及后验零差异记录。6913冻结来源在收尾再次对ROOT和私有树逐项核对一致。

原始批及所有118截图位于`D:/CodexEvidence/shuihu/ruan_xiaoqi_layered_integration_20261018/native/20261018_054606_5890ee3e/evidence/`。资源预览原始批在`D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_fixes_20261018/native_resource_preview/`。这些路径是本机证据索引，复现使用项目工具参数重新建立独立目录，不把本机路径写死进生产入口。

原著人物/情节限制沿既有第15/16回依据，衣色发式/赤足/具体步态和车构是美术解释。泛用败退掉货不改写寿终。QA显式CARRY/drug前提、位置取样、冻结其他演员、迷雾关闭；七车十一担、完整喝酒顺序、全战役/存档/常态性能/Steam/全部美术均不在通过范围。制作清单的false状态是未接入时的历史快照，当前实际采用为true，最终美术接受仍为false。
