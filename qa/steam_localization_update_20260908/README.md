# Steam 四语与校订更新 QA

运行内容/QA 快照为 `697b3132e7ef9e981c587b7395f2d10cf81e5d74`，外部探针工具修复为 `398a90f50c11bac96026100e3a94f4873591b864`，两者运行文件逐项哈希相同。

- `coverage.json`、`merge.json`：4,358 个显示源文本三语覆盖完整，缺失和格式错误 0；运行词库共 4,361 键。合并中 11 项覆盖已解决，不表述为零冲突。
- `native/`：QA `20260908_155519_1deaacd4`，182 项通过，六张顶层 PNG 均逐张查看，未见阻塞布局；真实 Steam 禁用提示符合环境。
- `export/`：候选 `20260908_160006_4ad9cdeb`，825 项同包检查通过，四语实际译文零不一致，108 篇完整生平/回目和区域字体检查通过，实际发行 EXE 600 帧及两个 release DLL 加载路径/哈希通过。源码与同包身份各 10 项通过。
- `smoke/`：同一 EXE `smoke_20260908_160254` 的 11 例短测通过；八关启动、据守 9 项、末波清理 12 项及菜单均通过，源码/玩家文件/EXE 未变，子进程已退出、锁释放。
- `candidate_delivery.json`：ZIP 238,034,173 字节，SHA256 `6f1758ebc59624f63b1d8bb656c42e1d416de331cc64039a973154605f3bb757`，四成员 CRC、大小、SHA256、SHA1 重新核对。

`source_mapping.json` 区分原始与脱敏副本哈希；路径占位符不会重写报告内已记录的输入哈希。仅归档显式选取的报告、日志和六张界面，不包含 profile、玩家文件、Steam 缓存、EXE、DLL 或 ZIP。失败候选 `20260908_155834_9ef41adb` 的 bool 推断错误已修复，未上传、不计入成功。

同包检查是资源和结构验证，原著事实及多语页面审查见 [文本校订 QA](../text_review_20260908/README.md)。本轮真实 Steam 禁用，不代替真实账号、客户端下载、双账号、完整通关、1800 秒、双机或性能验收；内部恢复组件仍未开放为正常玩家保存/继续入口。

复现：运行 `tools/run_steam_integration_qa.py --run --native --visual --profile-root <新的短绝对根>`，再运行 `tools/build_steam_candidate.py --run --qa-run <成功QA目录> --profile-root <短绝对根>`。同包短测 helper 恢复到工程 `.godot/<新目录>/smoke_verified_package.py`，替换私有 profile 占位符后传入候选目录。各套件串行占用引擎槽。

Build25182453已在default正式版生效，Manifest4066863387208539897；服务器四文件大小/SHA1与验收包相同。用户明确批准 default 并完成手机验证器确认后，canonical分支及发布历史均确认25182453，steam-integration仍为25179481。预览从25164373更新的增量下载为25.2 MB，真实客户端下载尚未验收；提交构建时选择“无”保留为此前上传时历史事实，详见 `steam_server_receipt.json`。

内容起点与构建流程见 [更新说明](../../docs/STEAM_LOCALIZATION_UPDATE_20260908.md)。未列为成功的上传或上线步骤不得从候选文件存在推断完成。
