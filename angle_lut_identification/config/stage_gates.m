function gates = stage_gates()
%STAGE_GATES Machine-readable Stage 0/1 acceptance thresholds.

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
end
