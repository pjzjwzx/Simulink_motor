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
| E09 | 周期插值 | `anglelut.periodic_lut_interp`、Stage2 harness `Stage2_Active_LUT_Compensation/periodic_interp_512` | `phi, LUT -> compensation` | 20 kHz | `testE09PeriodicContinuity`, `testRuntime512WrapContinuity` |
| E20 | shadow 相对局部解缠 | `anglelut.scheme4_update`，创新裁剪 ±30 deg_e | `shadow(phi), z, chi -> z_tilde` | 流式 20 kHz | `testE20LocalUnwrapAndInnovationClip` |
| E21 | 两节点流式充分统计量 | `anglelut.scheme4_update64/128` | 六字段 LearningSample -> fixed `diag/neighbor/b/S` | 流式 20 kHz | `testE21TwoNodeStatisticsMatchBatch`, `testStateIsFixedSizeAndStoresNoHistory` |
| E22 | 周期二阶平滑正规方程 | `scheme4_solve_reference` 与 `scheme4_solve_banded` | sufficient statistics -> shadow LUT | 触发求解 | `testFixedSolversMatchMldivide64/128` |
| E30 | Scheme 5 幅值与二维预测 | `anglelut.scheme5_update64/128` | `shadow(phi), omega_e -> a_hat, y_hat` | 流式 20 kHz | `testE30E31AndPositiveE32Update` |
| E31 | 切向/径向残差 | `anglelut.scheme5_update` | `y-y_hat, delta_hat -> t,n` | 流式 20 kHz | `testE30E31AndPositiveE32Update`, sensitivity reports |
| E32 | 正号归一化两节点更新 | `anglelut.scheme5_update` | 八字段 LearningSample -> two shadow nodes | 流式 20 kHz | `testCenteredFiniteDifferenceGradient`, `testForwardReverseNormalizedUpdateMatches`, `testExactlyTwoNodesChange` |
| E50 | 有效性与质量权重 | Stage 1 `quality_gates` 输出的 `valid/quality_weight` 经六字段接口复用 | IdentificationBus -> `chi` | 20 kHz | truth-isolation/config tests |
| E51 | 幅值/单调/融合约束 | `project_lut`（约束处理）与 `fuse_active_lut`，由 Scheme 4 求解或 Scheme 5 融合事件调用 | shadow/active/valid -> frozen active | 每次有效求解/融合 | constraint/fusion tests |

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

Stage 2 模型路径为
`angle_lut_stage2_harness/Stage2_Active_LUT_Compensation`。其控制输出仅连接原模型
Park/AntiPark 的角输入；Stage 1 observer 的 raw electrical angle 仍直接来自
`Position_Sensing_Encoder_Latency_Theta`。学习由 `stream_scheme4_trace` 逐样本复制
六个白名单字段后调用固定尺寸 wrapper；真值只在循环全部结束后由
`aggregate_reference_lut` 评分。冻结评价中的完整 PM 电流预测残差由
`anglelut.compensated_prediction_residual` 使用 IdentificationBus 残差、速度方向、
期望幅值和 frozen compensation 计算，不读取真值。

Stage 3 模型路径为
`angle_lut_stage3_harness/Stage3_Active_LUT_Compensation`。Scheme 5 更新器仅接受
`phi_m_rad/y_d_A/y_q_A/omega_e_est_radps/quality_weight/`
`theta_m_unwrapped_rad/timestamp_s/valid` 八个标量字段；固定尺寸 state 不包含 trace、
truth、plant 或历史缓存。`stream_scheme5_trace` 在所有更新完成后才读取
`truth_error_e_rad` 评分并生成学习演化图。nominal 路决定 gate，measured-magnitude
和 direction-normalized 只做同流诊断。
