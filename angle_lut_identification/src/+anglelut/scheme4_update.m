function [state,event] = scheme4_update(state,sample,cfg)
%SCHEME4_UPDATE E20-E22 streaming update using the deployment-only sample.

stage2 = local_stage2(cfg);
local_validate_sample(sample);
M = double(state.M);
state.sample_count = state.sample_count+uint64(1);
event = local_event(state);

state.diag_A = stage2.rho*state.diag_A;
state.neighbor_A = stage2.rho*state.neighbor_A;
state.b = stage2.rho*state.b;
state.S = stage2.rho*state.S;
state.node_weight = stage2.rho*state.node_weight;
state.block_effective_weight = stage2.rho*state.block_effective_weight;

accepted = sample.valid && isfinite(sample.phi_m_rad) && ...
    isfinite(sample.z_e_rad) && isfinite(sample.quality_weight) && ...
    sample.quality_weight > 0 && ...
    isfinite(sample.theta_m_unwrapped_rad) && isfinite(sample.timestamp_s);
if ~accepted
    return;
end

phi = anglelut.wrap_to_2pi(sample.phi_m_rad);
u = M*phi/(2*pi);
j0z = floor(u);
alpha = u-j0z;
j0 = j0z+1;
j1 = mod(j0z+1,M)+1;
h0 = 1-alpha;
h1 = alpha;

prediction = h0*state.shadow_lut_e_rad(j0) + ...
    h1*state.shadow_lut_e_rad(j1);
innovation = anglelut.wrap_to_pi(sample.z_e_rad-prediction);
innovation = min(max(innovation,-stage2.innovation_clip_e_rad), ...
    stage2.innovation_clip_e_rad);
zTilde = prediction+innovation;
chi = sample.quality_weight;

state.diag_A(j0) = state.diag_A(j0)+chi*h0*h0;
state.diag_A(j1) = state.diag_A(j1)+chi*h1*h1;
state.neighbor_A(j0) = state.neighbor_A(j0)+chi*h0*h1;
state.b(j0) = state.b(j0)+chi*h0*zTilde;
state.b(j1) = state.b(j1)+chi*h1*zTilde;
state.S = state.S+chi;
state.node_weight(j0) = state.node_weight(j0)+chi*h0;
state.node_weight(j1) = state.node_weight(j1)+chi*h1;
if h0 > 0, state.node_hits(j0) = state.node_hits(j0)+uint32(1); end
if h1 > 0, state.node_hits(j1) = state.node_hits(j1)+uint32(1); end
state.valid_mask = state.node_hits >= stage2.node_min_hits & ...
    state.node_weight >= stage2.node_min_weight;
state.accepted_count = state.accepted_count+uint64(1);
state.block_effective_weight = state.block_effective_weight+chi;

if state.has_previous_theta
    travel = abs(sample.theta_m_unwrapped_rad- ...
        state.previous_theta_m_unwrapped_rad);
    if isfinite(travel)
        state.total_abs_travel_m_rad = state.total_abs_travel_m_rad+travel;
        state.block_abs_travel_m_rad = state.block_abs_travel_m_rad+travel;
    end
end
state.previous_theta_m_unwrapped_rad = sample.theta_m_unwrapped_rad;
state.has_previous_theta = true;

coverage = mean(double(state.valid_mask));
if state.solve_count == 0
    trigger = state.S >= stage2.initial_effective_weight_per_node*M && ...
        coverage >= 1 && ...
        state.total_abs_travel_m_rad >= stage2.initial_travel_m_rad;
else
    trigger = state.block_effective_weight >= ...
        stage2.subsequent_effective_weight_per_node*M && ...
        coverage >= 1 && ...
        state.block_abs_travel_m_rad >= stage2.subsequent_travel_m_rad;
end
if ~trigger
    return;
end

reference = anglelut.scheme4_solve_reference(state);
banded = anglelut.scheme4_solve_banded(state);
relativeDifference = norm(banded.lut_e_rad-reference.lut_e_rad,2) / ...
    max(norm(reference.lut_e_rad,2),eps);
state.shadow_lut_e_rad = banded.lut_e_rad;
[projected,projection] = anglelut.project_lut( ...
    state.shadow_lut_e_rad,state.active_lut_e_rad,state.valid_mask,cfg);
[activeNext,fusion] = anglelut.fuse_active_lut( ...
    state.active_lut_e_rad,projected,state.valid_mask,cfg);
state.previous_active_update_rms_e_rad = ...
    state.last_active_update_rms_e_rad;
state.last_active_update_rms_e_rad = fusion.rms_step_e_rad;
state.active_lut_e_rad = activeNext;
state.solve_count = state.solve_count+uint32(1);
state.last_solve_sample_count = state.sample_count;
state.block_effective_weight = 0;
state.block_abs_travel_m_rad = 0;
state.last_solver.triggered = true;
state.last_solver.reference_relative_difference = relativeDifference;
state.last_solver.normal_equation_relative_residual = ...
    banded.normal_equation_relative_residual;
state.last_solver.rcond = reference.rcond;
state.last_solver.reference_lut_e_rad = reference.lut_e_rad;

event.triggered = true;
event.solve_count = state.solve_count;
event.reference_relative_difference = relativeDifference;
event.normal_equation_relative_residual = ...
    banded.normal_equation_relative_residual;
event.rcond = reference.rcond;
event.coverage_fraction = coverage;
event.projection = projection;
event.fusion = fusion;
event.shadow_lut_e_rad = state.shadow_lut_e_rad;
event.active_lut_e_rad = state.active_lut_e_rad;
end

function local_validate_sample(sample)
allowed = sort(["phi_m_rad","z_e_rad","quality_weight", ...
    "theta_m_unwrapped_rad","timestamp_s","valid"]);
actual = sort(string(fieldnames(sample)).');
assert(isequal(actual,allowed), 'anglelut:Scheme4SampleSchema', ...
    'Scheme-4 sample must contain only the deployment-safe scalar schema.');
end

function e = local_event(state)
e.triggered = false;
e.solve_count = state.solve_count;
e.reference_relative_difference = NaN;
e.normal_equation_relative_residual = NaN;
e.rcond = NaN;
e.coverage_fraction = mean(double(state.valid_mask));
e.projection = struct();
e.fusion = struct();
e.shadow_lut_e_rad = zeros(0,1);
e.active_lut_e_rad = zeros(0,1);
end

function s = local_stage2(cfg)
if isfield(cfg,'stage2'), s = cfg.stage2; else, s = cfg; end
end
