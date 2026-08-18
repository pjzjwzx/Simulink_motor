function out = physical_residual(sample_k, sample_kp1, cfg)
%PHYSICAL_RESIDUAL E05-E08 current prediction residuals for Stage 1.
%   Residual sign is always prediction minus measurement. The selected
%   Stage-1 result is Euler. Midpoint RK2 and Heun outputs are references;
%   no automatic predictor switching is performed.
%
%   SAMPLE_K and SAMPLE_KP1 use the schema documented by QUALITY_GATES.
%   Required CFG motor fields are Ts_s [s], Rs_Ohm [ohm], Ls_H [H], and
%   psi_f_Wb [Wb], plus the quality-gate fields. There are deliberately no
%   truth-state or plant-applied-voltage inputs.

[Ts_s, Rs_Ohm, Ls_H, psi_f_Wb] = resolve_config(cfg);

theta_k_rad = get_theta(sample_k);
theta_kp1_rad = get_theta(sample_kp1);
dtheta_rad = anglelut.wrap_to_pi(theta_kp1_rad - theta_k_rad);
omega_k_radps = get_omega(sample_k);
theta_raw_chord_mid_rad = theta_k_rad + 0.5 * dtheta_rad;
% The quantized raw angle is piecewise constant with one-count jumps.  Its
% finite difference is therefore not a physical frame speed.  Propagate
% the timestamped raw angle to the interval midpoint with the independently
% estimated physical speed, then perform E03 there.
theta_mid_rad = theta_k_rad + 0.5 * Ts_s * omega_k_radps;

iab_k_A = anglelut.clarke_abc(sample_k.iabc_A);
iab_kp1_A = anglelut.clarke_abc(sample_kp1.iabc_A);
idq_k_A = anglelut.park_alphabeta(iab_k_A, theta_mid_rad);
idq_kp1_A = anglelut.park_alphabeta(iab_kp1_A, theta_mid_rad);

v_start = anglelut.reconstruct_voltage(sample_k.duty_abc, ...
                                       sample_k.vdc_V, theta_k_rad);
v_mid = anglelut.reconstruct_voltage(sample_k.duty_abc, ...
                                     sample_k.vdc_V, theta_mid_rad);
v_end = anglelut.reconstruct_voltage(sample_k.duty_abc, ...
                                     sample_k.vdc_V, theta_kp1_rad);

% E05 is integrated in stationary alpha-beta coordinates.  This is the
% same isotropic SPMSM current model with the PM back-EMF term omitted, but
% it is invariant to encoder quantizer frame jumps.  E03 then rotates both
% prediction and measurement into one common continuous-midpoint raw frame.
f_euler_Aps = stationary_rhs_no_pm( ...
    iab_k_A, v_mid.vab_V, Rs_Ohm, Ls_H);
i_euler_ab_A = iab_k_A + Ts_s * f_euler_Aps;
i_euler_A = anglelut.park_alphabeta(i_euler_ab_A, theta_mid_rad);
r_euler_A = i_euler_A - idq_kp1_A;

% Timing-sensitivity comparator: identical Euler alpha-beta prediction,
% evaluated in the interval-start raw frame.
i_euler_start_A = anglelut.park_alphabeta(i_euler_ab_A, theta_k_rad);
idq_kp1_start_A = anglelut.park_alphabeta(iab_kp1_A, theta_k_rad);
r_euler_start_A = i_euler_start_A - idq_kp1_start_A;

% Explicit midpoint RK2 reference; never selected automatically.
k1_rk2_Aps = stationary_rhs_no_pm( ...
    iab_k_A, v_start.vab_V, Rs_Ohm, Ls_H);
i_mid_ab_A = iab_k_A + 0.5 * Ts_s * k1_rk2_Aps;
k2_rk2_Aps = stationary_rhs_no_pm( ...
    i_mid_ab_A, v_mid.vab_V, Rs_Ohm, Ls_H);
i_rk2_ab_A = iab_k_A + Ts_s * k2_rk2_Aps;
i_rk2_A = anglelut.park_alphabeta(i_rk2_ab_A, theta_mid_rad);
r_rk2_A = i_rk2_A - idq_kp1_A;

% Heun explicit trapezoid reference; never selected automatically.
k1_heun_Aps = k1_rk2_Aps;
i_trial_ab_A = iab_k_A + Ts_s * k1_heun_Aps;
k2_heun_Aps = stationary_rhs_no_pm( ...
    i_trial_ab_A, v_end.vab_V, Rs_Ohm, Ls_H);
