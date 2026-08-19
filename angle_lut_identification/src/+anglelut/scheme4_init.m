function state = scheme4_init(M,cfg)
%SCHEME4_INIT Fixed-size state for E20-E22 streaming sufficient statistics.

assert(isscalar(M) && any(M == [64,128]), ...
    'anglelut:Scheme4NodeCount','Scheme 4 supports fixed M=64 or M=128.');
stage2 = local_stage2(cfg);

state.schema_version = "scheme4-state-v1";
state.M = uint16(M);
state.diag_A = zeros(M,1);
state.neighbor_A = zeros(M,1);
state.b = zeros(M,1);
state.S = 0.0;
state.node_weight = zeros(M,1);
state.node_hits = zeros(M,1,'uint32');
state.valid_mask = false(M,1);
state.shadow_lut_e_rad = zeros(M,1);
state.active_lut_e_rad = zeros(M,1);
state.sample_count = uint64(0);
state.accepted_count = uint64(0);
state.total_abs_travel_m_rad = 0.0;
state.block_effective_weight = 0.0;
state.block_abs_travel_m_rad = 0.0;
state.previous_theta_m_unwrapped_rad = 0.0;
state.has_previous_theta = false;
state.solve_count = uint32(0);
state.last_solve_sample_count = uint64(0);
state.last_active_update_rms_e_rad = Inf;
state.previous_active_update_rms_e_rad = Inf;
state.last_solver = local_empty_solver();
state.lambda_s = stage2.lambda_s_at_128 * (double(M)/128)^3;
state.lambda0 = stage2.lambda0;
end

function out = local_empty_solver()
out.triggered = false;
out.reference_relative_difference = NaN;
out.normal_equation_relative_residual = NaN;
out.rcond = NaN;
out.reference_lut_e_rad = zeros(0,1);
end

function s = local_stage2(cfg)
if isfield(cfg,'stage2')
    s = cfg.stage2;
else
    s = cfg;
end
end
