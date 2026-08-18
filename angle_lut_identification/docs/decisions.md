# 实施决定

## D001 - 原模型只读，使用独立 harness

原因：保留现有 FOC 基线并允许机械编码器模型与 legacy 电角模型并存。验证：Stage 0/1 manifest 记录原模型运行前后 SHA256。

## D002 - 默认周期波形

采用用户确认的 `0.60 deg_m` 机械 1x 与 `0.30 deg_m` 机械 2x（相位 `pi/4`）组合，无常数项。保守峰值上界 0.9 deg_m，即 18.9 deg_e。

## D003 - 预测周期与触发相位

E05 的预测周期使用 PWM 周期 50 us。由于 ADC/角度已有 5 us 延迟，Stage 1 在 PWM 边界后 5 us 采样，以对齐物理区间边界。

## D004 - Stage 1 不学习 LUT

Stage 1 只验证残差、符号、时序和门控。控制补偿固定为 0；reference LUT 仅由真值评价样本聚合，不反馈控制。

## D005 - 非理想因素

非理想案例使用模型工作区已有数值；其实现只存在于 harness variant，默认基线保持关闭，不改写原逆变器或控制器。

## D006 - 速度设定块的实际单位

原模型块名含 `RPM`，但该 Step 后紧接增益 `2*pi`，没有 `/60`。因此 Step 数值的实际单位是机械转/秒（rev/s）；案例机械速度 `omega_m` 必须以 `omega_m/(2*pi)` 写入。结果 manifest 保留该映射，禁止按 RPM 名称误乘 60。

## D008 - 原始采集总线与正式 Stage 1 接口分层

模型内能直接汇集的信号不足以构成任务书规定的完整总线，因此将两个 observer
总线明确命名为 `RawIdentificationSourceBus` 与
`RawEvaluationTruthSourceBus`。它们只是原始采集源：正式
`IdentificationBus` 必须在物理残差循环前补齐解缠角、可用估速、方向状态、有效
标志和对齐时间戳，循环样本只能由该总线取得；正式 `EvaluationTruthBus` 必须在
残差循环结束后组装且保持 sink-only。验证由总线字段合同、builder 命名测试以及
分析器数据流结构测试共同完成。

## D007 - Predictor floor 使用零注入实测 RMSE

任务书要求在“无角误差、无噪声”条件下测量 Euler 与中点/梯形预测器的固有 RMSE。因此 `fixed_00deg_e` 是冻结的 floor 校准案例：其 Euler RMSE 是 Stage 1 ideal gate 的 `predictor_floor`，RK2/Heun RMSE同时记录。Euler 与 RK2/Heun 的逐样本差仅记为 `predictor_disagreement`，不能替代 floor，因为 ADC 基线量化等公共误差会同时进入三种预测器。校准案例本身不再对由自身生成的阈值做自引用判定。

## D009 - Plant voltage 仅进入独立 A/B 评价残差

Stage 1 主 estimator、有效标志、质量权重和全部 gate 永远使用由生效 duty 与
Vdc 重构的电压。只有在全部部署残差完成且 `EvaluationTruthBus` 已组装后，
`evaluate_voltage_ab` 才可读取对齐后的 plant-applied phase voltage，按相同 E05-E08
数学形成 B 路；B 路直接复制部署 valid mask，不能以 plant 残差重新判门。
`voltage_ab_reconstructed` 与 `voltage_ab_plant_evaluation` 的 `voltage_source` 仅选择
独立诊断分支的真值 RMSE 和 trace，绝不替换主 `rmse_e_rad`。结果同时保存两路
RMSE、plant-minus-reconstructed 的伪角度/残差/电压差以及数值分叉标志。
