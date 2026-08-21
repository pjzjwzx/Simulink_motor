function state = scheme2_init(M,cfg,sourceMode)
%SCHEME2_INIT Fixed-size E40 circular-NLMS state.

assert(isscalar(M) && any(M == [64,128]), ...
    'anglelut:Scheme2NodeCount','Scheme 2 supports fixed M=64 or M=128.');
s = local_stage4(cfg);
if nargin < 3, sourceMode = s.MODE_ATAN2; end
assert(isscalar(sourceMode) && any(uint8(sourceMode) == ...
    uint8([s.MODE_ATAN2,s.MODE_ATAN2_FREE])), ...
    'anglelut:Scheme2SourceMode','Unknown Scheme-2 source mode.');

state.schema_version = "scheme2-state-v1";
state.M = uint16(M);
state.source_mode = uint8(sourceMode);
state.node_weight = zeros(M,1);
state.node_hits = zeros(M,1,'uint32');
state.node_cumulative_gain = zeros(M,1);
state.node_step_mean_e_rad = zeros(M,1);
state.node_step_M2_e_rad2 = zeros(M,1);
state.valid_mask = false(M,1);
state.shadow_lut_e_rad = zeros(M,1);
state.active_lut_e_rad = zeros(M,1);
state.sample_count = uint64(0);
state.accepted_count = uint64(0);
state.update_count = uint64(0);
state.decimated_count = uint64(0);
state.total_effective_weight = 0.0;
state.block_effective_weight = 0.0;
state.total_abs_travel_m_rad = 0.0;
state.block_abs_travel_m_rad = 0.0;
state.previous_theta_m_unwrapped_rad = 0.0;
state.has_previous_theta = false;
state.fusion_count = uint32(0);
state.smoothing_event_count = uint32(0);
state.last_fusion_sample_count = uint64(0);
state.last_active_update_rms_e_rad = Inf;
state.previous_active_update_rms_e_rad = Inf;
state.last_innovation_e_rad = NaN;
state.last_sine_innovation = NaN;
state.last_normalized_step_e_rad = 0.0;
state.max_local_step_e_rad = 0.0;
end

function s = local_stage4(cfg)
if isfield(cfg,'stage4'), s = cfg.stage4; else, s = cfg; end
end
