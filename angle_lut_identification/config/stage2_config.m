function cfg = stage2_config()
%STAGE2_CONFIG Frozen Scheme-4 configuration layered on Stage 1.

cfg = default_config();
cfg.schema_version = "angle-lut-stage2-v1";
cfg.project.stage2_harness_model = fullfile(cfg.project.root, 'models', ...
    'angle_lut_stage2_harness.slx');

cfg.stage2.schema_version = "scheme4-streaming-ls-v1";
cfg.stage2.default_nodes = 64;
cfg.stage2.scan_nodes = [64, 128];
cfg.stage2.runtime_nodes = 512;
cfg.stage2.rho = 1.0;
cfg.stage2.lambda_s_at_128 = 1e-4;
cfg.stage2.lambda0 = 1e-6;
cfg.stage2.innovation_clip_e_rad = deg2rad(30);
cfg.stage2.initial_effective_weight_per_node = 32;
cfg.stage2.subsequent_effective_weight_per_node = 16;
cfg.stage2.initial_travel_m_rad = 2*pi;
cfg.stage2.subsequent_travel_m_rad = pi;
cfg.stage2.node_min_hits = uint32(32);
cfg.stage2.node_min_weight = 16;
cfg.stage2.gamma = 0.2;
cfg.stage2.max_abs_lut_e_rad = deg2rad(25);
cfg.stage2.monotonic_margin = 0.1;
cfg.stage2.max_active_step_e_rad = deg2rad(2);
cfg.stage2.constraint_sweeps = uint32(8);
cfg.stage2.training_mechanical_cycles = 10;
cfg.stage2.frozen_mechanical_cycles = 4;
cfg.stage2.training_speed_m_radps = 10;
cfg.stage2.training_load_torque_Nm = 1;
cfg.stage2.active_saved_default = false;
cfg.stage2.random_seed = cfg.random_seed;
cfg.stage2.truth_policy = ...
    "Truth is scored only after streaming learning and never selects a LUT.";
cfg.stage2.primary_profile_id = "periodic_combined";
cfg.stage2.prerequisite_stage1_run_id = "stage1_20260818_134403_214";
cfg.stage2.allow_result_driven_tuning = false;
cfg.stage2.enable_stage3 = false;

cfg.gates = stage_gates();
end