i_heun_ab_A = iab_k_A + 0.5 * Ts_s * (k1_heun_Aps + k2_heun_Aps);
i_heun_A = anglelut.park_alphabeta(i_heun_ab_A, theta_mid_rad);
r_heun_A = i_heun_A - idq_kp1_A;

direction_sign = double(sample_k.direction_sign);
y_euler_A = direction_sign * r_euler_A;
y_rk2_A = direction_sign * r_rk2_A;
y_heun_A = direction_sign * r_heun_A;

amplitude_euler_A = hypot(y_euler_A(1), y_euler_A(2));
amplitude_rk2_A = hypot(y_rk2_A(1), y_rk2_A(2));
amplitude_heun_A = hypot(y_heun_A(1), y_heun_A(2));
expected_amplitude_A = Ts_s * psi_f_Wb ...
    * abs(omega_k_radps) / Ls_H;

gates = anglelut.quality_gates(sample_k, sample_kp1, idq_k_A, idq_kp1_A, ...
                               amplitude_euler_A, expected_amplitude_A, cfg);

if gates.valid
    % E08 argument order is atan2(y_d, y_q), intentionally not swapped.
    z_euler_rad = atan2(y_euler_A(1), y_euler_A(2));
    z_rk2_rad = atan2(y_rk2_A(1), y_rk2_A(2));
    z_heun_rad = atan2(y_heun_A(1), y_heun_A(2));
else
    z_euler_rad = 0.0;
    z_rk2_rad = 0.0;
    z_heun_rad = 0.0;
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

function [Ts_s, Rs_Ohm, Ls_H, psi_f_Wb] = resolve_config(cfg)
if isfield(cfg, 'timing')
    Ts_s = cfg.timing.T_ident_s;
    Rs_Ohm = cfg.motor.Rs_ohm;
    Ls_H = cfg.motor.Ls_H;
    psi_f_Wb = cfg.motor.psi_f_Wb;
else
    Ts_s = cfg.Ts_s;
    Rs_Ohm = cfg.Rs_Ohm;
    Ls_H = cfg.Ls_H;
    psi_f_Wb = cfg.psi_f_Wb;
end
end

out.theta_mid_e_rad = theta_mid_rad;
out.theta_raw_chord_mid_e_rad = theta_raw_chord_mid_rad;
out.iab_k_A = iab_k_A;
out.iab_kp1_A = iab_kp1_A;
out.idq_k_A = idq_k_A;
out.idq_kp1_A = idq_kp1_A;
out.vabc_reconstructed_V = v_mid.vabc_V;
out.vab_reconstructed_V = v_mid.vab_V;
out.vdq_start_V = v_start.vdq_V;
out.vdq_mid_V = v_mid.vdq_V;
out.vdq_end_V = v_end.vdq_V;

out.euler.i_pred_A = i_euler_A;
out.euler.i_pred_ab_A = i_euler_ab_A;
out.euler.residual_A = r_euler_A;
out.euler.y_A = y_euler_A;
out.euler.z_rad = z_euler_rad;
out.euler.amplitude_A = amplitude_euler_A;

out.euler_start.i_pred_A = i_euler_start_A;
out.euler_start.residual_A = r_euler_start_A;

out.rk2.i_pred_A = i_rk2_A;
out.rk2.i_pred_ab_A = i_rk2_ab_A;
out.rk2.residual_A = r_rk2_A;
out.rk2.y_A = y_rk2_A;
out.rk2.z_rad = z_rk2_rad;
out.rk2.amplitude_A = amplitude_rk2_A;

out.heun.i_pred_A = i_heun_A;
out.heun.i_pred_ab_A = i_heun_ab_A;
out.heun.residual_A = r_heun_A;
out.heun.y_A = y_heun_A;
out.heun.z_rad = z_heun_rad;
out.heun.amplitude_A = amplitude_heun_A;

out.expected_amplitude_A = expected_amplitude_A;
out.gates = gates;
out.valid = gates.valid;
out.z_rad = z_euler_rad;
out.residual_A = r_euler_A;
out.y_A = y_euler_A;
out.amplitude_A = amplitude_euler_A;
out.quality_weight = gates.quality_weight;

end

function diab_Aps = stationary_rhs_no_pm(iab_A, vab_V, Rs_Ohm, Ls_H)
% E05 isotropic current derivative with the PM back-EMF term omitted.
% Stationary coordinates remove only coordinate-motion terms; they do not
% add a truth angle, truth speed, or plant-applied voltage dependency.
diab_Aps = (vab_V - Rs_Ohm * iab_A) / Ls_H;
end
