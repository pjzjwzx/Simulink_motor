function tests = testStage2Acceptance
%TESTSTAGE2ACCEPTANCE Pure tests for the pre-registered Stage-2 gate.
tests = functiontests(localfunctions);
end

function testPassingFixture(testCase)
cfg = stage2_config();
p64 = repmat(local_profile(cfg),8,1);
p128 = repmat(local_profile(cfg),8,1);
ids = ["fixed_00deg_e","fixed_05deg_e","fixed_10deg_e", ...
    "fixed_20deg_e","periodic_constant","periodic_1x", ...
    "periodic_2x","periodic_combined"];
for k = 1:8
    p64(k).case_id = char(ids(k));
    p128(k).case_id = char(ids(k));
end
drift = repmat(struct('case_id','x','lut_drift_e_rad',deg2rad(0.1)),8,1);
pairs = [local_pair('ideal','ideal_case'), ...
    local_pair('nonideal','nonideal_case'), ...
    local_pair('saturation_diagnostic','stage2_pwm_saturation')].';
[checks,aggregate] = evaluate_stage2_acceptance( ...
    p64,p128,pairs,drift,cfg,true);
verifyTrue(testCase,checks.all_mandatory);
verifyEqual(testCase,aggregate.m64_profile_count,8);
end

function testSolverFailureCannotBeMasked(testCase)
cfg = stage2_config();
p64 = repmat(local_profile(cfg),8,1);
p128 = repmat(local_profile(cfg),8,1);
ids = ["fixed_00deg_e","fixed_05deg_e","fixed_10deg_e", ...
    "fixed_20deg_e","periodic_constant","periodic_1x", ...
    "periodic_2x","periodic_combined"];
for k = 1:8, p64(k).case_id=char(ids(k)); p128(k).case_id=char(ids(k)); end
p64(4).solver_relative_difference = 2e-9;
drift = repmat(struct('case_id','x','lut_drift_e_rad',deg2rad(0.1)),8,1);
pairs = [local_pair('ideal','ideal_case'), ...
    local_pair('nonideal','nonideal_case'), ...
    local_pair('saturation_diagnostic','stage2_pwm_saturation')].';
checks = evaluate_stage2_acceptance(p64,p128,pairs,drift,cfg,true);
verifyFalse(testCase,checks.solver_reference_agreement);
verifyFalse(testCase,checks.all_mandatory);
end

function testIdealControlAngleFloorAwareBranches(testCase)
cfg = stage2_config();
pair = local_pair('ideal','periodic_2x');
pair.control_angle_improvement = 0.567;
pair.active.control_angle_rmse_e_rad = 2*pi*cfg.motor.pole_pairs/( ...
    cfg.encoder.counts_per_rev*sqrt(12))+deg2rad(0.05);
[pass,basis] = control_angle_gate(pair,struct('case_id','periodic_2x'),cfg);
verifyTrue(testCase,pass);
verifyEqual(testCase,basis,'quantization_floor');

pair.active.control_angle_rmse_e_rad = 2*pi*cfg.motor.pole_pairs/( ...
    cfg.encoder.counts_per_rev*sqrt(12))+deg2rad(0.11);
[pass,basis] = control_angle_gate(pair,struct('case_id','periodic_2x'),cfg);
verifyFalse(testCase,pass);
verifyEqual(testCase,basis,'failed');

pair.control_angle_improvement = 0.60;
[pass,basis] = control_angle_gate(pair,struct('case_id','periodic_2x'),cfg);
verifyTrue(testCase,pass);
verifyEqual(testCase,basis,'percentage');
end

function p = local_profile(cfg)
p = struct('case_id','', 'solver_relative_difference',1e-12, ...
    'normal_equation_relative_residual',1e-12,'rcond',0.2, ...
    'coverage_fraction',1,'solve_count',20, ...
    'last_active_update_rms_e_rad',deg2rad(0.1), ...
    'previous_active_update_rms_e_rad',deg2rad(0.1), ...
    'shadow_rmse_e_rad',deg2rad(0.2),'active_rmse_e_rad',deg2rad(0.3), ...
    'active_max_error_e_rad',deg2rad(0.8), ...
    'active_improvement_fraction',0.95, ...
    'amplitude_constraint_satisfied',true, ...
    'monotonic_constraint_satisfied',true,'all_nodes_valid',true, ...
    'active_max_abs_e_rad',0.5*cfg.stage2.max_abs_lut_e_rad);
end

function p = local_pair(className,id)
m = struct('compensation_max_abs_e_rad',deg2rad(10), ...
    'control_angle_rmse_e_rad',deg2rad(1));
p = struct('case_id',id,'expected_class',className,'baseline',m, ...
    'active',m,'control_angle_improvement',0.8, ...
    'id_rms_improvement',0.1,'prediction_residual_improvement',0.1, ...
    'torque_ripple_improvement',0.1,'iq_tracking_change',-0.1, ...
    'mean_torque_change',0.01);
end
