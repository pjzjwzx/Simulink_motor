function out = evaluate_voltage_ab(identificationBus, deploymentResult, ...
    plant_vabc_V, cfg)
%EVALUATE_VOLTAGE_AB Independent evaluation-only plant/reconstructed A/B.
%   OUT = EVALUATE_VOLTAGE_AB(IDENTIFICATIONBUS, DEPLOYMENTRESULT,
%   PLANT_VABC_V, CFG) compares the already-completed reconstructed-voltage
%   deployment residual with a separate plant-applied-voltage residual.
%
%   This helper is intentionally outside +anglelut deployment code.  The
%   plant branch:
%     * is evaluated only after DEPLOYMENTRESULT exists for every interval;
%     * never calls QUALITY_GATES and copies DEPLOYMENTRESULT.valid exactly;
%     * uses no truth angle, truth speed, or injected-error signal;
%     * preserves the E05-E08 conventions used by PHYSICAL_RESIDUAL:
%       stationary-alpha-beta Euler, continuous-midpoint raw-angle Park,
%       prediction minus measurement, y = direction_sign*r, and
%       atan2(y_d,y_q).
%
%   PLANT_VABC_V contains one interval-average phase-voltage row per
%   boundary pair.  Its kth row represents boundary k -> k+1.  A/B delta
%   fields are always defined as plant_evaluation minus reconstructed.

validate_identification_bus(identificationBus);
validate_deployment_result(deploymentResult);

[Ts_s, Rs_Ohm, Ls_H] = resolve_config(cfg);
iabc_A = require_matrix_shape(identificationBus.iabc_A, 3, ...
    'IdentificationBus.iabc_A');
duty_abc = require_matrix_shape(identificationBus.duty_abc, 3, ...
    'IdentificationBus.duty_abc');
vdc_V = require_column_shape(identificationBus.vdc_V, ...
    'IdentificationBus.vdc_V');
theta_e_rad = require_column_shape(identificationBus.theta_e_rad, ...
    'IdentificationBus.theta_e_rad');
omega_e_radps = require_column_shape(identificationBus.omega_e_radps, ...
    'IdentificationBus.omega_e_radps');
direction_sign = require_column_shape(identificationBus.direction_sign, ...
    'IdentificationBus.direction_sign');

n = size(iabc_A,1);
assert(n >= 2, 'anglelut:VoltageABTooFewSamples', ...
    'Voltage A/B evaluation requires at least two boundary records.');
assert(all([size(duty_abc,1), numel(vdc_V), numel(theta_e_rad), ...
    numel(omega_e_radps), numel(direction_sign)] == n), ...
    'anglelut:VoltageABLengthMismatch', ...
    'IdentificationBus fields must have one row per boundary record.');

m = n - 1;
plant_vabc_V = require_matrix_shape(plant_vabc_V, 3, 'plant_vabc_V');
assert(size(plant_vabc_V,1) == m, ...
    'anglelut:VoltageABLengthMismatch', ...
    'plant_vabc_V must contain exactly N-1 interval-average rows.');

reconstructed = normalize_deployment_result(deploymentResult, m);
valid = reconstructed.valid;
plantResidual_A = nan(m,2);
plantY_A = nan(m,2);
plantZ_rad = zeros(m,1);
plantAmplitude_A = nan(m,1);
plantVabc_V = plant_vabc_V;
plantVabc_V(~valid,:) = NaN;

