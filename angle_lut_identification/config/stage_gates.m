function gates = stage_gates()
%STAGE_GATES Machine-readable Stage 0/1/2/3 acceptance thresholds.

gates.schema_version = "angle-lut-gates-v2-control-angle-60pct-floor-aware";

gates.allowed_status = ["PASS", "FAIL", "BLOCKED"];

gates.stage0.require_baseline_model = true;
gates.stage0.require_baseline_run = true;
gates.stage0.require_model_sha256 = true;
gates.stage0.require_signal_map = true;
gates.stage0.require_timing_contract = true;
gates.stage0.require_formula_block_map = true;
gates.stage0.expected_base_step_s = 5e-6;
gates.stage0.expected_pwm_period_s = 50e-6;

gates.stage1.fixed_5deg_mean_error_max_e_rad = deg2rad(0.5);
gates.stage1.fixed_fit_slope_range = [0.9, 1.1];
gates.stage1.fixed_fit_intercept_abs_max_e_rad = deg2rad(0.5);
gates.stage1.ideal_rmse_floor_e_rad = deg2rad(0.5);
gates.stage1.ideal_rmse_predictor_floor_multiplier = 3;
gates.stage1.nonideal_rmse_max_e_rad = deg2rad(2);
gates.stage1.forward_reverse_mean_difference_max_e_rad = deg2rad(0.5);
gates.stage1.ideal_voltage_reconstruction_rms_max_V = 1e-6;
gates.stage1.periodic_minimum_mechanical_cycles = 4;
gates.stage1.require_park_sign_test = true;
gates.stage1.require_residual_sign_test = true;
gates.stage1.require_timing_test = true;
gates.stage1.require_voltage_reconstruction_test = true;
gates.stage1.require_encoder_test = true;
gates.stage1.require_truth_isolation_test = true;
gates.stage1.stop_on_failure = true;
gates.stage1.allow_predictor_switch_to_mask_failure = false;

% Stage 2 thresholds are pre-registered.  They must not be changed after
% looking at a Stage-2 result in order to turn a failure into a pass.
gates.stage2.solver_relative_difference_max = 1e-9;
gates.stage2.normal_equation_relative_residual_max = 1e-9;
gates.stage2.rcond_min = 1e-8;
gates.stage2.coverage_fraction_min = 1.0;
gates.stage2.solve_count_min = 18;
gates.stage2.final_active_update_rms_max_e_rad = deg2rad(0.25);
gates.stage2.shadow_lut_rmse_max_e_rad = deg2rad(0.5);
gates.stage2.active_lut_rmse_max_e_rad = deg2rad(1.0);
gates.stage2.active_lut_max_error_e_rad = deg2rad(2.0);
gates.stage2.nonzero_lut_improvement_min = 0.80;
gates.stage2.fixed_zero_lut_rmse_max_e_rad = deg2rad(0.5);
gates.stage2.cross_condition_lut_drift_max_e_rad = deg2rad(0.5);
gates.stage2.m128_rmse_regression_max_e_rad = deg2rad(0.25);
gates.stage2.ideal_control_angle_improvement_min = 0.60;
gates.stage2.ideal_control_angle_floor_margin_e_rad = deg2rad(0.10);
gates.stage2.ideal_median_physical_improvement_min = 0.05;
gates.stage2.ideal_per_case_regression_max = 0.02;
gates.stage2.iq_tracking_regression_max = 0.05;
gates.stage2.mean_torque_change_max = 0.02;
gates.stage2.nonideal_control_angle_improvement_min = 0.50;
gates.stage2.nonideal_per_case_regression_max = 0.10;
gates.stage2.stop_on_failure = true;

% Stage 3 Scheme-5 thresholds are locked before the formal Stage-3 run.
gates.stage3.gradient_relative_error_max = 1e-6;
gates.stage3.reverse_update_relative_difference_max = 1e-12;
gates.stage3.coverage_fraction_min = 1.0;
gates.stage3.fusion_count_min = 18;
gates.stage3.final_active_update_rms_max_e_rad = deg2rad(0.25);
gates.stage3.shadow_lut_rmse_max_e_rad = deg2rad(0.5);
gates.stage3.active_lut_rmse_max_e_rad = deg2rad(1.0);
gates.stage3.active_lut_max_error_e_rad = deg2rad(2.0);
gates.stage3.fixed_zero_lut_rmse_max_e_rad = deg2rad(0.5);
gates.stage3.nonzero_lut_improvement_min = 0.80;
gates.stage3.scheme4_lut_difference_max_e_rad = deg2rad(0.5);
gates.stage3.m128_rmse_regression_max_e_rad = deg2rad(0.25);
gates.stage3.cross_condition_lut_drift_max_e_rad = deg2rad(0.5);
gates.stage3.ideal_control_angle_improvement_min = 0.60;
gates.stage3.ideal_control_angle_floor_margin_e_rad = deg2rad(0.10);
gates.stage3.ideal_median_physical_improvement_min = 0.05;
gates.stage3.ideal_per_case_regression_max = 0.02;
gates.stage3.iq_tracking_regression_max = 0.05;
gates.stage3.mean_torque_change_max = 0.02;
gates.stage3.nonideal_control_angle_improvement_min = 0.50;
gates.stage3.nonideal_per_case_regression_max = 0.10;
gates.stage3.sensitivity_valid_fraction_min = 0.90;
gates.stage3.stop_on_failure = true;
end
