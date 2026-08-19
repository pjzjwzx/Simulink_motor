function pair = pair_stage2_metrics(baseline,active)
%PAIR_STAGE2_METRICS Deterministic active-off/on improvement metrics.

assert(strcmp(baseline.case_id,active.case_id), ...
    'anglelut:Stage2PairIdentity','Frozen pair case IDs must agree.');
pair.case_id = baseline.case_id;
pair.expected_class = active.expected_class;
pair.baseline = baseline;
pair.active = active;
pair.control_angle_improvement = local_improvement( ...
    baseline.control_angle_rmse_e_rad,active.control_angle_rmse_e_rad);
pair.id_rms_improvement = local_improvement( ...
    baseline.id_rms_A,active.id_rms_A);
pair.prediction_residual_improvement = local_improvement( ...
    baseline.prediction_residual_rms_A,active.prediction_residual_rms_A);
pair.torque_ripple_improvement = local_improvement( ...
    baseline.torque_ripple_rms_Nm,active.torque_ripple_rms_Nm);
pair.iq_tracking_change = local_relative_regression( ...
    baseline.iq_tracking_rmse_A,active.iq_tracking_rmse_A);
pair.mean_torque_change = local_relative_change( ...
    baseline.mean_torque_Nm,active.mean_torque_Nm);
end

function value = local_improvement(baseline,active)
value = 1-active/max(abs(baseline),eps);
end

function value = local_relative_change(baseline,active)
value = abs(active-baseline)/max(abs(baseline),eps);
end

function value = local_relative_regression(baseline,active)
% Negative values are improvements and therefore never fail a regression gate.
value = (active-baseline)/max(abs(baseline),eps);
end
