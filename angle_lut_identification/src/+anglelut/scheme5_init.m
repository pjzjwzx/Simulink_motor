function state = scheme5_init(M,cfg,modeCode)
%SCHEME5_INIT Fixed-size E30-E32 LUT-only state.

assert(isscalar(M) && any(M == [64,128]), ...
    'anglelut:Scheme5NodeCount','Scheme 5 supports fixed M=64 or M=128.');
s = local_stage3(cfg);
if nargin < 3, modeCode = s.primary_amplitude_mode_code; end
assert(isscalar(modeCode) && any(uint8(modeCode) == uint8([0 1 2])), ...
    'anglelut:Scheme5AmplitudeMode','Unknown Scheme-5 amplitude mode.');

state.schema_version = "scheme5-state-v1";
state.M = uint16(M);
state.amplitude_mode = uint8(modeCode);
state.node_weight = zeros(M,1);
state.node_hits = zeros(M,1,'uint32');
state.valid_mask = false(M,1);
state.shadow_lut_e_rad = zeros(M,1);
state.active_lut_e_rad = zeros(M,1);
state.sample_count = uint64(0);
state.accepted_count = uint64(0);
state.total_effective_weight = 0.0;
state.block_effective_weight = 0.0;
state.total_abs_travel_m_rad = 0.0;
state.block_abs_travel_m_rad = 0.0;
state.previous_theta_m_unwrapped_rad = 0.0;
state.has_previous_theta = false;
state.fusion_count = uint32(0);
state.last_fusion_sample_count = uint64(0);
state.last_active_update_rms_e_rad = Inf;
state.previous_active_update_rms_e_rad = Inf;
state.last_tangent_residual = NaN;
state.last_radial_residual = NaN;
state.last_normalized_step = 0.0;
state.max_local_step_e_rad = 0.0;
end

function s = local_stage3(cfg)
if isfield(cfg,'stage3'), s = cfg.stage3; else, s = cfg; end
end
