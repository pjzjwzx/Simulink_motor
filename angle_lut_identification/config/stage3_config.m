function cfg = stage3_config()
%STAGE3_CONFIG Frozen Scheme-5 LUT-only configuration.

cfg = stage2_config();
cfg.schema_version = "angle-lut-stage3-v1";
cfg.project.stage3_harness_model = fullfile(cfg.project.root,'models', ...
    'angle_lut_stage3_harness.slx');

cfg.stage3.schema_version = "scheme5-streaming-nonlinear-v1";
cfg.stage3.default_nodes = 64;
cfg.stage3.scan_nodes = [64,128];
cfg.stage3.runtime_nodes = 512;
cfg.stage3.MODE_NOMINAL = uint8(0);
cfg.stage3.MODE_MEASURED_MAGNITUDE = uint8(1);
cfg.stage3.MODE_DIRECTION_NORMALIZED = uint8(2);
cfg.stage3.primary_amplitude_mode = "nominal_model";
cfg.stage3.primary_amplitude_mode_code = cfg.stage3.MODE_NOMINAL;
cfg.stage3.diagnostic_amplitude_modes = ...
    ["measured_magnitude","direction_normalized"];
cfg.stage3.mu5 = 0.01;
cfg.stage3.epsilon5_A2 = 0.01;
cfg.stage3.amplitude_floor_A = 0.05;
cfg.stage3.direction_epsilon = 0.01;
cfg.stage3.training_mechanical_cycles = 10;
cfg.stage3.frozen_mechanical_cycles = 4;
cfg.stage3.initial_effective_weight_per_node = ...
    cfg.stage2.initial_effective_weight_per_node;
cfg.stage3.subsequent_effective_weight_per_node = ...
    cfg.stage2.subsequent_effective_weight_per_node;
cfg.stage3.initial_travel_m_rad = cfg.stage2.initial_travel_m_rad;
cfg.stage3.subsequent_travel_m_rad = cfg.stage2.subsequent_travel_m_rad;
cfg.stage3.node_min_hits = cfg.stage2.node_min_hits;
cfg.stage3.node_min_weight = cfg.stage2.node_min_weight;
cfg.stage3.max_abs_lut_e_rad = cfg.stage2.max_abs_lut_e_rad;
cfg.stage3.gamma = cfg.stage2.gamma;
cfg.stage3.max_active_step_e_rad = cfg.stage2.max_active_step_e_rad;
cfg.stage3.monotonic_margin = cfg.stage2.monotonic_margin;
cfg.stage3.constraint_sweeps = cfg.stage2.constraint_sweeps;
cfg.stage3.pole_pairs = cfg.motor.pole_pairs;
cfg.stage3.Ts_s = cfg.timing.T_ident_s;
cfg.stage3.Ls_H = cfg.motor.Ls_H;
cfg.stage3.psi_f_Wb = cfg.motor.psi_f_Wb;
cfg.stage3.random_seed = cfg.random_seed;
cfg.stage3.primary_profile_id = cfg.stage2.primary_profile_id;
cfg.stage3.control_gate_namespace = "stage3";
cfg.stage3.prerequisite_stage2_run_id = "";
cfg.stage3.allow_result_driven_tuning = false;
cfg.stage3.joint_parameter_identification_enabled = false;
cfg.stage3.enable_stage4 = false;
cfg.stage3.truth_policy = ...
    "Truth is scored after all Scheme-5 updates and never selects a mode.";
cfg.gates = stage_gates();
end
