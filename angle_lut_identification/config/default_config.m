function cfg = default_config()
%DEFAULT_CONFIG Decision-complete configuration for Stage 0 and Stage 1.
%   CFG = DEFAULT_CONFIG() returns only explicit values.  The runner must
%   copy case-specific values into Simulink.SimulationInput; it must not
%   depend on variables left in the base workspace.

configDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(configDir);

cfg.schema_version = "angle-lut-stage1-v1";
cfg.project.root = projectRoot;
cfg.project.baseline_model = fullfile(fileparts(projectRoot), ...
    'FOC_fw_hifi_v1_0709backup.slx');
cfg.project.harness_model = fullfile(projectRoot, 'models', ...
    'angle_lut_harness.slx');
cfg.random_seed = uint32(20260818);
cfg.allowed_status = ["PASS", "FAIL", "BLOCKED"];

% Plant and controller values observed in the baseline model workspace.
cfg.motor.pole_pairs = 21;
cfg.motor.Rs_ohm = 0.09;
cfg.motor.Ld_H = 61e-6;
cfg.motor.Lq_H = 61e-6;
cfg.motor.Ls_H = 61e-6;
cfg.motor.psi_f_Wb = 0.004208;
cfg.motor.viscous_friction_Nm_per_radps = 0.008;
cfg.motor.vdc_nominal_V = 24;
cfg.motor.iq_limit_A = 30;

cfg.timing.base_step_s = 5e-6;
cfg.timing.fpwm_Hz = 20e3;
cfg.timing.T_ident_s = 1 / cfg.timing.fpwm_Hz;
cfg.timing.identification_event_offset_s = cfg.timing.base_step_s;
cfg.timing.angle_sync_sample_Hz = cfg.timing.fpwm_Hz;
cfg.timing.angle_low_rate_sample_Hz = 1e3;
cfg.timing.timestamp_tolerance_s = cfg.timing.base_step_s / 2;
cfg.timing.voltage_angle_primary = "interval_midpoint";
cfg.timing.voltage_angle_sensitivity = "interval_start";

% SensorMode is deliberately distinct from ErrorMode.
cfg.sensor.MODE_LEGACY_ELECTRICAL = uint8(0);
cfg.sensor.MODE_MECHANICAL_STAGE1 = uint8(1);
cfg.sensor.mode = cfg.sensor.MODE_MECHANICAL_STAGE1;
cfg.sensor.mode_name = "MECHANICAL_STAGE1";

cfg.encoder.ERROR_OFF = uint8(0);
cfg.encoder.ERROR_FIXED = uint8(1);
cfg.encoder.ERROR_PERIODIC = uint8(2);
cfg.encoder.error_mode = cfg.encoder.ERROR_PERIODIC;
cfg.encoder.sensor_mode = cfg.sensor.mode;
cfg.encoder.pole_pairs = cfg.motor.pole_pairs;
cfg.encoder.counts_per_rev = 1024;
cfg.encoder.quantization_step_m_rad = 2*pi/cfg.encoder.counts_per_rev;
cfg.encoder.theta0_e_rad = 0;
cfg.encoder.legacy_theta_offset_e_rad = 0;
cfg.encoder.legacy_offset_e_rad = cfg.encoder.legacy_theta_offset_e_rad;
cfg.encoder.fixed_error_e_rad = 0;
cfg.encoder.fixed_bias_m_rad = 0;
cfg.encoder.periodic_bias_m_rad = 0;
cfg.encoder.periodic_amp1_m_rad = deg2rad(0.60);
cfg.encoder.periodic_phase1_rad = 0;
cfg.encoder.periodic_amp2_m_rad = deg2rad(0.30);
cfg.encoder.periodic_phase2_rad = pi/4;
cfg.encoder.quantization_enabled = true;
cfg.encoder.default_peak_bound_e_rad = cfg.motor.pole_pairs * (...
    abs(cfg.encoder.periodic_bias_m_rad) + ...
    abs(cfg.encoder.periodic_amp1_m_rad) + ...
    abs(cfg.encoder.periodic_amp2_m_rad));
cfg.encoder.angle_noise_std_m_rad = 0;
cfg.encoder.sample_Hz = cfg.timing.angle_sync_sample_Hz;
cfg.encoder.extrapolation_enabled = false;
cfg.encoder.extra_delay_s = 0;

