function tests = testStage4RunnerContract
%TESTSTAGE4RUNNERCONTRACT Noise scope, immutable blocker, and 2x2 identity.
tests = functiontests(localfunctions);
end

function testNoiseDefinitionIsExact(testCase)
cfg=stage4_config();
verifyEqual(testCase,cfg.stage4.noise_95_half_width_A,0.1,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.noise_sigma_A, ...
    0.1/1.959963984540054,'AbsTol',10*eps);
verifyEqual(testCase,cfg.stage4.adc_current_lsb_A,0.02442002442,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.random_seed,uint32(20260818));
end

function testDiagnosticMatrixIsTwoByTwo(testCase)
cfg=stage4_config(); matrix=stage4_noise_case_matrix(cfg);
verifyNumElements(testCase,matrix.training,2);
verifyNumElements(testCase,matrix.evaluation,2);
verifyEqual(testCase,matrix.total_frozen_simulation_count,6);
verifyTrue(testCase,matrix.cross_freeze);
verifyEqual(testCase,[matrix.training.current_noise_std_A], ...
    [0,cfg.stage4.noise_sigma_A],'AbsTol',0);
verifyEqual(testCase,matrix.training_condition, ...
    ["zero_noise","noise95_pm0p1A"]);
verifyTrue(testCase,matrix.noise_definition.adc_quantization_enabled_in_both_conditions);
end

function testRunnerCannotClaimFormalPass(testCase)
cfg=stage4_config(); code=fileread(fullfile(cfg.project.root,'run_stage4.m'));
verifyTrue(testCase,contains(code,"result.final_status='BLOCKED'"));
verifyTrue(testCase,contains(code,"'scope','NOISE_DIAGNOSTIC'"));
verifyTrue(testCase,contains(code,'formal_latest_stage4_updated'));
verifyTrue(testCase,contains(code,'latest_stage4_diagnostic.txt'));
verifyFalse(testCase,contains(code,"latest_stage4.txt'));"));
end

function testPublicResultContract(testCase)
cfg=stage4_config(); code=fileread(fullfile(cfg.project.root,'run_stage4.m'));
for token=["prerequisite_stage3","training_results","sweep_results", ...
        "scheme_comparison","frozen_matrix","result_path"]
    verifyTrue(testCase,contains(code,token),char(token));
end
verifyTrue(testCase,contains(code,'stage4_harness_sha256_before'));
verifyTrue(testCase,contains(code,'stage4_harness_sha256_after'));
end

function testStage4SimulationUsesExplicitWorkspaceParameters(testCase)
cfg=stage4_config(); code=fileread(fullfile(cfg.project.root,'scripts', ...
    'simulate_stage2_case.m'));
verifyTrue(testCase,contains(code,"'stage4_active_enable'"));
verifyTrue(testCase,contains(code,"'stage4_runtime_lut_e_rad'"));
verifyTrue(testCase,contains(code,"'stage1_current_noise_std_A'"));
verifyTrue(testCase,contains(code,"'stage1_current_noise_seed'"));
end

function testStage3HistoricalGateRemainsFail(testCase)
cfg=stage4_config(); pointer=fullfile(cfg.project.root,'results', ...
    'latest_stage3.txt');
runId=strtrim(fileread(pointer)); gate=jsondecode(fileread(fullfile( ...
    cfg.project.root,'results',runId,'stage3','gate.json')));
verifyEqual(testCase,gate.status,'FAIL');
verifyFalse(testCase,gate.checks.numeric.condition_drift);
end
