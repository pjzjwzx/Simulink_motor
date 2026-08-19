function tests = testStage3Configuration
%TESTSTAGE3CONFIGURATION Locked Stage-3 configuration and case identities.
tests = functiontests(localfunctions);
end

function testLockedScheme5Parameters(testCase)
cfg=stage3_config();
verifyEqual(testCase,cfg.stage3.default_nodes,64);
verifyEqual(testCase,cfg.stage3.scan_nodes,[64 128]);
verifyEqual(testCase,cfg.stage3.runtime_nodes,512);
verifyEqual(testCase,cfg.stage3.mu5,0.01,'AbsTol',0);
verifyEqual(testCase,cfg.stage3.epsilon5_A2,0.01,'AbsTol',0);
verifyEqual(testCase,cfg.stage3.amplitude_floor_A,0.05,'AbsTol',0);
verifyEqual(testCase,cfg.stage3.training_mechanical_cycles,10);
verifyEqual(testCase,cfg.stage3.primary_amplitude_mode,"nominal_model");
verifyFalse(testCase,cfg.stage3.joint_parameter_identification_enabled);
verifyFalse(testCase,cfg.stage3.enable_stage4);
end

function testFloorAwareControlContract(testCase)
cfg=stage3_config(); g=cfg.gates.stage3;
floorValue=2*pi*cfg.motor.pole_pairs/(cfg.encoder.counts_per_rev*sqrt(12));
verifyEqual(testCase,g.ideal_control_angle_improvement_min,0.60,'AbsTol',0);
verifyEqual(testCase,rad2deg(floorValue), ...
    360*cfg.motor.pole_pairs/(cfg.encoder.counts_per_rev*sqrt(12)), ...
    'AbsTol',10*eps);
verifyEqual(testCase,floorValue+g.ideal_control_angle_floor_margin_e_rad, ...
    2*pi*cfg.motor.pole_pairs/(cfg.encoder.counts_per_rev*sqrt(12))+ ...
    deg2rad(0.10),'AbsTol',10*eps);
verifyEqual(testCase,cfg.gates.schema_version, ...
    "angle-lut-gates-v2-control-angle-60pct-floor-aware");
end

function testCaseMatrixIsCompleteAndStable(testCase)
matrix=stage3_case_matrix(stage3_config());
verifyNumElements(testCase,matrix.training,8);
verifyNumElements(testCase,matrix.profile_freeze,8);
verifyNumElements(testCase,matrix.validation,24);
verifyNumElements(testCase,matrix.condition_drift_ids,8);
verifyNumElements(testCase,matrix.sensitivity_ids,10);
verifyEqual(testCase,matrix.amplitude_modes, ...
    ["nominal_model","measured_magnitude","direction_normalized"]);
end

function testNonidealHasNoFloorException(testCase)
cfg=stage3_config();
pair=local_pair('nonideal',0.49,deg2rad(1));
[pass,basis]=control_angle_gate(pair,struct('case_id','nonideal_deadtime'),cfg);
verifyFalse(testCase,pass); verifyEqual(testCase,basis,'failed');
pair.control_angle_improvement=0.50;
[pass,basis]=control_angle_gate(pair,struct('case_id','nonideal_deadtime'),cfg);
verifyTrue(testCase,pass); verifyEqual(testCase,basis,'percentage');
end

function testBoundedRunnerCanOnlyReturnBlocked(testCase)
cfg=stage3_config(); code=fileread(fullfile(cfg.project.root,'run_stage3.m'));
verifyTrue(testCase,contains(code,"if ~strcmp(options.mode,'full')"));
verifyTrue(testCase,contains(code,"status='BLOCKED'"));
verifyTrue(testCase,contains(code,"if strcmp(options.mode,'bounded')"));
end

function testPublicResultContainsScheme4Comparison(testCase)
cfg=stage3_config(); code=fileread(fullfile(cfg.project.root,'run_stage3.m'));
verifyTrue(testCase,contains(code,'result.scheme4_comparison='));
verifyTrue(testCase,contains(code,"'scheme4_comparison'"));
end

function pair=local_pair(className,improvement,activeRmse)
active=struct('control_angle_rmse_e_rad',activeRmse, ...
    'compensation_max_abs_e_rad',0);
pair=struct('expected_class',className,'control_angle_improvement', ...
    improvement,'active',active);
end
