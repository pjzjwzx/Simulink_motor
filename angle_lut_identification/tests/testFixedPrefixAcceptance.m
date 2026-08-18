function tests = testFixedPrefixAcceptance
%TFIXEDPREFIXACCEPTANCE Critical fixed-prefix early-stop gate behavior.
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'));
addpath(fullfile(root,'scripts'));
end

function testPassingPrefix(testCase)
cfg = default_config();
metrics = local_passing_metrics();
[passed,checks,aggregate] = evaluate_fixed_prefix_acceptance(metrics,cfg);
verifyTrue(testCase,passed);
verifyTrue(testCase,all(structfun(@logical,checks)));
verifyEqual(testCase,aggregate.fixed_fit_slope,1,'AbsTol',1e-12);
verifyEqual(testCase,aggregate.fixed_fit_intercept_e_deg,0,'AbsTol',1e-12);
end

function testFiveDegreeMeanFailure(testCase)
cfg = default_config();
metrics = local_passing_metrics();
metrics(3).mean_estimation_error_e_rad = deg2rad(0.6);
metrics(3).mean_estimation_error_e_deg = 0.6;
[passed,checks] = evaluate_fixed_prefix_acceptance(metrics,cfg);
verifyFalse(testCase,passed);
verifyFalse(testCase,checks.fixed_5deg_mean_error);
verifyTrue(testCase,checks.fixed_fit);
verifyTrue(testCase,checks.ideal_rmse);
end

function testFixedFitFailure(testCase)
cfg = default_config();
metrics = local_passing_metrics();
for k = 2:5
    metrics(k).mean_estimate_e_rad = 0;
end
[passed,checks] = evaluate_fixed_prefix_acceptance(metrics,cfg);
verifyFalse(testCase,passed);
verifyFalse(testCase,checks.fixed_fit);
end

function testIdealRmseFailure(testCase)
cfg = default_config();
metrics = local_passing_metrics();
metrics(3).rmse_e_rad = deg2rad(0.6);
[passed,checks] = evaluate_fixed_prefix_acceptance(metrics,cfg);
verifyFalse(testCase,passed);
verifyFalse(testCase,checks.ideal_rmse);
end

function testIncompletePrefixFailure(testCase)
cfg = default_config();
metrics = local_passing_metrics();
metrics(end) = [];
[passed,checks] = evaluate_fixed_prefix_acceptance(metrics,cfg);
verifyFalse(testCase,passed);
verifyFalse(testCase,checks.prefix_complete);
end

function testCaseMatrixPrefixOrder(testCase)
cfg = default_config();
cases = case_matrix(cfg);
expected = ["baseline_legacy_equivalence", ...
    "fixed_00deg_e", "fixed_05deg_e", ...
    "fixed_10deg_e", "fixed_20deg_e"];
verifyEqual(testCase,string({cases(1:5).case_id}),expected);
verifyEqual(testCase,numel(cases)-5,31);
end

function testRunnerScopeAndFullAcceptanceWiring(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
code = string(fileread(fullfile(root,'run_stage1.m')));
verifyTrue(testCase,contains(code, ...
    'if ~completeMatrix || caseIndex ~= 5'));
verifyTrue(testCase,contains(code,'if criticalEarlyStop'));
verifyTrue(testCase,contains(code, ...
    'acceptanceComplete = completeMatrix &&'));
verifyTrue(testCase,contains(code, ...
    'gate.checks.all_selected_cases_analyzed'));
verifyTrue(testCase,contains(code, ...
    'result.critical_early_stop = gate.critical_early_stop'));
end

function metrics = local_passing_metrics()
ids = ["baseline_legacy_equivalence", ...
    "fixed_00deg_e", "fixed_05deg_e", ...
    "fixed_10deg_e", "fixed_20deg_e"];
commandDeg = [0 0 5 10 20];
template = struct('case_id','', 'expected_class','ideal', ...
    'mean_estimation_error_e_rad',0, ...
    'mean_estimation_error_e_deg',0, ...
    'commanded_fixed_error_e_rad',0, ...
    'mean_estimate_e_rad',0, ...
    'rmse_e_rad',deg2rad(0.1), ...
    'rk2_rmse_e_rad',deg2rad(0.1), ...
    'heun_rmse_e_rad',deg2rad(0.1), ...
    'predictor_floor_e_rad',0, ...
    'predictor_floor_e_deg',0);
metrics = repmat(template,1,numel(ids));
for k = 1:numel(ids)
    metrics(k).case_id = char(ids(k));
    metrics(k).commanded_fixed_error_e_rad = deg2rad(commandDeg(k));
    metrics(k).mean_estimate_e_rad = deg2rad(commandDeg(k));
end
metrics(1).expected_class = 'baseline_equivalence';
end
