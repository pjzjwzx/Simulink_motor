function gates = quality_gates(sample_k, sample_kp1, idq_k_A, idq_kp1_A, ...
                               residual_amplitude_A, expected_amplitude_A, cfg)
%QUALITY_GATES Stage-1 hard gates and E50-compatible quality weight.
%   This deployment function accepts only measured/reconstructed signals and
%   validity metadata. It has no truth-angle, truth-speed, or plant-voltage
%   input.
%
%   Required sample fields follow IdentificationBus:
%     iabc_A[3], duty_abc[3], vdc_V, theta_e_raw_rad,
%     omega_e_est_radps,
%     direction_sign(int8), direction_valid, adc_valid,
%     encoder_valid, pwm_saturated, min_pulse_clipped,
%     current_limited, timestamp_s, current_timestamp_s,
%     angle_timestamp_s, duty_timestamp_s.
%
%   Required CFG fields:
%     Ts_s, speed_observable_min_e_radps, speed_weight_corner_e_radps,
%     iq_limit_A, vdc_nominal_V, vdc_tolerance_fraction,
%     timestamp_tolerance_s, residual_ratio_min, residual_ratio_max.

[Ts_s, speed_min_radps, speed_corner_radps, iq_limit_A, ...
    vdc_nominal_V, vdc_fraction, timestamp_tolerance_s, ...
    residual_ratio_bounds] = resolve_config(cfg);
omega_e_radps = get_omega(sample_k);
speed_ok = isfinite(omega_e_radps) ...
    && (abs(omega_e_radps) >= speed_min_radps);
direction_ok = sample_k.direction_valid ...
    && ((sample_k.direction_sign == int8(1)) ...
        || (sample_k.direction_sign == int8(-1)));

pwm_overmodulated = false;
if isfield(sample_k, 'pwm_overmodulated')
    pwm_overmodulated = sample_k.pwm_overmodulated;
end
pwm_ok = ~(sample_k.pwm_saturated || pwm_overmodulated ...
           || sample_k.min_pulse_clipped);
adc_ok = sample_k.adc_valid && sample_kp1.adc_valid;
encoder_ok = true;
if isfield(sample_k, 'encoder_valid')
    encoder_ok = sample_k.encoder_valid && sample_kp1.encoder_valid;
end

iq_peak_A = max(abs(idq_k_A(2)), abs(idq_kp1_A(2)));
current_limit_ok = ~(sample_k.current_limited || sample_kp1.current_limited) ...
    && isfinite(iq_peak_A) && (iq_peak_A < iq_limit_A);

vdc_lower_V = vdc_nominal_V * vdc_fraction(1);
vdc_upper_V = vdc_nominal_V * vdc_fraction(2);
vdc_ok = isfinite(sample_k.vdc_V) && (sample_k.vdc_V >= vdc_lower_V) ...
    && (sample_k.vdc_V <= vdc_upper_V);

tol_s = timestamp_tolerance_s;
timestamp_interval_s = sample_kp1.timestamp_s - sample_k.timestamp_s;
timestamp_ok = isfinite(timestamp_interval_s) ...
    && (abs(timestamp_interval_s - Ts_s) <= tol_s) ...
    && (abs(sample_k.current_timestamp_s - sample_k.timestamp_s) <= tol_s) ...
    && (abs(sample_k.angle_timestamp_s - sample_k.timestamp_s) <= tol_s) ...
    && (abs(get_duty_timestamp(sample_k) - sample_k.timestamp_s) <= tol_s) ...
    && (abs(sample_kp1.current_timestamp_s - sample_kp1.timestamp_s) <= tol_s) ...
    && (abs(sample_kp1.angle_timestamp_s - sample_kp1.timestamp_s) <= tol_s);

expected_amplitude_ok = isfinite(expected_amplitude_A) ...
    && (expected_amplitude_A > 0.0);
if expected_amplitude_ok
    residual_ratio = residual_amplitude_A / expected_amplitude_A;
else
    residual_ratio = 0.0;
