function [state,event] = scheme5_update(state,sample,cfg)
%SCHEME5_UPDATE E30-E32 two-node normalized nonlinear LUT update.

s = local_stage3(cfg);
local_validate_sample(sample);
M = double(state.M);
state.sample_count = state.sample_count+uint64(1);
event = local_event(state);
accepted = sample.valid && isfinite(sample.phi_m_rad) && ...
    isfinite(sample.y_d_A) && isfinite(sample.y_q_A) && ...
    isfinite(sample.omega_e_est_radps) && ...
    isfinite(sample.quality_weight) && sample.quality_weight > 0 && ...
    isfinite(sample.theta_m_unwrapped_rad) && isfinite(sample.timestamp_s);
if ~accepted, return; end

phi = anglelut.wrap_to_2pi(sample.phi_m_rad);
u = M*phi/(2*pi);
j0z = floor(u);
alpha = u-j0z;
j0 = j0z+1;
j1 = mod(j0z+1,M)+1;
h0 = 1-alpha;
h1 = alpha;
hNorm2 = h0*h0+h1*h1;
deltaHat = h0*state.shadow_lut_e_rad(j0)+ ...
    h1*state.shadow_lut_e_rad(j1);
yRaw = [sample.y_d_A;sample.y_q_A];
aNominal = s.Ts_s*s.psi_f_Wb*abs(sample.omega_e_est_radps)/s.Ls_H;
[y,a,epsilon,units] = local_amplitude(yRaw,aNominal,state.amplitude_mode,s);
yHat = a*[sin(deltaHat);cos(deltaHat)];
residual = y-yHat;
tangent = residual(1)*cos(deltaHat)-residual(2)*sin(deltaHat);
radial = residual(1)*sin(deltaHat)+residual(2)*cos(deltaHat);
gain = s.mu5*sample.quality_weight*a*tangent/(epsilon+a*a*hNorm2);
step0 = gain*h0;
step1 = gain*h1;
state.shadow_lut_e_rad(j0) = min(max( ...
    state.shadow_lut_e_rad(j0)+step0,-s.max_abs_lut_e_rad), ...
    s.max_abs_lut_e_rad);
state.shadow_lut_e_rad(j1) = min(max( ...
    state.shadow_lut_e_rad(j1)+step1,-s.max_abs_lut_e_rad), ...
    s.max_abs_lut_e_rad);

chi = sample.quality_weight;
state.node_weight(j0) = state.node_weight(j0)+chi*h0;
state.node_weight(j1) = state.node_weight(j1)+chi*h1;
if h0 > 0, state.node_hits(j0) = state.node_hits(j0)+uint32(1); end
if h1 > 0, state.node_hits(j1) = state.node_hits(j1)+uint32(1); end
state.valid_mask = state.node_hits >= s.node_min_hits & ...
    state.node_weight >= s.node_min_weight;
state.accepted_count = state.accepted_count+uint64(1);
state.total_effective_weight = state.total_effective_weight+chi;
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
state.last_tangent_residual = tangent;
state.last_radial_residual = radial;
state.last_normalized_step = hypot(step0,step1);
state.max_local_step_e_rad = max(state.max_local_step_e_rad, ...
    max(abs([step0,step1])));

coverage = mean(double(state.valid_mask));
if state.fusion_count == 0
    trigger = state.total_effective_weight >= ...
        s.initial_effective_weight_per_node*M && coverage >= 1 && ...
        state.total_abs_travel_m_rad >= s.initial_travel_m_rad;
else
    trigger = state.block_effective_weight >= ...
        s.subsequent_effective_weight_per_node*M && coverage >= 1 && ...
        state.block_abs_travel_m_rad >= s.subsequent_travel_m_rad;
end
event.accepted = true;
event.tangent_residual = tangent;
event.radial_residual = radial;
event.normalized_step_e_rad = state.last_normalized_step;
event.amplitude = a;
event.nominal_amplitude_A = aNominal;
event.residual_units = units;
event.coverage_fraction = coverage;
if ~trigger, return; end

[projected,projection] = anglelut.project_lut( ...
    state.shadow_lut_e_rad,state.active_lut_e_rad,state.valid_mask,cfg);
[activeNext,fusion] = anglelut.fuse_active_lut( ...
    state.active_lut_e_rad,projected,state.valid_mask,cfg);
state.previous_active_update_rms_e_rad = ...
    state.last_active_update_rms_e_rad;
state.last_active_update_rms_e_rad = fusion.rms_step_e_rad;
state.active_lut_e_rad = activeNext;
state.fusion_count = state.fusion_count+uint32(1);
state.last_fusion_sample_count = state.sample_count;
state.block_effective_weight = 0;
state.block_abs_travel_m_rad = 0;
event.triggered = true;
event.fusion_count = state.fusion_count;
event.projection = projection;
event.fusion = fusion;
event.shadow_lut_e_rad = state.shadow_lut_e_rad;
event.active_lut_e_rad = state.active_lut_e_rad;
end

function [y,a,epsilon,units] = local_amplitude(yRaw,aNominal,mode,s)
if mode == s.MODE_NOMINAL
    y = yRaw; a = aNominal; epsilon = s.epsilon5_A2; units = "A";
elseif mode == s.MODE_MEASURED_MAGNITUDE
    y = yRaw; a = max(hypot(yRaw(1),yRaw(2)),s.amplitude_floor_A);
    epsilon = s.epsilon5_A2; units = "A";
else
    scale = max(hypot(yRaw(1),yRaw(2)),s.amplitude_floor_A);
    y = yRaw/scale; a = 1.0; epsilon = s.direction_epsilon;
    units = "dimensionless";
end
end

function local_validate_sample(sample)
allowed = sort(["phi_m_rad","y_d_A","y_q_A", ...
    "omega_e_est_radps","quality_weight","theta_m_unwrapped_rad", ...
    "timestamp_s","valid"]);
actual = sort(string(fieldnames(sample)).');
assert(isequal(actual,allowed),'anglelut:Scheme5SampleSchema', ...
    'Scheme-5 sample must contain only the deployment-safe scalar schema.');
end

function e = local_event(state)
e.triggered = false;
e.accepted = false;
e.fusion_count = state.fusion_count;
e.coverage_fraction = mean(double(state.valid_mask));
e.tangent_residual = NaN;
e.radial_residual = NaN;
e.normalized_step_e_rad = 0;
e.amplitude = NaN;
e.nominal_amplitude_A = NaN;
e.residual_units = "";
e.projection = struct();
e.fusion = struct();
e.shadow_lut_e_rad = zeros(0,1);
e.active_lut_e_rad = zeros(0,1);
end

function s = local_stage3(cfg)
if isfield(cfg,'stage3'), s = cfg.stage3; else, s = cfg; end
end
