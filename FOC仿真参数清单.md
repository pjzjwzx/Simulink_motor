# FOC 仿真参数清单

模型：`FOC_fw_hifi_v1_0709backup.slx`

本清单已按固件 `common/state_parameters.h` 更新。原模型备份为 `FOC_fw_hifi_v1_0709backup.before_state_parameters_20260818.slx`。

- 更新后模型 SHA256：`0CEEF28412602E5553DFE580A0784AFB253439BBEE14B9F4608C20CEB586C2CF`
- 更新前备份 SHA256：`1744E353788F6CA974DD01184E2422B59E89F9F514802285CAB50E2CDE958070`
- MATLAB R2024b 已执行保存、关闭、重新加载和只读复核；未运行仿真。

## 1. 本次更新

| 固件定义 | Simulink 参数 | 更新前 | 更新后 |
|---|---|---:|---:|
| `PPAIRS` | `pn` | 4 | **21** |
| `Lq` | `Lq` | 0.012 H | **61e-6 H** |
| `Ld` | `Ld` | 0.00525 H | **61e-6 H** |
| `Rs` | `Rs` | 0.958 Ω | **0.09 Ω** |
| `Linkage` | `psif` | 0.1827 Wb | **0.004208 Wb** |
| `J` | `J` | 0.03 kg·m² | **5.5e-6 kg·m²** |
| `BandWidth_CurrentLoop` | `BW_I` | 1100 rad/s | **5000 rad/s** |
| `BandWidth_SpeedLoop` | `BW_speed` | 50 rad/s | **20 rad/s** |
| `Vdc` | `Vdc` | 24 V | **24 V** |
| `PWM_FREQ` | `fpwm` | 20000 Hz | **20000 Hz** |

`B=0.008 N·m·s/rad` 保留不变：`state_parameters.h` 没有定义电机粘性阻尼，不能无依据改成 0。`GearRatio=9` 没有直接写入 PMSM；固件仅将它用于输出轴角度换算，模型若需要减速器应另加 9:1 齿轮模块。

## 2. 当前 Model Workspace（34 个）

| 类别 | 参数 | 当前值 | 单位/用途 | 状态 |
|---|---|---:|---|---|
| 电机 | `Rs` | 0.09 | Ω，定子相电阻 | 已引用 |
| 电机 | `Ld` | 61e-6 | H，d 轴电感 | 已引用 |
| 电机 | `Lq` | 61e-6 | H，q 轴电感 | 已引用 |
| 电机 | `psif` | 0.004208 | Wb，永磁磁链 | 已引用 |
| 电机 | `pn` | 21 | 极对数 | 已引用 |
| 电机 | `J` | 5.5e-6 | kg·m²，电机轴惯量 | 已引用 |
| 电机 | `B` | 0.008 | N·m·s/rad，现有建模假设 | 已引用 |
| 直流侧 | `Vdc` | 24 | V，直流母线 | 已引用 |
| 控制 | `BW_I` | 5000 | rad/s，电流环带宽 | 已引用 |
| 控制 | `BW_speed` | 20 | rad/s，速度环声明带宽 | 已引用 |
| 时序 | `Ts` | 5e-6 | s，模型控制/延时步长 | 已引用 |
| PWM | `fpwm` | 20000 | Hz，PWM 频率 | 已引用 |
| PWM | `pwm_min_duty` | 0 | pu，占空比下限 | 已引用 |
| PWM | `pwm_max_duty` | 1 | pu，占空比上限 | 已引用 |
| PWM | `pwm_deadtime_s` | 5e-7 | s | **未引用** |
| PWM | `pwm_min_pulse_duty` | 0.001 | pu | **未引用** |
| 逆变器 | `inverter_voltage_drop_V` | 0.05 | V | **未引用** |
| 电流 ADC | `adc_current_bits` | 12 | bit | **未引用** |
| 电流 ADC | `adc_current_range_A` | 50 | A，限幅 ±50 A | 已引用 |
| 电流 ADC | `adc_current_gain` | 1 | 增益 | 已引用 |
| 电流 ADC | `adc_current_lsb_A` | 0.02442002442 | A/LSB | 已引用 |
| 电流 ADC | `adc_current_offset_a_A` | 0 | A | 已引用 |
| 电流 ADC | `adc_current_offset_b_A` | 0 | A | 已引用 |
| 电流 ADC | `adc_current_offset_c_A` | 0 | A | 已引用 |
| 电流 ADC | `adc_current_noise_std_A` | 0.005 | A | **未引用** |
| 电流 ADC | `adc_current_noise_hz` | 137 | Hz | **未引用** |
| 编码器 | `encoder_counts_per_rev` | 1024 | count/rev | 已引用 |
| 编码器 | `encoder_theta_offset_rad` | 0 | rad | 已引用 |
| 编码器 | `encoder_speed_offset_radps` | 0 | rad/s | 已引用 |
| 编码器 | `encoder_speed_lsb_radps` | 0.001 | rad/s | 已引用 |
| 编码器 | `encoder_theta_noise_rad` | 0.0001 | rad | **未引用** |
| 编码器 | `encoder_speed_noise_radps` | 0.001 | rad/s | **未引用** |
| 编码器 | `encoder_noise_hz` | 83 | Hz | **未引用** |
| 编码器 | `encoder_speed_noise_hz` | 41 | Hz | **未引用** |

