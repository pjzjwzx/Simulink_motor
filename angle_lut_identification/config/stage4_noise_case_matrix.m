function matrix = stage4_noise_case_matrix(cfg)
%STAGE4_NOISE_CASE_MATRIX Locked zero/high-current-noise diagnostic cases.

baseMatrix = stage2_case_matrix(cfg);
index = find(string({baseMatrix.training.case_id}) == ...
    cfg.stage2.primary_profile_id,1);
assert(~isempty(index),'anglelut:Stage4PrimaryCaseMissing', ...
    'The periodic_combined Stage-2 profile is required by Stage 4.');
base = baseMatrix.training(index);
base.omega_m_radps = 10;
base.load_torque_Nm = 1;
base.angle_sample_Hz = cfg.timing.angle_sync_sample_Hz;
base.angle_extrapolation_enabled = false;
base.angle_noise_std_m_rad = 0;
base.deadtime_s = 0;
base.min_pulse_duty = 0;
base.inverter_voltage_drop_V = 0;
base.extra_sensor_delay_s = 0;
base.random_seed = cfg.stage4.random_seed;
base.stop_time_s = local_stop_time(cfg,base.omega_m_radps, ...
    cfg.stage4.training_mechanical_cycles);

zero = base;
zero.case_id = "periodic_combined_zero_noise";
zero.current_noise_std_A = 0;
zero.stage2_expected_class = "ideal";

noisy = base;
noisy.case_id = "periodic_combined_noise95_pm0p1A";
noisy.group = "nonideal";
noisy.current_noise_std_A = cfg.stage4.noise_sigma_A;
noisy.stage2_expected_class = "nonideal";

freezeZero = zero;
freezeZero.stop_time_s = local_stop_time(cfg,freezeZero.omega_m_radps, ...
    cfg.stage4.frozen_mechanical_cycles);
freezeNoisy = noisy;
freezeNoisy.stop_time_s = local_stop_time(cfg,freezeNoisy.omega_m_radps, ...
    cfg.stage4.frozen_mechanical_cycles);

matrix = struct();
matrix.schema_version = "stage4-noise-diagnostic-matrix-v1";
matrix.training = [zero,noisy];
matrix.evaluation = [freezeZero,freezeNoisy];
matrix.training_condition = ["zero_noise","noise95_pm0p1A"];
matrix.evaluation_condition = matrix.training_condition;
matrix.cross_freeze = true;
matrix.baseline_simulation_count = 2;
matrix.active_simulation_count = 4;
matrix.total_frozen_simulation_count = 6;
matrix.primary_profile = "periodic_combined";
matrix.noise_definition = struct( ...
    'distribution','independent zero-mean Gaussian', ...
    'sigma_A',cfg.stage4.noise_sigma_A, ...
    'requested_95_percent_half_width_A', ...
    cfg.stage4.noise_95_half_width_A, ...
    'injection_point','post-ADC-quantizer identification measurement', ...
    'adc_quantization_enabled_in_both_conditions',true, ...
    'adc_current_lsb_A',cfg.stage4.adc_current_lsb_A, ...
    'random_seed',cfg.stage4.random_seed);
end

function t = local_stop_time(cfg,omegaM,cycles)
t = cfg.simulation.steady_state_time_s + max( ...
    cfg.simulation.minimum_evaluation_time_s,2*pi*cycles/abs(omegaM)) + ...
    cfg.simulation.identification_flush_margin_s;
end
