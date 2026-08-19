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

## D010 - Stage 2 使用固定尺寸 Scheme 4 与冻结门槛

Stage 2 默认 M64，M128 仅以相同训练流做预注册扫描；两者都导出固定 512 点运行
表。`scheme4_update` 只接收六个 deployment-safe 标量，状态只保存循环三对角充分
统计量、覆盖/行程、shadow/active 和触发计数。参考解使用 `mldivide`，固定求解器
使用带宽二 Cholesky 加四维周期边界 Schur；禁止 `pinv`。正则、触发、投影处理、
融合及全部 PASS 数值在仿真前锁定，结果不得用于挑选 M 或回调参数。

## D011 - Stage 2 冻结预测残差包含 frozen PM 补偿

Stage 1 为提取角误差方向而有意省略 PM 反电势，因此其残差幅值不能作为“补偿后
完整电流模型”的改善指标。Stage 2 冻结评价在 Stage 1 部署残差上减去由 frozen
compensation、IdentificationBus 方向和期望幅值预测的 PM 残差，形成完整 SPMSM
一步预测残差。该计算不读取真值；真值仍只用于控制角 RMSE、转矩与最终 LUT 评分。
`iq` 门槛定义为恶化量 `(active-baseline)/baseline`，改善为负值，不得被误判为
“变化过大”。
## D012 - User-authorized floor-aware control-angle gate

After the preserved Stage-2 run `stage2_20260818_194629_441` failed under
the original 70% ideal control-angle improvement threshold, the user
explicitly authorized a versioned protocol change for new Stage-2 and
Stage-3 runs.  A nonzero ideal frozen case now passes when its control-angle
RMSE improves by at least 60%, or when its active RMSE reaches the encoder
quantization RMS floor plus 0.10 deg_e.  With 1024 mechanical counts and 21
pole pairs this second limit is 2.231234 deg_e.  Fixed-zero remains exempt
from the percentage gate; nonideal cases retain the strict 50% improvement
gate without a floor exception.  Historical result files are immutable, and
all other thresholds remain unchanged.

## D013 - Stage 3 uses fixed Scheme 5 nominal-amplitude learning

Stage 3 is LUT-only and keeps `Rs/Ls/psi_f` fixed. The gate-driving path uses
E30--E32 with M64, `mu5=0.01`, `epsilon5=0.01 A^2`, ten mechanical training
cycles, and the same valid samples saved by the passed Stage-2 run. M128 is a
same-stream scan. Measured-magnitude and direction-normalized forms are M64
diagnostics only and cannot replace the nominal path after truth scoring. Each
accepted 20 kHz sample updates only the two local shadow nodes; table-wide E51
handling and slow active fusion occur only at a fusion trigger. Algorithm state
is fixed-size and stores no sample history. Runner-side history exists only to
produce convergence CSV/PNG/PDF/GIF artifacts and is never fed back to learning.

## D014 - Frozen active-on initialization uses the frozen control frame

The first floor-aware Stage-2 rerun exposed a pair-comparability defect at the
20-degree fixed profile: active-on was initialized with the uncompensated
control-frame error, so its speed PI started with excess torque and had not
settled inside the fixed evaluation window. Frozen simulations now compute the
controller and plant equilibrium from the actual quantized raw encoder angle
minus the supplied frozen runtime LUT. Active-off remains initialized from the
raw uncompensated frame. This corrects only simulation initial conditions; it
does not modify the controller, LUT, training samples, thresholds, predictor,
or evaluation window.
