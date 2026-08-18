# Stage 0 工程预检报告

## 结论

主模型 `FOC_fw_hifi_v1_0709backup.slx` 可由 MATLAB R2024b Update 7 加载、编译并进行快速加速仿真。Stage 0 执行脚本会重新运行完整 10 s 基线，并以运行前后 SHA256 一致作为“不修改原模型”的硬性 gate。

## 当前工程

- 主模型：`../FOC_fw_hifi_v1_0709backup.slx`
- 参数更新前备份：`../FOC_fw_hifi_v1_0709backup.before_state_parameters_20260818.slx`
- 当前目录不是 Git 仓库，因此 manifest 使用 SHA256、文件大小和修改时间代替 commit/diff。
- MATLAB：R2024b Update 7；Simulink、Simscape Electrical、Motor Control Blockset 和代码生成工具可用。

## 参数与时序

- 极对数 `pn=21`，`Rs=0.09 ohm`，`Ld=Lq=61e-6 H`，`psif=0.004208 Wb`。
- 模型基础步长参数 `Ts=5e-6 s`；powergui 为离散 5 us。
- PWM 比较值通过 50 us Unit Delay 生效，故 Stage 1 预测周期固定为 `T_ident=1/fpwm=50e-6 s`，不得使用 5 us。
- ADC 电流与编码器角度各有 5 us Unit Delay。Stage 1 事件安排在 duty 边界后 5 us，使延迟输出对应区间起点。
- 模型配置为 `Variable-step / VariableStepAuto`、Rapid Accelerator、StopTime 10 s；Stage 1 harness 保持该配置。

## 信号映射摘要

- 测量电流：`Current_Sensing_ADC_Latency_Ia/Ib/Ic` 输出。
- 生效 duty：`PWM_and_Actuation` 输出；已经过 50 us 保持和 `[0,1]` 饱和。
- 直流母线：`Constant8`，值为 `Vdc`。
- 现有角度链：PMSM `MtrElcPos` -> 电角度偏置/量化 -> 5 us 延迟 -> Park/AntiPark。它是 legacy 模式，不满足机械编码器定义。
- Stage 1 机械角真值：PMSM `MtrPos`，只允许进入传感器前向模型与评价总线。
- plant-applied voltage：`Inverter_Nonideal` 输出，只允许进入 A/B 评价。

## 已识别风险

- 1024 counts 在原模型中按电角一圈量化；Stage 1 必须按机械一圈量化，因此 harness 保留 legacy 变体用于等价性测试。
- 现有 `wm/we` 来源于 PMSM 真值；Stage 1 辨识器必须改用原始机械角的解缠差分估速。
- 模型没有原生 ADC-valid、PWM-overmodulation、current-limit 或 timestamp 信号；harness 将显式生成并记录这些门控。

