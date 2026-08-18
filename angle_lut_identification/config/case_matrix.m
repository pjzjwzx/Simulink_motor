function cases = case_matrix(cfg)
%CASE_MATRIX Explicit Stage 1 simulation cases (not a hidden Cartesian sweep).
%   Every returned case contains every mutable simulation parameter so that
%   run_stage1 can transfer it to Simulink.SimulationInput explicitly.

if nargin < 1
    cfg = default_config();
end

b = baseCase(cfg);
cases = repmat(b, 0, 1);

% Baseline equivalence and fixed electrical offsets.
cases(end+1) = makeCase(cfg, b, "baseline_legacy_equivalence", "baseline", struct( ...
    'sensor_mode', cfg.sensor.MODE_LEGACY_ELECTRICAL, ...
    'error_mode', cfg.encoder.ERROR_OFF, ...
    'expected_class', "baseline_equivalence"));
fixedDeg = [0, 5, 10, 20];
for k = 1:numel(fixedDeg)
    cases(end+1) = makeCase(cfg, b, compose("fixed_%02ddeg_e", fixedDeg(k)), ...
        "fixed_error", struct('error_mode', cfg.encoder.ERROR_FIXED, ...
        'fixed_error_e_rad', deg2rad(fixedDeg(k))));
end

% Constant, pure 1x, pure 2x, and the selected combined waveform.
cases(end+1) = makeCase(cfg, b, "periodic_constant", "periodic_error", struct( ...
    'periodic_bias_m_rad', deg2rad(0.40), ...
    'periodic_amp1_m_rad', 0, 'periodic_amp2_m_rad', 0));
cases(end+1) = makeCase(cfg, b, "periodic_1x", "periodic_error", struct( ...
    'periodic_amp1_m_rad', deg2rad(0.60), ...
    'periodic_amp2_m_rad', 0));
cases(end+1) = makeCase(cfg, b, "periodic_2x", "periodic_error", struct( ...
    'periodic_amp1_m_rad', 0, ...
    'periodic_amp2_m_rad', deg2rad(0.30), ...
    'periodic_phase2_rad', pi/4));
cases(end+1) = makeCase(cfg, b, "periodic_combined", "periodic_error", struct());

% Direction and speed coverage.
for speed = [-20, -10, -5, 5, 10, 20]
    cases(end+1) = makeCase(cfg, b, compose("speed_%+03dradps_m", speed), ...
        "speed_direction", struct('omega_m_radps', speed));
end

% Load coverage.
for loadNm = [0, 1, 2]
    cases(end+1) = makeCase(cfg, b, compose("load_%dNm", loadNm), ...
        "load", struct('load_torque_Nm', loadNm));
end

% One-at-a-time predictor parameter mismatch.
names = ["Rs", "Ls", "psi"];
fields = ["Rs_scale", "Ls_scale", "psi_f_scale"];
for n = 1:numel(names)
    for scale = [0.9, 1.1]
        overrides = struct();
        overrides.(fields(n)) = scale;
        cases(end+1) = makeCase(cfg, b, ...
            compose("mismatch_%s_%+dpercent", names(n), round(100*(scale-1))), ...
            "parameter_mismatch", overrides);
    end
end

% Synchronous and timestamp-extrapolated encoder paths.
cases(end+1) = makeCase(cfg, b, "angle_sync_20kHz", "angle_sampling", struct( ...
    'angle_sample_Hz', 20e3, 'angle_extrapolation_enabled', false));
cases(end+1) = makeCase(cfg, b, "angle_timestamped_1kHz", "angle_sampling", struct( ...
    'angle_sample_Hz', 1e3, 'angle_extrapolation_enabled', true));

% Individual and combined nonidealities.
cases(end+1) = makeCase(cfg, b, "nonideal_angle_noise", "nonideal", struct( ...
    'angle_noise_std_m_rad', cfg.nonideal.angle_noise_std_m_rad));
cases(end+1) = makeCase(cfg, b, "nonideal_current_noise", "nonideal", struct( ...
    'current_noise_std_A', cfg.nonideal.current_noise_std_A));
cases(end+1) = makeCase(cfg, b, "nonideal_deadtime", "nonideal", struct( ...
    'deadtime_s', cfg.nonideal.deadtime_s));
cases(end+1) = makeCase(cfg, b, "nonideal_min_pulse", "nonideal", struct( ...
    'min_pulse_duty', cfg.nonideal.min_pulse_duty));
cases(end+1) = makeCase(cfg, b, "nonideal_voltage_drop", "nonideal", struct( ...
    'inverter_voltage_drop_V', cfg.nonideal.inverter_voltage_drop_V));