for k = 1:m
    if ~valid(k)
        % A delayed interval-average signal has no support on its leading
        % row.  Preserve that row as unavailable: do not fabricate,
        % extrapolate, or allow it to enter an A/B summary.
        continue;
    end
    validate_valid_interval(k,iabc_A,theta_e_rad,omega_e_radps, ...
        direction_sign,plant_vabc_V,reconstructed);

    % This is the stationary-alpha-beta Euler path in physical_residual.
    % No plant-derived value is used to decide whether the sample is valid.
    iab_k_A = anglelut.clarke_abc(iabc_A(k,:).');
    iab_kp1_A = anglelut.clarke_abc(iabc_A(k+1,:).');
    vab_plant_V = anglelut.clarke_abc(plant_vabc_V(k,:).');
    theta_mid_e_rad = theta_e_rad(k) + 0.5 * Ts_s * omega_e_radps(k);

    derivative_Aps = (vab_plant_V - Rs_Ohm * iab_k_A) / Ls_H;
    i_pred_ab_A = iab_k_A + Ts_s * derivative_Aps;
    i_pred_dq_A = anglelut.park_alphabeta(i_pred_ab_A, theta_mid_e_rad);
    i_meas_dq_A = anglelut.park_alphabeta(iab_kp1_A, theta_mid_e_rad);

    residual_dq_A = i_pred_dq_A - i_meas_dq_A;
    y_dq_A = double(direction_sign(k)) * residual_dq_A;
    amplitude_A = hypot(y_dq_A(1), y_dq_A(2));

    plantResidual_A(k,:) = residual_dq_A.';
    plantY_A(k,:) = y_dq_A.';
    plantAmplitude_A(k) = amplitude_A;
    plantZ_rad(k) = atan2(y_dq_A(1), y_dq_A(2));
end

deltaResidual_A = plantResidual_A - reconstructed.residual_A;
deltaY_A = plantY_A - reconstructed.y_A;
deltaZ_rad = anglelut.wrap_to_pi(plantZ_rad - reconstructed.z_rad);
deltaAmplitude_A = plantAmplitude_A - reconstructed.amplitude_A;
deltaVabc_V = plantVabc_V - reconstructed.vabc_V;
deltaResidual_A(~valid,:) = NaN;
deltaY_A(~valid,:) = NaN;
deltaZ_rad(~valid) = NaN;
deltaAmplitude_A(~valid) = NaN;
deltaVabc_V(~valid,:) = NaN;

out = struct();
out.schema_version = "stage1-voltage-ab-v1";
out.source_a = "reconstructed_duty_vdc";
out.source_b = "plant_applied_evaluation_only";
out.gate_source = "reconstructed_deployment_only";
out.reconstructed = reconstructed;
out.plant_evaluation = struct( ...
    'residual_A',plantResidual_A, ...
    'y_A',plantY_A, ...
    'z_rad',plantZ_rad, ...
    'amplitude_A',plantAmplitude_A, ...
    'vabc_V',plantVabc_V);
out.delta = struct( ...
    'residual_A',deltaResidual_A, ...
    'y_A',deltaY_A, ...
    'z_rad',deltaZ_rad, ...
    'amplitude_A',deltaAmplitude_A, ...
    'vabc_V',deltaVabc_V);
out.valid = valid;

validDeltaZ_rad = deltaZ_rad(valid);
validDeltaResidual_A = deltaResidual_A(valid,:);
out.summary = struct();
out.summary.sample_count = m;
out.summary.valid_sample_count = nnz(valid);
out.summary.voltage_delta_rms_V = local_rms(deltaVabc_V);
out.summary.residual_delta_rms_A = local_rms(validDeltaResidual_A);
out.summary.pseudo_angle_delta_rms_e_rad = local_rms(validDeltaZ_rad);
out.summary.pseudo_angle_delta_rms_e_deg = ...
    rad2deg(out.summary.pseudo_angle_delta_rms_e_rad);
out.summary.pseudo_angle_delta_mean_e_rad = ...
    local_circular_mean(validDeltaZ_rad);
out.summary.pseudo_angle_delta_mean_e_deg = ...
    rad2deg(out.summary.pseudo_angle_delta_mean_e_rad);

scaleValues = [abs(reconstructed.vabc_V(:)); abs(plantVabc_V(:)); ...
    abs(reconstructed.residual_A(:)); abs(plantResidual_A(:))];
scaleValues = scaleValues(isfinite(scaleValues));
scale = max([1;scaleValues]);
distinctTolerance = 128 * eps(scale);
out.summary.branches_numerically_distinct = ...
    any(abs(deltaVabc_V(isfinite(deltaVabc_V))) > distinctTolerance) || ...
    any(abs(deltaResidual_A(isfinite(deltaResidual_A))) > distinctTolerance);
end

function validate_identification_bus(bus)
assert(isstruct(bus) && isscalar(bus), 'anglelut:VoltageABInterface', ...
    'IdentificationBus must be a scalar structure-of-arrays.');
required = ["iabc_A", "duty_abc", "vdc_V", "theta_e_rad", ...
    "omega_e_radps", "direction_sign"];
assert(all(isfield(bus,required)), 'anglelut:VoltageABInterface', ...
    'IdentificationBus is missing a required deployment field.');

forbidden = lower(["EvaluationTruthBus", "theta_m_true_rad", ...
    "theta_e_true_rad", "omega_m_true_radps", "omega_e_true_radps", ...
    "injected_error_m_rad", "injected_error_e_rad", ...
    "plant_vabc_V", "plant_vdq_V"]);
present = lower(string(fieldnames(bus)));
assert(isempty(intersect(present,forbidden)), ...
    'anglelut:VoltageABTruthLeak', ...
    'Truth or plant-evaluation data must not be embedded in IdentificationBus.');
end

function validate_deployment_result(result)
assert(isstruct(result) && isscalar(result), 'anglelut:VoltageABInterface', ...
    'deploymentResult must be a scalar structure-of-arrays.');
required = ["source", "residual_A", "y_A", "z_rad", "amplitude_A", ...
    "valid", "vabc_reconstructed_V"];
assert(all(isfield(result,required)), 'anglelut:VoltageABInterface', ...
    'deploymentResult is incomplete.');
assert(string(result.source) == "reconstructed_duty_vdc", ...
    'anglelut:VoltageABDeploymentSource', ...
    'A/B evaluation requires a completed reconstructed-voltage deployment result.');
end

function result = normalize_deployment_result(input, sampleCount)
result = struct();
result.source = "reconstructed_duty_vdc";
result.residual_A = require_matrix_shape(input.residual_A, 2, ...
    'deploymentResult.residual_A');
result.y_A = require_matrix_shape(input.y_A, 2, 'deploymentResult.y_A');
result.z_rad = require_column_shape(input.z_rad, 'deploymentResult.z_rad');
result.amplitude_A = require_column_shape(input.amplitude_A, ...
    'deploymentResult.amplitude_A');
validRaw = require_column_shape(input.valid, 'deploymentResult.valid');
assert(all(isfinite(validRaw)) && all(validRaw == 0 | validRaw == 1), ...
    'anglelut:VoltageABValidMask', ...
    'deploymentResult.valid must be a finite logical mask.');
result.valid = logical(validRaw);
result.vabc_V = require_matrix_shape(input.vabc_reconstructed_V, 3, ...
    'deploymentResult.vabc_reconstructed_V');
assert(all([size(result.residual_A,1), size(result.y_A,1), ...
    numel(result.z_rad), numel(result.amplitude_A), numel(result.valid), ...
    size(result.vabc_V,1)] == sampleCount), ...
    'anglelut:VoltageABLengthMismatch', ...
    'deploymentResult must contain one completed result per interval.');
end

function validate_valid_interval(k,iabc_A,theta_e_rad,omega_e_radps, ...
    direction_sign,plant_vabc_V,reconstructed)
required = [iabc_A(k,:),iabc_A(k+1,:),theta_e_rad(k), ...
    omega_e_radps(k),direction_sign(k),plant_vabc_V(k,:), ...
    reconstructed.residual_A(k,:),reconstructed.y_A(k,:), ...
    reconstructed.z_rad(k),reconstructed.amplitude_A(k), ...
    reconstructed.vabc_V(k,:)];
assert(all(isfinite(required)), 'anglelut:VoltageABValidInputNonfinite', ...
    'A deployment-valid interval contains a nonfinite E05/A-B input at row %d.',k);
assert(abs(direction_sign(k)) == 1, 'anglelut:VoltageABDirection', ...
    'A deployment-valid interval must have direction_sign = +/-1 at row %d.',k);
end

function value = require_matrix_shape(value, columns, label)
value = double(value);
if isvector(value) && numel(value) == columns
    value = reshape(value,1,columns);
end
assert(ismatrix(value) && size(value,2) == columns, ...
    'anglelut:VoltageABShape', '%s must have %d columns.', label, columns);
end

function value = require_column_shape(value, ~)
value = double(value(:));
end

function [Ts_s, Rs_Ohm, Ls_H] = resolve_config(cfg)
if isfield(cfg,'timing')
    Ts_s = double(cfg.timing.T_ident_s);
    Rs_Ohm = double(cfg.motor.Rs_ohm);
    Ls_H = double(cfg.motor.Ls_H);
else
    Ts_s = double(cfg.Ts_s);
    Rs_Ohm = double(cfg.Rs_Ohm);
    Ls_H = double(cfg.Ls_H);
end
assert(all(isfinite([Ts_s,Rs_Ohm,Ls_H])) && Ts_s > 0 && Ls_H > 0, ...
    'anglelut:VoltageABConfig', 'Invalid E05 timing or motor parameters.');
end

function value = local_rms(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = sqrt(mean(x.^2));
end
end

function value = local_circular_mean(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = angle(mean(exp(1i*x)));
end
end