end
residual_ratio_ok = expected_amplitude_ok && isfinite(residual_amplitude_A) ...
    && isfinite(residual_ratio) ...
    && (residual_ratio >= residual_ratio_bounds(1)) ...
    && (residual_ratio <= residual_ratio_bounds(2));

signals_finite = all(isfinite(sample_k.iabc_A)) ...
    && all(isfinite(sample_kp1.iabc_A)) ...
    && all(isfinite(sample_k.duty_abc)) ...
    && isfinite(get_theta(sample_k)) ...
    && isfinite(get_theta(sample_kp1)) ...
    && isfinite(get_omega(sample_kp1));

valid = speed_ok && direction_ok && pwm_ok && adc_ok && encoder_ok ...
    && current_limit_ok && vdc_ok && timestamp_ok ...
    && residual_ratio_ok && signals_finite;

omega_sq = omega_e_radps * omega_e_radps;
corner_sq = speed_corner_radps * speed_corner_radps;
speed_weight = omega_sq / (omega_sq + corner_sq);
if ~isfinite(speed_weight)
    speed_weight = 0.0;
end
amplitude_weight = double(residual_ratio_ok);
quality_weight = double(valid) * speed_weight * amplitude_weight;

gates.speed_ok = speed_ok;
gates.direction_ok = direction_ok;
gates.pwm_ok = pwm_ok;
gates.adc_ok = adc_ok;
gates.encoder_ok = encoder_ok;
gates.current_limit_ok = current_limit_ok;
gates.vdc_ok = vdc_ok;
gates.timestamp_ok = timestamp_ok;
gates.residual_ratio_ok = residual_ratio_ok;
gates.signals_finite = signals_finite;
gates.valid = valid;
gates.residual_ratio = residual_ratio;
gates.speed_weight = speed_weight;
gates.amplitude_weight = amplitude_weight;
gates.quality_weight = quality_weight;

end

function theta_e_rad = get_theta(sample)
if isfield(sample, 'theta_e_raw_rad')
    theta_e_rad = sample.theta_e_raw_rad;
else
    theta_e_rad = sample.theta_e_rad;
end
end

function omega_e_radps = get_omega(sample)
if isfield(sample, 'omega_e_est_radps')
    omega_e_radps = sample.omega_e_est_radps;
else
    omega_e_radps = sample.omega_e_radps;
end
end

function timestamp_s = get_duty_timestamp(sample)
if isfield(sample, 'duty_timestamp_s')
    timestamp_s = sample.duty_timestamp_s;
else
    timestamp_s = sample.voltage_timestamp_s;
end
end

function [Ts_s, speed_min_radps, speed_corner_radps, iq_limit_A, ...
          vdc_nominal_V, vdc_fraction, timestamp_tolerance_s, ...
          residual_ratio_bounds] = resolve_config(cfg)
if isfield(cfg, 'timing')
    Ts_s = cfg.timing.T_ident_s;
    speed_min_radps = cfg.speed_estimator.direction_enter_e_radps;
    speed_corner_radps = cfg.speed_estimator.direction_enter_e_radps;
    iq_limit_A = cfg.gating.iq_limit_A;
    vdc_nominal_V = cfg.motor.vdc_nominal_V;
    vdc_fraction = cfg.gating.vdc_valid_fraction;
    timestamp_tolerance_s = cfg.gating.timestamp_tolerance_s;
    residual_ratio_bounds = cfg.gating.residual_amplitude_ratio;
else
    Ts_s = cfg.Ts_s;
    speed_min_radps = cfg.speed_observable_min_e_radps;
    speed_corner_radps = cfg.speed_weight_corner_e_radps;
    iq_limit_A = cfg.iq_limit_A;
    vdc_nominal_V = cfg.vdc_nominal_V;
    vdc_fraction = [1.0 - cfg.vdc_tolerance_fraction, ...
                     1.0 + cfg.vdc_tolerance_fraction];
    timestamp_tolerance_s = cfg.timestamp_tolerance_s;
    residual_ratio_bounds = [cfg.residual_ratio_min, cfg.residual_ratio_max];
end
end
