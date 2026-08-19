function tests = testStage3Acceptance
%TESTSTAGE3ACCEPTANCE Pure Stage-3 acceptance and control-gate tests.
tests=functiontests(localfunctions);
end

function testPassingFixture(testCase)
cfg=stage3_config(); ids=local_ids();
p64=repmat(local_profile(),8,1); p128=p64;
for k=1:8, p64(k).case_id=char(ids(k)); p128(k).case_id=char(ids(k)); end
diag=repmat(local_profile(),16,1);
for k=1:16, diag(k).case_id=sprintf('d%d',k); end
pairs=[repmat(local_pair('ideal'),8,1);repmat(local_pair('nonideal'),23,1); ...
    local_pair('saturation_diagnostic')];
for k=1:numel(pairs), pairs(k).case_id=sprintf('pair_%d',k); end
pairs(1).case_id='fixed_00deg_e';
drift=repmat(struct('case_id','x','lut_drift_e_rad',deg2rad(0.1)),8,1);
sensitivity=repmat(struct('case_id','x','tangent_rms',0.1,'radial_rms',0.1, ...
    'lut_drift_e_rad',deg2rad(0.1),'valid_fraction',1, ...
    'finite_diagnostics',true),10,1);
[checks,aggregate]=evaluate_stage3_acceptance(p64,p128,diag,pairs, ...
    drift,sensitivity,cfg,true);
verifyTrue(testCase,checks.all_mandatory);
verifyEqual(testCase,aggregate.frozen_pair_count,32);
end

function testFloorBranchIsRecorded(testCase)
cfg=stage3_config(); pair=local_pair('ideal'); pair.case_id='periodic_2x';
pair.control_angle_improvement=0.57;
floorValue=2*pi*cfg.motor.pole_pairs/(cfg.encoder.counts_per_rev*sqrt(12));
pair.active.control_angle_rmse_e_rad=floorValue+deg2rad(0.05);
[pass,basis,details]=evaluate_stage3_pair_gate(pair, ...
    struct('case_id','periodic_2x'),cfg);
verifyTrue(testCase,pass); verifyEqual(testCase,basis,'quantization_floor');
verifyEqual(testCase,details.angle.floor_threshold_e_rad, ...
    floorValue+deg2rad(0.10),'AbsTol',1e-14);
end

function testPhysicalRegressionCannotBeHiddenByFloor(testCase)
cfg=stage3_config(); pair=local_pair('ideal'); pair.case_id='periodic_2x';
pair.control_angle_improvement=0.9; pair.id_rms_improvement=-0.021;
pass=evaluate_stage3_pair_gate(pair,struct('case_id','periodic_2x'),cfg);
verifyFalse(testCase,pass);
end

function ids=local_ids()
ids=["fixed_00deg_e","fixed_05deg_e","fixed_10deg_e","fixed_20deg_e", ...
    "periodic_constant","periodic_1x","periodic_2x","periodic_combined"];
end
function p=local_profile()
p=struct('case_id','','coverage_fraction',1,'fusion_count',19, ...
    'last_active_update_rms_e_rad',deg2rad(0.1), ...
    'previous_active_update_rms_e_rad',deg2rad(0.1), ...
    'shadow_rmse_e_rad',deg2rad(0.2),'active_rmse_e_rad',deg2rad(0.3), ...
    'active_max_error_e_rad',deg2rad(0.8),'active_improvement_fraction',0.9, ...
    'scheme4_shadow_difference_e_rad',deg2rad(0.1), ...
    'scheme4_active_difference_e_rad',deg2rad(0.1),'all_nodes_valid',true, ...
    'finite_state',true,'amplitude_constraint_satisfied',true, ...
    'monotonic_constraint_satisfied',true);
end
function p=local_pair(className)
m=struct('control_angle_rmse_e_rad',deg2rad(1), ...
    'compensation_max_abs_e_rad',deg2rad(10));
p=struct('case_id','x','expected_class',className,'baseline',m,'active',m, ...
    'control_angle_improvement',0.8,'id_rms_improvement',0.1, ...
    'prediction_residual_improvement',0.1,'torque_ripple_improvement',0.1, ...
    'iq_tracking_change',0,'mean_torque_change',0);
end
