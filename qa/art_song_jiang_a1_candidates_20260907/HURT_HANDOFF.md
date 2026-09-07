# 宋江 A1 四向受击候选交接 · 2026-09-07

本阶段已在官方 ChatGPT 网页分别上传同向 idle + 宋江身份图并生成 SE、SW、NE、NW 四个独立受击姿态，原生 PNG 已保存在 `source/`。生产准入数仍为 0；没有运行 Godot，没有修改 `assets/`、生产代码或公共文档，没有 Git 提交。

## 文件与来源

- `candidate_manifest_hurt_v1.json`：4 张候选原图的稳定生成对话、SHA、尺寸和参考路径。临时签名下载 URL 不入库。
- `source_inspection_hurt_v1.json`：36 个旧参考/清单/资源 SHA 实际匹配，4 张新 PNG 的 alpha、主要轮廓边界和尺寸。
- `prompts/01_*.txt` 至 `04_*.txt` 是本次实际提交的受击规格；`pose_worklist_at_hurt_handoff.json` 冻结完整9姿态的参考 SHA 和 prompt SHA。05—09 在本交接时仅完成规格，尚未出图。
- `preview/hurt_v1_light.png`、`hurt_v1_dark.png`：实际查看的浅/深底对照，上排旧 idle，下排新候选；同为 0.23 缩放，仅用于审图，不是游戏脚锚或实机验收。
- `preview/render_receipt.json`：4 张新原图 + 4 张 idle 在 QA 合成前后 SHA 全同。

## 实际初审

四图均为站立遭击后仰，胸肩/空手相对 idle 有清楚变化；剑始终保留在解剖右手，左手空，左髋青绿穗带保持，主要人物和剑尖没有被画布截断。SE/SW 为前侧，NE/NW 为背侧且面对相应左右方向。没有拿 fall/down 代替 hurt，没有对方向做镜像。

原生图的主体 alpha 众数为 253；不能只看 alpha=255 占比很低就认定整个人半透明。已正常合成浅/深底，未见不透明矩形背景或明显背景光晕。SE/SW 外边框非零 alpha 为 0；NE/NW 分别有8/22个弱 alpha 边缘样本，但 alpha>99 的主体边界都在画布内部；保留原像素，不脚本擦边或二值化透明度。

四张均保留为待选候选。衣褶与部分金纹会随重新绘制变化；需在正常游戏比例与旧 idle/attack/walk 相邻切换复查。当前还没有定实际受击脚锚、缩放、TRES帧节奏，没有验证真实受击触发/退出和转向。初审通过不等于用户视觉认可或可直接生产接入。

## 浏览器能力和限制

优先 IAB：中断前官方网页已登录，能看到“创建图片”和“添加照片和文件”。主动中断后 IAB 从工具清单消失，原 tab 与新 IAB 请求均返回 browser unavailable；随后用现有受支持的 Edge / chatgpt.com 正常 filechooser.setFiles 上传参考，生成成功。没有使用绘图 API/CLI、付费替代通道或其他 Codex 任务代理生成。

原生图由浏览器 `pageAssets` 对当前可见生成图资源进行标准导出，再字节复制到本目录；完整稳定对话保留。下载缓存清单中的临时 URL 未复制入项目。

本地 `review.html` 可供用户手动打开，但代理对 file URL 的浏览器访问被 URL policy 拒绝，因此没有宣称自动网页预览通过，也没有改 localhost/CDP/其他浏览器绕行。之后的明暗底 QA 使用本地 System.Drawing 的标准 alpha 合成，读取已保存的 PNG，只输出独立 QA 画布并保持全部原图 SHA 不变。这不是绘画、补画或生产资源变换。

## 接续

先由主线/用户审阅四图；若选中，再在独占 Godot 时间窗口生成候选资源、校脚锚并做真实受击和未改状态对照。剩余已批准工作为 NW 接触1姿态与四向反腿4姿态；林冲条件修订仍等待当前正常镜头观察。
