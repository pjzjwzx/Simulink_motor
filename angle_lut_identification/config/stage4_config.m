function cfg = stage4_config()
%STAGE4_CONFIG Frozen Scheme-2 circular-NLMS core configuration.

cfg = stage3_config();
cfg.schema_version = "angle-lut-stage4-v1";
cfg.project.stage4_harness_model = fullfile(cfg.project.root,'models', ...
    'angle_lut_stage4_harness.slx');

cfg.stage4.schema_version = "scheme2-circular-nlms-v1";
cfg.stage4.default_nodes = 64;
cfg.stage4.scan_nodes = [64,128];
cfg.stage4.runtime_nodes = 512;
cfg.stage4.MODE_ATAN2 = uint8(0);
cfg.stage4.MODE_ATAN2_FREE = uint8(1);
cfg.stage4.primary_mode = "atan2";
cfg.stage4.diagnostic_mode = "atan2_free";
cfg.stage4.mu2 = 0.005;
cfg.stage4.epsilon2 = 0.01;
cfg.stage4.update_decimation = 1;
cfg.stage4.smoothing_strength = 0;
cfg.stage4.innovation_clip_e_rad = deg2rad(30);
cfg.stage4.atan2_free_epsilon_A = 0.05;
cfg.stage4.training_mechanical_cycles = 10;
cfg.stage4.frozen_mechanical_cycles = 4;
cfg.stage4.initial_effective_weight_per_node = ...
    cfg.stage2.initial_effective_weight_per_node;
cfg.stage4.subsequent_effective_weight_per_node = ...
    cfg.stage2.subsequent_effective_weight_per_node;
cfg.stage4.initial_travel_m_rad = cfg.stage2.initial_travel_m_rad;
cfg.stage4.subsequent_travel_m_rad = cfg.stage2.subsequent_travel_m_rad;
cfg.stage4.node_min_hits = cfg.stage2.node_min_hits;
cfg.stage4.node_min_weight = cfg.stage2.node_min_weight;
cfg.stage4.max_abs_lut_e_rad = cfg.stage2.max_abs_lut_e_rad;
cfg.stage4.gamma = cfg.stage2.gamma;
cfg.stage4.max_active_step_e_rad = cfg.stage2.max_active_step_e_rad;
cfg.stage4.monotonic_margin = cfg.stage2.monotonic_margin;
cfg.stage4.constraint_sweeps = cfg.stage2.constraint_sweeps;
cfg.stage4.pole_pairs = cfg.motor.pole_pairs;
cfg.stage4.random_seed = uint32(20260818);
cfg.stage4.primary_profile_id = cfg.stage2.primary_profile_id;
cfg.stage4.prerequisite_stage3_run_id = "";
cfg.stage4.allow_result_driven_tuning = false;
cfg.stage4.truth_policy = ...
    "Truth is scored after every Scheme-2 update and never selects a sweep.";

% Pre-registered diagnostic sweep.  The primary values above remain fixed.
cfg.stage4.sweep_mu2 = [0.0025,0.005,0.01,0.02];
cfg.stage4.sweep_epsilon2 = [0,0.01,0.1];
cfg.stage4.sweep_update_decimation = [1,2,4];
cfg.stage4.sweep_smoothing_strength = [0,0.001,0.01];
cfg.stage4.sweep_gamma = [0.1,0.2,0.4];

cfg.stage4.noise_sigma_A = 0.0510213456924654;
cfg.stage4.noise_95_half_width_A = 0.1;
cfg.stage4.adc_current_lsb_A = 0.02442002442;

% Keep Stage-4 gates local until the Stage-4 runner owns the global gate file.
g.coverage_fraction_min = 1.0;
g.fusion_count_min = 18;
g.final_active_update_rms_max_e_rad = deg2rad(0.25);
g.active_lut_rmse_max_e_rad = deg2rad(1.0);
g.active_lut_max_error_e_rad = deg2rad(2.0);
g.nonzero_lut_improvement_min = 0.80;
g.training_lut_drift_max_e_rad = deg2rad(0.5);
g.noise_lut_drift_max_e_rad = deg2rad(0.5);
g.m128_rmse_regression_max_e_rad = deg2rad(0.25);
g.noise_fraction_min = 0.94;
g.noise_fraction_max = 0.96;
g.ideal_control_angle_improvement_min = ...
    cfg.gates.stage3.ideal_control_angle_improvement_min;
g.ideal_control_angle_floor_margin_e_rad = ...
    cfg.gates.stage3.ideal_control_angle_floor_margin_e_rad;
g.ideal_median_physical_improvement_min = ...
    cfg.gates.stage3.ideal_median_physical_improvement_min;
g.ideal_per_case_regression_max = ...
    cfg.gates.stage3.ideal_per_case_regression_max;
g.iq_tracking_regression_max = cfg.gates.stage3.iq_tracking_regression_max;
g.mean_torque_change_max = cfg.gates.stage3.mean_torque_change_max;
g.nonideal_control_angle_improvement_min = ...
    cfg.gates.stage3.nonideal_control_angle_improvement_min;
g.nonideal_per_case_regression_max = ...
    cfg.gates.stage3.nonideal_per_case_regression_max;
g.stop_on_failure = true;
cfg.gates.stage4 = g;
end