cases(end+1) = makeCase(cfg, b, "nonideal_delay_5us", "nonideal", struct( ...
    'extra_sensor_delay_s', 5e-6));
cases(end+1) = makeCase(cfg, b, "nonideal_delay_50us", "nonideal", struct( ...
    'extra_sensor_delay_s', 50e-6));
cases(end+1) = makeCase(cfg, b, "nonideal_combined", "nonideal", struct( ...
    'angle_sample_Hz', 1e3, 'angle_extrapolation_enabled', true, ...
    'angle_noise_std_m_rad', cfg.nonideal.angle_noise_std_m_rad, ...
    'current_noise_std_A', cfg.nonideal.current_noise_std_A, ...
    'deadtime_s', cfg.nonideal.deadtime_s, ...
    'min_pulse_duty', cfg.nonideal.min_pulse_duty, ...
    'inverter_voltage_drop_V', cfg.nonideal.inverter_voltage_drop_V, ...
    'extra_sensor_delay_s', 5e-6));

% Truth voltage is allowed only for this independent A/B evaluation case.
cases(end+1) = makeCase(cfg, b, "voltage_ab_reconstructed", "voltage_ab", struct( ...
    'voltage_source', "reconstructed"));
cases(end+1) = makeCase(cfg, b, "voltage_ab_plant_evaluation", "voltage_ab", struct( ...
    'voltage_source', "plant_evaluation"));

% Stable order and unique IDs are part of the result contract.
[~, first] = unique([cases.case_id], 'stable');
assert(numel(first) == numel(cases), 'anglelut:DuplicateCaseId', ...
    'case_matrix produced duplicate case IDs.');
assert(numel(cases) == 36, 'anglelut:CaseMatrixContract', ...
    'Stage 1 requires exactly 36 explicit cases; got %d.', numel(cases));
end

function c = baseCase(cfg)
c.case_id = "";
c.group = "";
c.enabled = true;
c.random_seed = cfg.random_seed;
c.sensor_mode = cfg.sensor.MODE_MECHANICAL_STAGE1;
c.error_mode = cfg.encoder.ERROR_PERIODIC;
c.fixed_error_e_rad = 0;
c.periodic_bias_m_rad = cfg.encoder.periodic_bias_m_rad;
c.periodic_amp1_m_rad = cfg.encoder.periodic_amp1_m_rad;
c.periodic_phase1_rad = cfg.encoder.periodic_phase1_rad;
c.periodic_amp2_m_rad = cfg.encoder.periodic_amp2_m_rad;
c.periodic_phase2_rad = cfg.encoder.periodic_phase2_rad;
c.theta0_e_rad = cfg.encoder.theta0_e_rad;
c.encoder_counts_per_rev = cfg.encoder.counts_per_rev;
c.omega_m_radps = cfg.simulation.default_speed_m_radps;
c.load_torque_Nm = cfg.simulation.default_load_torque_Nm;
c.Rs_scale = 1;
c.Ls_scale = 1;
c.psi_f_scale = 1;
c.angle_sample_Hz = cfg.timing.angle_sync_sample_Hz;
c.angle_extrapolation_enabled = false;
c.angle_noise_std_m_rad = 0;
c.current_noise_std_A = 0;
c.deadtime_s = 0;
c.min_pulse_duty = 0;
c.inverter_voltage_drop_V = 0;
c.extra_sensor_delay_s = 0;
c.voltage_source = "reconstructed";
c.predictor = cfg.predictor.primary;
c.expected_class = "ideal";
c.stop_time_s = stopTime(cfg, c.omega_m_radps);
end

function c = makeCase(cfg, base, id, group, overrides)
c = base;
c.case_id = string(id);
c.group = string(group);
fields = fieldnames(overrides);
for k = 1:numel(fields)
    c.(fields{k}) = overrides.(fields{k});
end
if c.group == "nonideal" || c.group == "parameter_mismatch"
    c.expected_class = "nonideal";
end
c.stop_time_s = stopTime(cfg, c.omega_m_radps);
end

function t = stopTime(cfg, omegaM)
assert(isfinite(omegaM) && omegaM ~= 0, ...
    'anglelut:InvalidCaseSpeed', 'Stage 1 cases require nonzero speed.');
t = cfg.simulation.steady_state_time_s + max( ...
    cfg.simulation.minimum_evaluation_time_s, ...
    2*pi*cfg.simulation.minimum_mechanical_cycles/abs(omegaM)) + ...
    cfg.simulation.identification_flush_margin_s;
end
