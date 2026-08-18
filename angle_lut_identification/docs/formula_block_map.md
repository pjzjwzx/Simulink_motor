# 公式与模块映射

| 公式 | 作用 | 实现 | 输入/输出 | 采样 | 测试 |
|---|---|---|---|---|---|
| E01 | 机械角传感器前向模型 | `anglelut.encoder_forward_model` 与 harness Encoder Frontend | `theta_m_true -> theta_m_raw, error_m` | 20 kHz/1 kHz | encoder forward tests |
| E02 | 补偿符号 | harness Control Angle，Stage 1 `L_e=0` | `theta_re-L_e` | 20 kHz | +5 deg sign |
| E03 | Park 约定 | `anglelut.park_alphabeta`，与现有 MATLAB Function4 相同 | `alpha,beta,theta -> d,q` | 20 kHz | Park sign |
| E04 | SPMSM 原始角坐标模型 | 推导与符号核对，不使用真值求解 | - | - | +5 deg sign |
| E05 | 一步预测 | `anglelut.physical_residual`：在坐标不变的 αβ 系积分，再用速度外推的原始角区间中点执行 E03；避免 1024 机械量化角跳变被误当成物理坐标系速度 | interval sample pair -> predicted current | 20 kHz | predictor floor、量化角跳变不变性 |
| E06 | 预测减实测残差 | `anglelut.physical_residual` | `pred,next -> rd,rq` | 20 kHz | residual direction |
| E07 | 残差与角误差 | Stage 1 evaluator | `rd,rq -> expected amplitude/error` | 20 kHz | fixed-error regression |
| E08 | 方向统一与伪角度 | `anglelut.direction_hysteresis`、`physical_residual` | `rd,rq,omega -> yd,yq,z` | 20 kHz | forward/reverse |
| E09 | 周期插值 | 仅参考 LUT 聚合/后续接口；Stage 1 不学习 | `phi,delta -> reference bins` | analysis | periodic wrap |

接口分层：harness 中的 `RawIdentificationSourceBus` 与
`RawEvaluationTruthSourceBus` 只汇集模型内已有的观测源，不冒充完整接口。
分析层必须在残差循环前组装完整 `IdentificationBus`，且循环中的
`sample_k/sample_kp1` 只能从该接口读取；完整 `EvaluationTruthBus` 只能在残差
循环后组装，并保持评价/绘图 sink-only。

Voltage A/B 另设 `evaluate_voltage_ab` 评价器。部署残差先且始终由
`physical_residual` 使用 reconstructed duty/Vdc 电压完整计算；正式
`EvaluationTruthBus` 组装后，评价器才读取 `plant_vabc_V` 形成独立 B 路。
B 路严格复制 A 路的 `valid`，不调用门控，并保持 E05-E08 的 alpha-beta Euler、
连续中点原始角 Park、预测减实测、`y=s*r` 与 `atan2(y_d,y_q)`。案例字段
`voltage_source` 只选择保存/评分的 A/B 诊断分支，不替换主 estimator 或 Stage 1
理想 RMSE。
