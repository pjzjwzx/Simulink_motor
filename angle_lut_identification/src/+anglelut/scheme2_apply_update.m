function [state,event] = scheme2_apply_update(state,phi,sineInnovation, ...
        rawSineInnovation,innovation,chi,thetaUnwrapped,timestamp,valid,cfg)
%SCHEME2_APPLY_UPDATE Shared fixed-size E40 update after source isolation.

s = local_stage4(cfg);
assert(isscalar(s.update_decimation) && isfinite(s.update_decimation) && ...
    s.update_decimation >= 1 && ...
    s.update_decimation == floor(s.update_decimation), ...
    'anglelut:Scheme2UpdateDecimation', ...
    'update_decimation must be a positive integer.');
state.sample_count = state.sample_count+uint64(1);
event = local_event(state);
eligible = logical(valid) && isfinite(phi) && ...
    isfinite(sineInnovation) && isfinite(rawSineInnovation) && ...
    isfinite(chi) && chi > 0 && isfinite(thetaUnwrapped) && ...
    isfinite(timestamp);
if ~eligible, return; end

state.accepted_count = state.accepted_count+uint64(1);
event.accepted = true;
event.raw_sine_innovation = rawSineInnovation;
event.sine_innovation = sineInnovation;
event.innovation_e_rad = innovation;

if state.has_previous_theta
    travel = abs(thetaUnwrapped-state.previous_theta_m_unwrapped_rad);
    if isfinite(travel)
        state.total_abs_travel_m_rad = state.total_abs_travel_m_rad+travel;
        state.block_abs_travel_m_rad = state.block_abs_travel_m_rad+travel;
    end
end
state.previous_theta_m_unwrapped_rad = thetaUnwrapped;
state.has_previous_theta = true;

decimation = uint64(s.update_decimation);
if rem(state.accepted_count,decimation) ~= 0
    state.decimated_count = state.decimated_count+uint64(1);
    event.decimated = true;
    return;
end

M = double(state.M);
phi = anglelut.wrap_to_2pi(phi);
u = M*phi/(2*pi);
j0z = floor(u);
alpha = u-j0z;
j0 = j0z+1;
j1 = mod(j0z+1,M)+1;
h0 = 1-alpha;
h1 = alpha;
hNorm2 = h0*h0+h1*h1;
baseGain = s.mu2*chi/(s.epsilon2+hNorm2);
requested0 = baseGain*sineInnovation*h0;
requested1 = baseGain*sineInnovation*h1;
old0 = state.shadow_lut_e_rad(j0);
old1 = state.shadow_lut_e_rad(j1);
new0 = min(max(old0+requested0,-s.max_abs_lut_e_rad), ...
    s.max_abs_lut_e_rad);
new1 = min(max(old1+requested1,-s.max_abs_lut_e_rad), ...
    s.max_abs_lut_e_rad);
step0 = new0-old0;
step1 = new1-old1;
state.shadow_lut_e_rad(j0) = new0;
state.shadow_lut_e_rad(j1) = new1;

if h0 > 0
    state = local_node_stat(state,j0,step0,chi*h0,baseGain*h0*h0);
end
if h1 > 0
    state = local_node_stat(state,j1,step1,chi*h1,baseGain*h1*h1);
end
state.valid_mask = state.node_hits >= s.node_min_hits & ...
    state.node_weight >= s.node_min_weight;
state.update_count = state.update_count+uint64(1);
state.total_effective_weight = state.total_effective_weight+chi;
state.block_effective_weight = state.block_effective_weight+chi;
state.last_innovation_e_rad = innovation;
state.last_sine_innovation = sineInnovation;
state.last_normalized_step_e_rad = hypot(step0,step1);
state.max_local_step_e_rad = max(state.max_local_step_e_rad, ...
    max(abs([step0,step1])));
coverage = mean(double(state.valid_mask));

event.updated = true;
event.node0 = uint16(j0);
event.node1 = uint16(j1);
event.alpha = alpha;
event.local_step0_e_rad = step0;
event.local_step1_e_rad = step1;
event.normalized_step_e_rad = state.last_normalized_step_e_rad;
event.coverage_fraction = coverage;

if state.fusion_count == 0
    trigger = state.total_effective_weight >= ...
        s.initial_effective_weight_per_node*M && coverage >= 1 && ...
        state.total_abs_travel_m_rad >= s.initial_travel_m_rad;
else
    trigger = state.block_effective_weight >= ...
        s.subsequent_effective_weight_per_node*M && coverage >= 1 && ...
        state.block_abs_travel_m_rad >= s.subsequent_travel_m_rad;
end
if ~trigger, return; end

if s.smoothing_strength > 0
    state.shadow_lut_e_rad = anglelut.scheme2_smooth_periodic( ...
        state.shadow_lut_e_rad,s.smoothing_strength);
    state.smoothing_event_count = state.smoothing_event_count+uint32(1);
    event.smoothing_applied = true;
end
reuseCfg = local_reuse_cfg(cfg,s);
[projected,projection] = anglelut.project_lut( ...
    state.shadow_lut_e_rad,state.active_lut_e_rad,state.valid_mask,reuseCfg);
[activeNext,fusion] = anglelut.fuse_active_lut( ...
    state.active_lut_e_rad,projected,state.valid_mask,reuseCfg);
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

function state = local_node_stat(state,index,step,weight,gain)
oldCount = double(state.node_hits(index));
newCount = oldCount+1;
oldMean = state.node_step_mean_e_rad(index);
delta = step-oldMean;
newMean = oldMean+delta/newCount;
state.node_step_M2_e_rad2(index) = ...
    state.node_step_M2_e_rad2(index)+delta*(step-newMean);
state.node_step_mean_e_rad(index) = newMean;
state.node_hits(index) = state.node_hits(index)+uint32(1);
state.node_weight(index) = state.node_weight(index)+weight;
state.node_cumulative_gain(index) = ...
    state.node_cumulative_gain(index)+gain;
end

function cfgOut = local_reuse_cfg(cfg,s)
cfgOut = cfg;
if ~isfield(cfgOut,'stage2'), cfgOut.stage2 = s; end
cfgOut.stage2.max_abs_lut_e_rad = s.max_abs_lut_e_rad;
cfgOut.stage2.gamma = s.gamma;
cfgOut.stage2.max_active_step_e_rad = s.max_active_step_e_rad;
cfgOut.stage2.monotonic_margin = s.monotonic_margin;
cfgOut.stage2.constraint_sweeps = s.constraint_sweeps;
cfgOut.stage2.pole_pairs = s.pole_pairs;
end

function e = local_event(state)
e.triggered = false;
e.accepted = false;
e.updated = false;
e.decimated = false;
e.smoothing_applied = false;
e.fusion_count = state.fusion_count;
e.coverage_fraction = mean(double(state.valid_mask));
e.raw_sine_innovation = NaN;
e.sine_innovation = NaN;
e.innovation_e_rad = NaN;
e.node0 = uint16(0);
e.node1 = uint16(0);
e.alpha = NaN;
e.local_step0_e_rad = 0;
e.local_step1_e_rad = 0;
e.normalized_step_e_rad = 0;
e.projection = struct();
e.fusion = struct();
e.shadow_lut_e_rad = zeros(0,1);
e.active_lut_e_rad = zeros(0,1);
end

function s = local_stage4(cfg)
if isfield(cfg,'stage4'), s = cfg.stage4; else, s = cfg; end
end
