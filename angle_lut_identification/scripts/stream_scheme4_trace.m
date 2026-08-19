function [state,metrics,history,reference] = ...
        stream_scheme4_trace(trace,M,cfg)
%STREAM_SCHEME4_TRACE Replay the deployment-only Stage-1 stream samplewise.
%   Only six whitelisted scalar fields are copied into SCHEME4_UPDATE.
%   Evaluation truth is read only after every learning update has finished.

assert(isstruct(trace) && isfield(trace,'theta_m_raw_rad') && ...
    isfield(trace,'theta_m_unwrapped_rad') && isfield(trace,'z_euler_rad') && ...
    isfield(trace,'quality_weight') && isfield(trace,'valid') && ...
    isfield(trace,'evaluation_mask') && isfield(trace,'time_s'), ...
    'anglelut:Stage2TraceSchema','Stage-1 deployment trace is incomplete.');
state = anglelut.scheme4_init(M,cfg);
history = local_history(M);
n = numel(trace.time_s);
for k = 1:n
    sample = struct( ...
        'phi_m_rad',double(trace.theta_m_raw_rad(k)), ...
        'z_e_rad',double(trace.z_euler_rad(k)), ...
        'quality_weight',double(trace.quality_weight(k)), ...
        'theta_m_unwrapped_rad',double(trace.theta_m_unwrapped_rad(k)), ...
        'timestamp_s',double(trace.time_s(k)), ...
        'valid',logical(trace.valid(k) && trace.evaluation_mask(k)));
    if M == 64
        [state,event] = anglelut.scheme4_update64(state,sample,cfg);
    else
        [state,event] = anglelut.scheme4_update128(state,sample,cfg);
    end
    if event.triggered
        history.solve_count(end+1,1) = double(event.solve_count);
        history.sample_index(end+1,1) = k;
        history.time_s(end+1,1) = double(trace.time_s(k));
        history.travel_m_rad(end+1,1) = state.total_abs_travel_m_rad;
        history.coverage_fraction(end+1,1) = event.coverage_fraction;
        history.reference_relative_difference(end+1,1) = ...
            event.reference_relative_difference;
        history.normal_equation_relative_residual(end+1,1) = ...
            event.normal_equation_relative_residual;
        history.rcond(end+1,1) = event.rcond;
        history.active_update_rms_e_rad(end+1,1) = ...
            event.fusion.rms_step_e_rad;
        history.shadow_lut_e_rad(end+1,:) = ...
            event.shadow_lut_e_rad(:).';
        history.active_lut_e_rad(end+1,:) = ...
            event.active_lut_e_rad(:).';
    end
end

% Truth is evaluation-only and deliberately accessed after the update loop.
assert(isfield(trace,'truth_error_e_rad'), ...
    'anglelut:Stage2TruthEvaluationMissing', ...
    'Evaluation truth is required only to score the completed LUT.');
accepted = logical(trace.valid(:) & trace.evaluation_mask(:));
reference = anglelut.aggregate_reference_lut( ...
    trace.theta_m_raw_rad,trace.truth_error_e_rad,M,accepted);

shadowError = anglelut.wrap_to_pi(state.shadow_lut_e_rad-reference.lut_e_rad);
activeError = anglelut.wrap_to_pi(state.active_lut_e_rad-reference.lut_e_rad);
zeroError = anglelut.wrap_to_pi(-reference.lut_e_rad);
mask = reference.valid_mask & isfinite(shadowError) & isfinite(activeError);
metrics = struct();
metrics.nodes = M;
metrics.sample_count = n;
metrics.accepted_count = double(state.accepted_count);
metrics.effective_weight = state.S;
metrics.coverage_fraction = mean(double(state.valid_mask));
metrics.reference_coverage_fraction = reference.coverage_fraction;
metrics.solve_count = double(state.solve_count);
metrics.total_abs_travel_m_rad = state.total_abs_travel_m_rad;
metrics.mechanical_revolutions = state.total_abs_travel_m_rad/(2*pi);
metrics.shadow_rmse_e_rad = local_rms(shadowError(mask));
metrics.shadow_rmse_e_deg = rad2deg(metrics.shadow_rmse_e_rad);
metrics.active_rmse_e_rad = local_rms(activeError(mask));
metrics.active_rmse_e_deg = rad2deg(metrics.active_rmse_e_rad);
metrics.baseline_rmse_e_rad = local_rms(zeroError(mask));
metrics.baseline_rmse_e_deg = rad2deg(metrics.baseline_rmse_e_rad);
metrics.active_max_error_e_rad = local_max_abs(activeError(mask));
metrics.active_max_error_e_deg = rad2deg(metrics.active_max_error_e_rad);
metrics.active_improvement_fraction = 1 - metrics.active_rmse_e_rad / ...
    max(metrics.baseline_rmse_e_rad,eps);
metrics.last_active_update_rms_e_rad = state.last_active_update_rms_e_rad;
metrics.previous_active_update_rms_e_rad = ...
    state.previous_active_update_rms_e_rad;
metrics.solver_relative_difference = ...
    state.last_solver.reference_relative_difference;
metrics.normal_equation_relative_residual = ...
    state.last_solver.normal_equation_relative_residual;
metrics.rcond = state.last_solver.rcond;
activeDelta = circshift(state.active_lut_e_rad,-1)-state.active_lut_e_rad;
metrics.active_max_abs_e_rad = max(abs(state.active_lut_e_rad));
metrics.minimum_monotonic_margin = min(1-activeDelta/( ...
    cfg.motor.pole_pairs*2*pi/M));
metrics.all_nodes_valid = all(state.valid_mask);
metrics.amplitude_constraint_satisfied = ...
    metrics.active_max_abs_e_rad <= cfg.stage2.max_abs_lut_e_rad+100*eps;
metrics.monotonic_constraint_satisfied = ...
    metrics.minimum_monotonic_margin >= ...
    cfg.stage2.monotonic_margin-100*eps;
end

function h = local_history(M)
h.solve_count = zeros(0,1);
h.sample_index = zeros(0,1);
h.time_s = zeros(0,1);
h.travel_m_rad = zeros(0,1);
h.coverage_fraction = zeros(0,1);
h.reference_relative_difference = zeros(0,1);
h.normal_equation_relative_residual = zeros(0,1);
h.rcond = zeros(0,1);
h.active_update_rms_e_rad = zeros(0,1);
h.shadow_lut_e_rad = zeros(0,M);
h.active_lut_e_rad = zeros(0,M);
end

function value = local_rms(x)
if isempty(x), value = NaN; else, value = sqrt(mean(x.^2)); end
end

function value = local_max_abs(x)
if isempty(x), value = NaN; else, value = max(abs(x)); end
end
