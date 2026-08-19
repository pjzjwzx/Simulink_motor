function [metrics,trace] = evaluate_stage2_frozen(simOut,stage1Trace,c,cfg, ...
        activeEnable)
%EVALUATE_STAGE2_FROZEN Score control performance after learning is frozen.
%   Truth is used only in this evaluator.  It is never returned as a
%   learning sample and never changes the active LUT or validity mask.

required = {'stage2_control_theta_e','stage2_lut_compensation_e', ...
    'stage2_torque_true_Nm','stage1_iabc_meas','stage1_theta_e_true', ...
    'stage1_iq_ref'};
for k = 1:numel(required)
    assert(any(strcmp(simOut.who,required{k})), ...
        'anglelut:MissingStage2Log','Missing Stage-2 log %s.',required{k});
end
controlLog = simOut.get('stage2_control_theta_e');
time_s = double(controlLog.Time(:));
controlTheta = sample_logged_signal(controlLog,time_s,'linear');
compensation = sample_logged_signal( ...
    simOut.get('stage2_lut_compensation_e'),time_s,'linear');
torque = sample_logged_signal(simOut.get('stage2_torque_true_Nm'), ...
    time_s,'linear');
iabc = sample_logged_signal(simOut.get('stage1_iabc_meas'),time_s,'linear');
thetaTrue = sample_logged_signal(simOut.get('stage1_theta_e_true'), ...
    time_s,'linear');
iqRef = sample_logged_signal(simOut.get('stage1_iq_ref'),time_s,'linear');

controlTheta = double(controlTheta(:,1));
compensation = double(compensation(:,1));
torque = double(torque(:,1));
thetaTrue = double(thetaTrue(:,1));
iqRef = double(iqRef(:,1));
if size(iabc,2) ~= 3, iabc = reshape(iabc,[],3); end
evaluation = time_s >= cfg.simulation.steady_state_time_s;
finite = evaluation & isfinite(controlTheta) & isfinite(thetaTrue) & ...
    isfinite(torque) & isfinite(iqRef) & all(isfinite(iabc),2);

id = zeros(numel(time_s),1);
iq = zeros(numel(time_s),1);
for k = 1:numel(time_s)
    iab = anglelut.clarke_abc(iabc(k,:).');
    idq = anglelut.park_alphabeta(iab,thetaTrue(k));
    id(k) = idq(1);
    iq(k) = idq(2);
end
controlError = anglelut.wrap_to_pi(controlTheta-thetaTrue);
residualMask = stage1Trace.valid & stage1Trace.evaluation_mask;
compensationAtResidual = sample_logged_signal( ...
    simOut.get('stage2_lut_compensation_e'),stage1Trace.time_s,'linear');
compensationAtResidual = double(compensationAtResidual(:,1));
fullModelResidual = anglelut.compensated_prediction_residual( ...
    stage1Trace.residual_A,stage1Trace.expected_amplitude_A, ...
    stage1Trace.direction_sign,compensationAtResidual);
residualNorm = hypot(fullModelResidual(:,1),fullModelResidual(:,2));
residualMask = residualMask & all(isfinite(fullModelResidual),2);

metrics = struct();
metrics.case_id = char(c.case_id);
metrics.active_enable = logical(activeEnable);
metrics.expected_class = local_expected_class(c);
metrics.sample_count = nnz(finite);
metrics.control_angle_rmse_e_rad = local_rms(controlError(finite));
metrics.control_angle_rmse_e_deg = ...
    rad2deg(metrics.control_angle_rmse_e_rad);
metrics.id_rms_A = local_rms(id(finite));
metrics.iq_tracking_rmse_A = local_rms(iq(finite)-iqRef(finite));
metrics.prediction_residual_rms_A = local_rms(residualNorm(residualMask));
metrics.mean_torque_Nm = local_mean(torque(finite));
metrics.torque_ripple_rms_Nm = local_rms( ...
    torque(finite)-metrics.mean_torque_Nm);
metrics.compensation_rms_e_rad = local_rms(compensation(finite));
metrics.compensation_max_abs_e_rad = local_max_abs(compensation(finite));

trace.time_s = time_s;
trace.evaluation_mask = finite;
trace.control_theta_e_rad = controlTheta;
trace.truth_theta_e_rad = thetaTrue;
trace.control_error_e_rad = controlError;
trace.lut_compensation_e_rad = compensation;
trace.id_A = id;
trace.iq_A = iq;
trace.iq_ref_A = iqRef;
trace.torque_Nm = torque;
trace.prediction_residual_A = fullModelResidual;
trace.prediction_residual_mask = residualMask;
trace.prediction_residual_model = ...
    'full SPMSM PM prediction using frozen active compensation';
trace.learning_frozen = true;
end

function value = local_expected_class(c)
if isfield(c,'stage2_expected_class')
    value = char(c.stage2_expected_class);
elseif c.group == "nonideal" || c.group == "parameter_mismatch"
    value = 'nonideal';
else
    value = 'ideal';
end
end

function value = local_rms(x)
if isempty(x), value = NaN; else, value = sqrt(mean(x.^2)); end
end

function value = local_mean(x)
if isempty(x), value = NaN; else, value = mean(x); end
end

function value = local_max_abs(x)
if isempty(x), value = NaN; else, value = max(abs(x)); end
end
