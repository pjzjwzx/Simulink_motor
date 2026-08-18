function [out, state_next] = estimate_speed_step(theta_m_rad, timestamp_s, state, cfg)
%ESTIMATE_SPEED_STEP Unwrap raw mechanical angle and estimate speed.
%   The estimator uses only raw encoder angle and its timestamp. It never
%   accepts plant/rotor true speed. A first-order low-pass filter is applied
%   to the timestamped difference.
%
%   CFG may be DEFAULT_CONFIG's full project struct or a flat subset with:
%     pole_pairs       motor pole-pair count
%     lpf_cutoff_hz    speed-estimator cutoff frequency [Hz]
%     min_dt_s         minimum valid timestamp increment [s]
%     max_dt_s         maximum valid timestamp increment [s]

[pole_pairs, lpf_cutoff_hz, min_dt_s, max_dt_s] = resolve_config(cfg);
state_next = state;
theta_wrapped_rad = anglelut.wrap_to_2pi(theta_m_rad);

out.theta_m_wrapped_rad = theta_wrapped_rad;
out.theta_m_unwrapped_rad = state.theta_m_unwrapped_rad;
out.omega_m_raw_radps = 0.0;
out.omega_m_radps = state.omega_m_filt_radps;
out.omega_e_radps = pole_pairs * state.omega_m_filt_radps;
out.omega_e_est_radps = out.omega_e_radps;
out.dt_s = 0.0;
out.valid = false;

input_finite = isfinite(theta_wrapped_rad) && isfinite(timestamp_s);
if ~state.initialized
    if input_finite
        state_next.initialized = true;
        state_next.theta_m_wrapped_prev_rad = theta_wrapped_rad;
        state_next.theta_m_unwrapped_rad = theta_wrapped_rad;
        state_next.timestamp_prev_s = timestamp_s;
        state_next.omega_m_filt_radps = 0.0;
        out.theta_m_unwrapped_rad = theta_wrapped_rad;
    end
    return;
end

dt_s = timestamp_s - state.timestamp_prev_s;
out.dt_s = dt_s;
timestamp_valid = input_finite && isfinite(dt_s) ...
    && (dt_s >= min_dt_s) && (dt_s <= max_dt_s);

if ~timestamp_valid
    % A long positive gap can alias multiple turns. Resynchronize the
    % wrapped sample and timestamp without inventing an unwrapped increment.
    if input_finite && (dt_s > 0.0)
        state_next.theta_m_wrapped_prev_rad = theta_wrapped_rad;
        state_next.timestamp_prev_s = timestamp_s;
    end
    return;
end

dtheta_m_rad = anglelut.wrap_to_pi(theta_wrapped_rad ...
                                   - state.theta_m_wrapped_prev_rad);
theta_unwrapped_rad = state.theta_m_unwrapped_rad + dtheta_m_rad;
omega_raw_radps = dtheta_m_rad / dt_s;

alpha = 1.0 - exp(-2.0 * pi * lpf_cutoff_hz * dt_s);
omega_filt_radps = state.omega_m_filt_radps ...
    + alpha * (omega_raw_radps - state.omega_m_filt_radps);

state_next.theta_m_wrapped_prev_rad = theta_wrapped_rad;
state_next.theta_m_unwrapped_rad = theta_unwrapped_rad;
state_next.timestamp_prev_s = timestamp_s;
state_next.omega_m_filt_radps = omega_filt_radps;

out.theta_m_unwrapped_rad = theta_unwrapped_rad;
out.omega_m_raw_radps = omega_raw_radps;
out.omega_m_radps = omega_filt_radps;
out.omega_e_radps = pole_pairs * omega_filt_radps;
out.omega_e_est_radps = out.omega_e_radps;
out.valid = true;

end

function [pole_pairs, lpf_cutoff_hz, min_dt_s, max_dt_s] = resolve_config(cfg)
if isfield(cfg, 'speed_estimator')
    pole_pairs = cfg.motor.pole_pairs;
    lpf_cutoff_hz = cfg.speed_estimator.cutoff_Hz;
    nominal_dt_s = 1.0 / cfg.encoder.sample_Hz;
    min_dt_s = 0.5 * nominal_dt_s;
    max_dt_s = 1.5 * nominal_dt_s;
else
    pole_pairs = cfg.pole_pairs;
    lpf_cutoff_hz = cfg.lpf_cutoff_hz;
    min_dt_s = cfg.min_dt_s;
    max_dt_s = cfg.max_dt_s;
end
end
