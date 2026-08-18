function out = extrapolate_angle(theta_m_unwrapped_rad, omega_m_radps, ...
                                 measurement_timestamp_s, target_timestamp_s, ...
                                 pole_pairs, theta0_e_rad)
%EXTRAPOLATE_ANGLE Align a timestamped raw angle to a target sample time.
%   All estimates are derived from raw encoder angle and estimated speed.
%   No true rotor state is accepted. Angles are in radians and timestamps
%   are in seconds.

dt_s = target_timestamp_s - measurement_timestamp_s;
theta_m_target_unwrapped_rad = theta_m_unwrapped_rad + omega_m_radps * dt_s;
theta_m_target_rad = anglelut.wrap_to_2pi(theta_m_target_unwrapped_rad);
theta_e_target_rad = pole_pairs * theta_m_target_rad + theta0_e_rad;

out.dt_s = dt_s;
out.theta_m_unwrapped_rad = theta_m_target_unwrapped_rad;
out.theta_m_rad = theta_m_target_rad;
out.theta_e_rad = theta_e_target_rad;
out.valid = isfinite(theta_m_unwrapped_rad) && isfinite(omega_m_radps) ...
    && isfinite(measurement_timestamp_s) && isfinite(target_timestamp_s) ...
    && (dt_s >= 0.0);

end
