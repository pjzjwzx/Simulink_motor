function tests = testStage2Configuration
%TESTSTAGE2CONFIGURATION Configuration, gate, and artifact contracts.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.cfg = stage2_config();
testCase.TestData.matrix = stage2_case_matrix(testCase.TestData.cfg);
end

function testFrozenConfigurationValues(testCase)
cfg = testCase.TestData.cfg;
verifyEqual(testCase,cfg.stage2.default_nodes,64);
verifyEqual(testCase,cfg.stage2.scan_nodes,[64 128]);
verifyEqual(testCase,cfg.stage2.runtime_nodes,512);
verifyEqual(testCase,cfg.stage2.rho,1);
verifyEqual(testCase,cfg.stage2.lambda_s_at_128,1e-4);
verifyEqual(testCase,cfg.stage2.lambda0,1e-6);
verifyEqual(testCase,cfg.stage2.gamma,0.2);
verifyEqual(testCase,cfg.stage2.innovation_clip_e_rad,deg2rad(30));
verifyEqual(testCase,cfg.stage2.max_abs_lut_e_rad,deg2rad(25));
verifyEqual(testCase,cfg.stage2.max_active_step_e_rad,deg2rad(2));
verifyEqual(testCase,cfg.stage2.monotonic_margin,0.1);
verifyFalse(testCase,cfg.stage2.enable_stage3);
end

function testEightTrainingProfiles(testCase)
cfg = testCase.TestData.cfg;
training = testCase.TestData.matrix.training;
verifyEqual(testCase,numel(training),8);
verifyEqual(testCase,unique([training.omega_m_radps]),10);
verifyEqual(testCase,unique([training.load_torque_Nm]),1);
verifyEqual(testCase,unique([training.angle_sample_Hz]), ...
    cfg.timing.angle_sync_sample_Hz);
expected = ["fixed_00deg_e","fixed_05deg_e","fixed_10deg_e", ...
    "fixed_20deg_e","periodic_constant","periodic_1x", ...
    "periodic_2x","periodic_combined"];
verifyEqual(testCase,string({training.case_id}),expected);
end

function testFrozenMatrixAndSaturationIdentity(testCase)
validation = testCase.TestData.matrix.validation;
verifyEqual(testCase,numel(validation),24);
verifyEqual(testCase,numel(unique(string({validation.case_id}))),24);
index = string({validation.case_id}) == "stage2_pwm_saturation";
verifyEqual(testCase,nnz(index),1);
verifyEqual(testCase,validation(index).omega_m_radps,20);
verifyEqual(testCase,validation(index).load_torque_Nm,2);
verifyEqual(testCase,validation(index).vdc_override_V,18);
verifyEqual(testCase,validation(index).stage2_expected_class, ...
    "saturation_diagnostic");
end

function testFormalStage1PrerequisiteExists(testCase)
cfg = testCase.TestData.cfg;
path = fullfile(cfg.project.root,'results', ...
    char(cfg.stage2.prerequisite_stage1_run_id),'stage1');
gate = jsondecode(fileread(fullfile(path,'gate.json')));
result = jsondecode(fileread(fullfile(path,'result.json')));
verifyEqual(testCase,gate.status,'PASS');
verifyEqual(testCase,gate.scope,'FULL_STAGE1');
verifyEqual(testCase,result.final_status,'PASS');
end

function testPrereigsteredThresholds(testCase)
g = testCase.TestData.cfg.gates.stage2;
verifyEqual(testCase,g.solver_relative_difference_max,1e-9);
verifyEqual(testCase,g.normal_equation_relative_residual_max,1e-9);
verifyEqual(testCase,g.rcond_min,1e-8);
verifyEqual(testCase,g.solve_count_min,18);
verifyEqual(testCase,g.nonzero_lut_improvement_min,0.8);
verifyEqual(testCase,g.ideal_control_angle_improvement_min,0.6);
verifyEqual(testCase,g.ideal_control_angle_floor_margin_e_rad,deg2rad(0.1));
verifyEqual(testCase,g.nonideal_control_angle_improvement_min,0.5);
end

function testNoPinvAndNoTruthInDeploymentLearning(testCase)
cfg = testCase.TestData.cfg;
files = {'scheme4_update.m','scheme4_solve_reference.m', ...
    'scheme4_solve_banded.m','project_lut.m','fuse_active_lut.m'};
for k = 1:numel(files)
    code = lower(fileread(fullfile(cfg.project.root,'src','+anglelut', ...
        files{k})));
    verifyFalse(testCase,contains(code,'pinv('));
    verifyFalse(testCase,contains(code,'truth'));
    verifyFalse(testCase,contains(code,'plant'));
end
end

function testRunnerReturnAndArtifactContractIsPresent(testCase)
cfg = testCase.TestData.cfg;
code = fileread(fullfile(cfg.project.root,'run_stage2.m'));
required = {'run_id','final_status','training_results','frozen_cases', ...
    'node_scan','result_path','configuration.json','metrics.csv', ...
    'gate.json','result.json','run_manifest.json','tests.csv', ...
    'file_inventory.csv','latest_stage2.txt'};
for k = 1:numel(required)
    verifyTrue(testCase,contains(code,required{k}),required{k});
end
verifyTrue(testCase,contains(code,"generate_stage2_reports"));
end

function testSignedIqRegressionTreatsImprovementAsSafe(testCase)
baseline = local_frozen('x','ideal',10,2,3,4,5,6);
active = local_frozen('x','ideal',2,1,1,1,1,6);
pair = pair_stage2_metrics(baseline,active);
verifyLessThan(testCase,pair.iq_tracking_change,0);
verifyGreaterThan(testCase,pair.control_angle_improvement,0);
end

function value = local_frozen(id,className,angle,idr,iq,residual,torqueRipple,meanTorque)
value = struct('case_id',id,'active_enable',false, ...
    'expected_class',className,'sample_count',100, ...
    'control_angle_rmse_e_rad',angle,'control_angle_rmse_e_deg',rad2deg(angle), ...
    'id_rms_A',idr,'iq_tracking_rmse_A',iq, ...
    'prediction_residual_rms_A',residual,'mean_torque_Nm',meanTorque, ...
    'torque_ripple_rms_Nm',torqueRipple,'compensation_rms_e_rad',0, ...
    'compensation_max_abs_e_rad',0,'elapsed_s',0);
end