cfg.speed_estimator.cutoff_Hz = 50;
cfg.speed_estimator.direction_enter_e_radps = 10;
cfg.speed_estimator.direction_exit_e_radps = 5;
cfg.speed_estimator.initial_omega_e_radps = 0;
cfg.speed_estimator.initial_direction = int8(0);
cfg.speed_estimator.pole_pairs = cfg.motor.pole_pairs;
cfg.speed_estimator.lpf_cutoff_hz = cfg.speed_estimator.cutoff_Hz;
cfg.speed_estimator.min_dt_s = cfg.timing.base_step_s/2;
cfg.speed_estimator.max_dt_s = 2/cfg.timing.angle_low_rate_sample_Hz;

cfg.direction.enter_threshold_e_radps = ...
    cfg.speed_estimator.direction_enter_e_radps;
cfg.direction.exit_threshold_e_radps = ...
    cfg.speed_estimator.direction_exit_e_radps;

cfg.predictor.primary = "euler";
cfg.predictor.references = ["rk2_midpoint", "heun"];
cfg.predictor.allow_automatic_fallback = false;

cfg.reconstruction.clarke_scaling = "amplitude_invariant";
cfg.reconstruction.remove_common_mode = true;
cfg.reconstruction.voltage_source = "reconstructed";

cfg.gating.vdc_valid_fraction = [0.90, 1.10];
cfg.gating.iq_limit_A = cfg.motor.iq_limit_A;
cfg.gating.residual_amplitude_ratio = [0.25, 4.0];
cfg.gating.timestamp_tolerance_s = cfg.timing.timestamp_tolerance_s;
cfg.gating.freeze_on_low_speed = true;
cfg.gating.freeze_on_direction_change = true;
cfg.gating.freeze_on_pwm_saturation = true;
cfg.gating.freeze_on_min_pulse_clipping = true;
cfg.gating.freeze_on_invalid_adc = true;
cfg.gating.freeze_on_current_limit = true;

% Flat, code-facing contract consumed by anglelut.physical_residual.
cfg.residual.Ts_s = cfg.timing.T_ident_s;
cfg.residual.Rs_Ohm = cfg.motor.Rs_ohm;
cfg.residual.Ls_H = cfg.motor.Ls_H;
cfg.residual.psi_f_Wb = cfg.motor.psi_f_Wb;
cfg.residual.speed_observable_min_e_radps = ...
    cfg.speed_estimator.direction_enter_e_radps;
cfg.residual.speed_weight_corner_e_radps = ...
    cfg.speed_estimator.direction_enter_e_radps;
cfg.residual.iq_limit_A = cfg.motor.iq_limit_A;
cfg.residual.vdc_nominal_V = cfg.motor.vdc_nominal_V;
cfg.residual.vdc_tolerance_fraction = 0.10;
cfg.residual.timestamp_tolerance_s = cfg.timing.timestamp_tolerance_s;
cfg.residual.residual_ratio_min = cfg.gating.residual_amplitude_ratio(1);
cfg.residual.residual_ratio_max = cfg.gating.residual_amplitude_ratio(2);

% Values are zero for ideal cases and are overridden explicitly per case.
cfg.nonideal.angle_noise_std_m_rad = 1e-4;
cfg.nonideal.current_noise_std_A = 5e-3;
cfg.nonideal.deadtime_s = 0.5e-6;
cfg.nonideal.min_pulse_duty = 1e-3;
cfg.nonideal.inverter_voltage_drop_V = 0.05;
cfg.nonideal.extra_delay_s = [5e-6, 50e-6];

cfg.simulation.steady_state_time_s = 1;
cfg.simulation.minimum_evaluation_time_s = 2;
cfg.simulation.minimum_mechanical_cycles = 4;
% Allow the +5 us phased identification logger to emit the interval that
% closes the requested evaluation duration.
cfg.simulation.identification_flush_margin_s = cfg.timing.T_ident_s;
cfg.simulation.default_load_torque_Nm = 1;
cfg.simulation.default_speed_m_radps = 10;
cfg.simulation.stop_time_rule = ...
    "1 + max(2, 8*pi/abs(omega_m_radps)) + T_ident";
cfg.simulation.log_decimation = 1;

cfg.stage1.enable_lut_learning = false;
cfg.stage1.control_compensation_e_rad = 0;
cfg.stage1.reference_lut_nodes = 128;
cfg.stage1.run_voltage_ab_evaluation = true;

cfg.buses = bus_definitions(false);
cfg.gates = stage_gates();
end
