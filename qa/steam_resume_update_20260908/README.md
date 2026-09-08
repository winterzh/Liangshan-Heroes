# 2026-09-08 恢复组件更新包 QA

从干净 stable `d32b0b86cbf82c88ec11e1a3433a7291f65e038d` 冻结。运行代码对应上一批9529a8b，未为打包改动运行代码。

- 原生QA `20260908_113427_df712cfe`：2923份来源记录，182项检查通过；六张PNG逐张查看，未见阻塞布局，Steam禁用提示符合测试环境。
- 导出 `20260908_113610_180c93c4`：import/export退出0，65项实际包检查、源码/PCK身份各10项及发行EXE启动通过。固定release DLL已校验。
- 同一EXE串行11个短测（八关、据守、末波清理、菜单）通过；据守9项、末波清理12项内嵌合同ALL=true。源码、真实玩家文件及EXE不变，子进程退出且锁释放。
- ZIP 221324671字节，SHA256 `7e98ca00a78992f11d538a2c7dba7d335e9ee07455b7569532a04483403ec995`。CRC、四成员及大小/SHA256重新核对；SHA1供后续服务端比对。

本轮验证禁用真实Steam，不代替真实账号、客户端下载、双账号、完整通关、1800秒、双机及性能验收。内部恢复组件虽已入包，玩家保存/继续按钮、正常启动持久模式和持续SDK发布仍未接通。

`native/`为原生QA与六张界面；`export/`为导出、包/身份报告；`smoke/`为实际发行EXE短测；`candidate_delivery.json`为成品清单；`source_mapping.json`记录原件和归档SHA。文本路径作占位符替换，内嵌哈希指向原始输入，不应当作脱敏副本哈希。未归档玩家文件、Steam缓存、DLL、EXE或ZIP。

复现：使用上述源码与配置的Godot4.6.3，运行 `py -3.14 -X utf8 -B tools/run_steam_integration_qa.py --run --native --visual --profile-root <新的短绝对根>`，随后 `tools/build_steam_candidate.py --run --qa-run <新QA目录> --profile-root <短绝对根>`。将 `helpers/smoke_verified_package.py.txt` 恢复到工程 `.godot/<新目录>/smoke_verified_package.py`，替换私有profile占位符，再传入新成品目录运行。各套件串行占用引擎槽。

服务端状态见 `steam_server_receipt.json`。Build25179481已在steam-integration生效，Manifest5125271626255480862；服务器四文件大小/SHA1与成品一致，canonical分支及历史回读确认。default保持25164373。更正：截图确认文件已附加，先前DOM读取被误判为缺少文件URL权限；首轮Upload failed后用相同ZIP重试成功，历史保留在收据。
