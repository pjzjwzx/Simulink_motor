# Angle LUT Stage 0/1

本目录在不修改原始 `FOC_fw_hifi_v1_0709backup.slx` 的前提下，实现编码器机械角周期误差注入和 Stage 1 物理残差验证。

## 入口

在全新 MATLAB R2024b 会话中：

```matlab
cd('D:/Desktop/HKU_2/FOC_Arclab/simulink_2/angle_lut_identification');
cfg = setup_project;
s0 = run_stage0;
r1 = run_stage1;
```

`run_stage1` 会先检查最新 Stage 0 gate；未通过时返回 `BLOCKED`。所有案例使用 `Simulink.SimulationInput`，结果保存在 `results/<run_id>/`。

## 边界

- 原始 SLX 只读使用；Stage 1 修改仅存在于 `models/angle_lut_harness.slx`。
- Stage 1 不学习 LUT，active 补偿固定为 0。
- 真实角度、真实速度、注入误差与 plant-applied voltage 只用于评价。
- 默认机械误差为 `0.60 deg_m*sin(theta_m)+0.30 deg_m*sin(2*theta_m+pi/4)`。
- harness 内的 `RawIdentificationSourceBus` / `RawEvaluationTruthSourceBus`
  只是模型原始采集源；完整正式接口由分析层按 `config/bus_definitions.m` 组装。
