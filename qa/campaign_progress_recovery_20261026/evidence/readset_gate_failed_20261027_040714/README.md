# readset 首轮 gate 工具失败（2026-10-27 04:07:14）

原批次 20261027_040714_122b1aa3，仅 producer PID 66668 运行并退出 1。最终 105 项检查中 104 过、唯一 exact host gate 失败；prepared 的 102 项是较早累积快照，不再叠加计数。无 debugger stop，attack_reader 与 clone_record 均未启动。

request 与 ACK 的 pid=66668、index=0、nonce、process_nonce 四字段值完全一致。原 GDScript 将 JSON 数值读成 float Variant，却用整个 Dictionary 与含原生 int 的预期 Dictionary 深等比较，导致 QA 控制通道误拒。原失败没有追加运行时 typeof 探针；原字节与源码共同保留供复核。

这是测试工具失败，不是 Store 或正常 Flow 恢复失败。正常 Flow 另批资格不受本批判定替代。本片尚未进入 readset 攻击或旧 4 MB clone 恢复，不授相应通过资格。

raw/inputs 保留运行时 5 个原文件，raw/workers 保留实际执行的 3 个 worker 原字节；raw 内另有原 receipt/controller/prepared/report、request/ACK、gate 绑定及 native.log。逐文件 SHA 见 manifest.json。未复制私有 seed、profile、业务原件、fixture 载荷、EXE、assets 或缓存。

原宿主收据 lock_released=false、helpers_terminal_confirmed=false 原样保留；worker 报告 providers={}、providers_terminal=true。后续独立确认与释放由根线程另记，本归档不提前授予该结果。原冻结、原输入和原失败证据均未修改；归档不启动引擎、不操作锁或 Git。
