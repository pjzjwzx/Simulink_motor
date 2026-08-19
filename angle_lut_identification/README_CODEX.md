# Angle LUT Stage 0/1/2/3

本目录在不修改原始 `FOC_fw_hifi_v1_0709backup.slx` 的前提下，实现编码器机械角周期误差注入和 Stage 1 物理残差验证。

## 入口

在全新 MATLAB R2024b 会话中：

```matlab
cd('D:/Desktop/HKU_2/FOC_Arclab/simulink_2/angle_lut_identification');
cfg = setup_project;
s0 = run_stage0;
r1 = run_stage1;
r2 = run_stage2;
r3 = run_stage3;
```

`run_stage1` 会先检查最新 Stage 0 gate；未通过时返回 `BLOCKED`。所有案例使用 `Simulink.SimulationInput`，结果保存在 `results/<run_id>/`。

`run_stage2` 固定检查正式 Stage 1 PASS `stage1_20260818_134403_214`。它先用
八条训练流完成默认 M64 Scheme 4，再把完全相同的数据重放给 M128，最后运行
独立 active-off/on 冻结矩阵。完整运行是高保真 20 kHz 案例矩阵，预计约
25–40 分钟；出现关键失败会立即保存现有状态并停止。

`run_stage3` 只接受新生成的 `FULL_STAGE2/PASS`。它逐样本重放 Stage 2 保存的
完全相同训练流，执行 E30–E32 的 Scheme 5 LUT-only 学习，再运行独立冻结矩阵。
主路固定使用 `nominal_model`、`mu5=0.01`、`epsilon5=0.01 A^2`；另外两种幅值
形式只生成诊断，不得按真值选择。若 Stage 2 不是完整 PASS，Stage 3 会保留
`BLOCKED` 工件并停止。

## 边界

- 原始 SLX 只读使用；Stage 1 修改仅存在于 `models/angle_lut_harness.slx`。
- Stage 1 不学习 LUT，active 补偿固定为 0。
- 真实角度、真实速度、注入误差与 plant-applied voltage 只用于评价。
- 默认机械误差为 `0.60 deg_m*sin(theta_m)+0.30 deg_m*sin(2*theta_m+pi/4)`。
- harness 内的 `RawIdentificationSourceBus` / `RawEvaluationTruthSourceBus`
  只是模型原始采集源；完整正式接口由分析层按 `config/bus_definitions.m` 组装。
- Stage 2 修改只存在于 `models/angle_lut_stage2_harness.slx`；其保存默认值是
  active 关闭、512 点运行表全零。原始辨识角始终旁路 active 补偿。
- Scheme 4 每次更新只接受 `phi_m_rad/z_e_rad/quality_weight/`
  `theta_m_unwrapped_rad/timestamp_s/valid` 六个标量字段，状态不保存历史样本。
- `project_lut` 是约束处理函数，不宣称精确欧氏投影。Stage 2 完成后不会自动
  运行 Stage 3 或 Stage 4。
- Stage 3 修改只存在于 `models/angle_lut_stage3_harness.slx`；保存默认同样是
  active 关闭、512 点零表。Scheme 5 每个样本只接收八个白名单标量并只更新
  相邻两个 shadow 节点；学习历史由 runner 在算法状态外记录。
- Stage 3 固定 `Rs/Ls/psi_f`，不执行联合参数辨识，也不执行 Stage 4。

## Stage 2 结果

正式结果位于 `results/<stage2_run_id>/stage2/`。顶层包含 `configuration.json`、
`metrics.csv`、`gate.json`、`result.json`、`run_manifest.json`、`tests.csv`、文件
清单与环境清单；`training/`、`profile_freeze/`、`frozen_validation/` 和
`condition_drift/` 保存逐案例状态/trace；`luts/` 保存 shadow、active 与固定 512 点
运行表；`reports/` 保存 PNG/PDF、求解器、收敛、覆盖、漂移、安全及计算/存储成本。
失败原因集中在 `failures/gate_failures.txt` 与逐案例 `failure.txt`。

已保存的 Scheme 4 求解快照可独立重放成学习演化图，不会重新训练或改变 gate：

```matlab
generate_stage2_learning_evolution( ...
    'results/<stage2_run_id>/stage2','periodic_combined');
```

该命令在 `reports/` 中生成逐次求解 CSV/JSON、静态 PNG/PDF 和动画 GIF。图中的
reference 只用于学习完成后的评价，不反馈给 shadow/active 更新。

## Stage 3 结果与学习演化

正式结果位于 `results/<stage3_run_id>/stage3/`。除配置、哈希、清单、测试、门控
和逐案例状态外，`reports/lut_learning_evolution.png|pdf|gif` 会展示每次融合时
shadow/active LUT 的变化；`lut_learning_evolution.csv` 同时给出融合次数、时间、
机械圈数、覆盖率、LUT RMSE 和相对零表改善率。改善应随学习增加而上升并最终收敛，
但评价真值只用于离线计算这些曲线，不参与 E32 更新。

Stage 2/3 新门控使用版本化合同：非零理想案例满足“控制角 RMSE 改善至少 60%”
或“active RMSE 达到编码器量化 RMS 地板加 0.10 deg_e”之一即可；每个冻结案例都会
保存实际采用的 `percentage`、`quantization_floor` 或 `fixed_zero_exempt` 分支。
非理想案例仍严格要求至少 50% 改善，不使用地板例外。