当前静态引用 24 个，未引用 10 个。

## 3. 电机模型与派生量

### Surface Mount PMSM

| 参数入口 | 当前表达式 | 当前解析值 |
|---|---|---:|
| 极对数 | `P=pn` | 21 |
| 电阻 | `Rs=Rs` | 0.09 Ω |
| 电感 | `Ldq_=Ld` | 61e-6 H |
| 磁链 | `lambda_pm=psif` | 0.004208 Wb |
| 机械参数 | `mechanical=[J,B,0]` | `[5.5e-6,0.008,0]` |
| dq 初始电流 | `idq0=[0 0]` | `[0,0] A` |
| 初始角度/转速 | `theta_init=0`, `omega_init=0` | 0 rad / 0 rad/s |

理论转矩常数：

```text
Kt = 1.5*pn*psif = 0.132552 N·m/A
```

PMSM Mask 还保存着库内部隐藏/缓存字段，例如旧的 `Kt`、`Ke`、`lambda_pm_calc` 和 `Ldq`；当前用户参数入口明确使用 `pn/Rs/Ld/psif/J/B`，隐藏字段不作为本清单的有效电机参数。

### PWM 与电压

```text
Vdc = 24 V
fpwm = 20 kHz
PWM 周期 = 50 µs
载波时间点 = [0,25,50] µs
占空比限幅 = [0,1]
```

模型电流 PI 电压限幅仍采用 `±Vdc*0.9*sqrt(1/3)`，当前为 `±12.4707658 V`。固件另定义 `Vd/Vq_ref_Max_V=12 V`，本次未改写模型原有限幅公式。

## 4. 控制器派生参数

三个启用控制器仍为 Parallel、Discrete-time、Forward Euler、内部参数、采样时间 `-1`（继承）、初值 0、`AntiWindupMode=none`。

| 控制器 | P | I | 输出限幅 |
|---|---:|---:|---|
| q 轴电流 PI | `BW_I*Lq` = **0.305** | `BW_I*Rs` = **450** | ±12.4707658 V |
| d 轴电流 PI | `BW_I*Ld` = **0.305** | `BW_I*Rs` = **450** | ±12.4707658 V |
| 速度 PI | `BW_speed*J/(1.5*pn*psif)` = **0.0008298629972** | 前式×`BW_speed` = **0.01659725994** | ±30 A |

电流环在固件中的离散每拍积分系数为 `5000*0.09/20000=0.0225`；Simulink PID 保存连续式积分系数 450，并由离散积分器结合采样时间执行。

速度无弱磁基速限幅自动变为：

```text
±Vdc*0.9*sqrt(1/3)/(pn*psif)
= ±141.1230968 rad/s
= ±1347.626 rpm
```

注意：固件当前实际速度 PI 仍硬编码为 `kp=0.1`、每个 5 ms 周期 `ki=0.0005`；基于 `BandWidth_SpeedLoop` 的公式在固件中被注释。因此模型的 `BW_speed=20` 是按头文件声明同步，不是逐系数复现当前固件速度 PI。

## 5. 自动联动变化

- `Speed Setpoint (RPM)` 的 `After=2*pn`：8 → **42**。
- `Constant7/10` 自动解析为 `Ld/Lq=61e-6`。
- `Constant9` 自动解析为 `psif=0.004208`。
- 极对数增益自动解析为 21。
- `1/Vdc` 增益保持 `1/24=0.0416667`。
- PMSM、d/q 电流 PI、速度 PI、解耦前馈和基速限幅均继续引用 Model Workspace，无需改写块内公式。

## 6. 未改变的采样、传感器和仿真配置

- `Ts=5 µs` 保持不变；它仍作为模型的求解/延时步长。固件 PWM 控制周期为 50 µs；若后续要做逐拍固件等效，需要单独审查各控制块的实际采样时间，不能把 powergui 步长直接等同于控制周期。
- powergui：Discrete，`SampleTime=5e-6`，Tustin。
- Simulink：Rapid Accelerator，`0–10 s`，Variable-step / `VariableStepAuto`，`RelTol=1e-3`。
- ADC、编码器、噪声、死区、最小脉宽等参数本次没有调整。
- 模型所有 Load/Init/Start/Stop 回调仍为空。

## 7. 全量原始清单

全量机器可读结果见 `FOC仿真参数原始清单.json`，包含 34 个 Model Workspace 变量、180 个模型块、3008 条块对话框参数和 872 条 Mask 参数。链接库内部实现未展开，但库块的用户参数接口已包含。
