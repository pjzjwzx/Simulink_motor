function tests = testStage1Reports
%TESTSTAGE1REPORTS Small artifact-contract tests for offline reports.
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'));
addpath(fullfile(root,'scripts'));
addpath(fullfile(root,'src'));
end

function testCompleteSmallFixtureCreatesEveryArtifact(testCase)
[outDir,cleanup] = local_temp_dir(); %#ok<ASGLU>
cfg = default_config();
cfg.stage1.reference_lut_nodes = 32;
local_write_fixture(outDir,cfg);
gatePath = fullfile(outDir,'gate.json');
gateBefore = fileread(gatePath);

report = generate_stage1_reports(outDir,cfg);

required = [ ...
    "timing_timeline.png","timing_timeline.pdf", ...
    "yd_yq_trajectory.png","yd_yq_trajectory.pdf", ...
    "residual_amplitude_vs_speed.png", ...
    "residual_amplitude_vs_speed.pdf", ...
    "condition_consistency.png","condition_consistency.pdf", ...
    "time_alignment_report.csv","time_alignment_report.json", ...
    "error_budget.csv","error_budget.json", ...
    "reference_lut.csv","reference_lut.mat", ...
    "reference_lut.png","reference_lut.pdf", ...
    "gate_failures.json","gate_failures.txt", ...
    "report_manifest.json"];
for name = required
    path = fullfile(outDir,'reports',char(name));
    verifyTrue(testCase,isfile(path),sprintf('Missing report artifact %s.',name));
    info = dir(path);
    verifyGreaterThan(testCase,info.bytes,0, ...
        sprintf('Empty report artifact %s.',name));
end

verifyEqual(testCase,report.generation_status,'COMPLETE');
verifyTrue(testCase,report.offline_evaluation_only);
verifyFalse(testCase,report.mathematical_gate_modified);
verifyEqual(testCase,string(report.primary_case_id),"periodic_combined");
verifyEqual(testCase,fileread(gatePath),gateBefore, ...
    'Report generation must not edit the mathematical gate.');

lutFile = load(fullfile(outDir,'reports','reference_lut.mat'));
verifyTrue(testCase,lutFile.referenceMetadata.available);
verifyTrue(testCase,lutFile.referenceMetadata.evaluation_only);
verifyFalse(testCase,lutFile.referenceMetadata.feedback_used);
verifyGreaterThan(testCase,double( ...
    lutFile.referenceMetadata.accepted_samples),0);

gateReport = jsondecode(fileread( ...
    fullfile(outDir,'reports','gate_failures.json')));
verifyTrue(testCase,gateReport.available);
verifyEqual(testCase,gateReport.failure_count,1);
verifyFalse(testCase,gateReport.gate_modified);

alignment = jsondecode(fileread( ...
    fullfile(outDir,'reports','time_alignment_report.json')));
verifyTrue(testCase,alignment.available);
budget = jsondecode(fileread( ...
    fullfile(outDir,'reports','error_budget.json')));
verifyTrue(testCase,budget.available);
end

function testEmptyPartialRunDegradesWithoutChangingGate(testCase)
[outDir,cleanup] = local_temp_dir(); %#ok<ASGLU>
cfg = default_config();
cfg.stage1.reference_lut_nodes = 16;

report = generate_stage1_reports(outDir,cfg);

verifyEqual(testCase,report.generation_status,'COMPLETE');
verifyEqual(testCase,report.case_count_discovered,0);
verifyFalse(testCase,report.metrics_available);
verifyFalse(testCase,report.mathematical_gate_modified);
for name = ["timing_timeline","yd_yq_trajectory", ...
        "residual_amplitude_vs_speed","condition_consistency", ...
        "time_alignment_report","error_budget","reference_lut", ...
        "gate_failures"]
    artifact = local_find_artifact(report,name);
    verifyFalse(testCase,artifact.available, ...
        sprintf('%s must record available=false for an empty partial run.',name));
    verifyNotEmpty(testCase,artifact.reason);
end

lutFile = load(fullfile(outDir,'reports','reference_lut.mat'));
verifyFalse(testCase,lutFile.referenceMetadata.available);
verifyFalse(testCase,lutFile.referenceMetadata.feedback_used);
verifyEqual(testCase,double( ...
    lutFile.referenceMetadata.accepted_samples),0);
gateReport = jsondecode(fileread( ...
    fullfile(outDir,'reports','gate_failures.json')));
verifyFalse(testCase,gateReport.available);
verifyFalse(testCase,gateReport.gate_modified);
end

function testGeneratorRemainsStandaloneAndEvaluationOnly(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
runner = string(fileread(fullfile(root,'run_stage1.m')));
generator = string(fileread( ...
    fullfile(root,'scripts','generate_stage1_reports.m')));

% The helper remains a standalone offline function, while the runner calls
% it only as a durable artifact step after numerical acceptance has been
% decided. Report failure may fail the result contract, but it cannot
% rewrite a mathematical metric or threshold.
verifyTrue(testCase,contains(runner,'generate_stage1_reports'));
verifyTrue(testCase,contains(runner,'gate.checks.report_bundle_generated'));
verifyTrue(testCase,contains(runner,'completeMatrix && ~reportOK'));
verifyTrue(testCase,contains(generator, ...
    'anglelut.aggregate_reference_lut'));
verifyTrue(testCase,contains(generator, ...
    'report.offline_evaluation_only = true'));
verifyTrue(testCase,contains(generator, ...
    'report.mathematical_gate_modified = false'));
verifyFalse(testCase,contains(generator,'quality_gates'));
verifyFalse(testCase,contains(generator,'physical_residual'));
end

function local_write_fixture(outDir,cfg)
caseId = 'periodic_combined';
caseDir = fullfile(outDir,'cases',caseId);
mkdir(caseDir);
n = 160;
T = cfg.timing.T_ident_s;
t = (0:n-1).'*T;
omegaE = cfg.motor.pole_pairs*10;
thetaM = anglelut.wrap_to_2pi(2*pi*(0:n-1).'/(n-1));
truthError = cfg.motor.pole_pairs*( ...
    deg2rad(0.60)*sin(thetaM) + ...
    deg2rad(0.30)*sin(2*thetaM+pi/4));
amplitude = cfg.timing.T_ident_s*cfg.motor.psi_f_Wb* ...
    abs(omegaE)/cfg.motor.Ls_H*ones(n,1);
y = [amplitude.*sin(truthError),amplitude.*cos(truthError)];
valid = true(n,1);
valid(1) = false;

trace = struct();
trace.time_s = t;
trace.availability_time_s = t + cfg.timing.identification_event_offset_s;
trace.estimate_e_rad = truthError;
trace.truth_error_e_rad = truthError;
trace.valid = valid;
trace.evaluation_mask = true(n,1);
trace.theta_m_raw_rad = thetaM;
trace.omega_e_est_radps = omegaE*ones(n,1);
trace.direction_sign = ones(n,1,'int8');
trace.residual_A = y;
trace.y_A = y;
trace.residual_amplitude_A = amplitude;
trace.expected_amplitude_A = amplitude;
trace.z_rk2_rad = truthError + deg2rad(0.05);
trace.z_heun_rad = truthError - deg2rad(0.05);
trace.timestamp_ok = valid;
trace.residual_ratio_ok = valid;
trace.gates = struct('timestamp_ok',valid, ...
    'residual_ratio_ok',valid,'valid',valid);
trace.IdentificationBus = struct( ...
    'theta_m_raw_rad',thetaM, ...
    'theta_e_rad',cfg.motor.pole_pairs*thetaM, ...
    'omega_e_radps',omegaE*ones(n,1), ...
    'timestamp_s',t, ...
    'current_timestamp_s',t, ...
    'voltage_timestamp_s',t, ...
    'angle_timestamp_s',t);
save(fullfile(caseDir,'trace.mat'),'trace');
write_json_file(fullfile(caseDir,'case_config.json'),struct( ...
    'case_id',caseId,'extra_sensor_delay_s',0, ...
    'angle_extrapolation_enabled',false));

case_id = ["periodic_combined";"speed_pos_10";"speed_neg_10"; ...
    "load_0Nm";"load_1Nm";"load_2Nm";"Rs_plus10"; ...
    "angle_1k_extrap";"nonideal_combined"; ...
    "voltage_ab_plant_evaluation"];
group = ["periodic";"speed_direction";"speed_direction"; ...
    "load";"load";"load";"parameter_mismatch"; ...
    "angle_sampling";"nonideal";"voltage_ab"];
expected_class = ["ideal";"ideal";"ideal";"ideal";"ideal"; ...
    "ideal";"nonideal";"nonideal";"nonideal";"diagnostic"];
rmse_e_deg = [0.82;0.70;0.74;0.61;0.82;0.91;1.10;1.25;1.42;0.79];
mean_estimation_error_e_deg = [0.10;0.08;-0.11;0.04;0.10;0.13; ...
    0.18;0.21;0.25;0.09];
valid_fraction = [0.96;0.97;0.96;0.98;0.96;0.94;0.93;0.91;0.88;0.96];
predictor_floor_e_deg = 0.47*ones(size(rmse_e_deg));
voltage_reconstruction_rms_V = [5e-8;5e-8;5e-8;4e-8;5e-8; ...
    6e-8;5e-8;5e-8;0.08;0.08];
metrics = table(case_id,group,expected_class,rmse_e_deg, ...
    mean_estimation_error_e_deg,valid_fraction,predictor_floor_e_deg, ...
    voltage_reconstruction_rms_V);
writetable(metrics,fullfile(outDir,'metrics.csv'));

gate = struct('status','FAIL','checks',struct( ...
    'timing_pass',true,'ideal_rmse_pass',false), ...
    'critical_early_stop',struct('checks',struct('structure_pass',true)));
write_json_file(fullfile(outDir,'gate.json'),gate);
end

function artifact = local_find_artifact(report,name)
names = string({report.artifacts.name});
index = find(names == string(name),1);
assert(~isempty(index),'Missing artifact metadata: %s',name);
artifact = report.artifacts(index);
end

function [path,cleanup] = local_temp_dir()
path = tempname;
mkdir(path);
cleanup = onCleanup(@() rmdir(path,'s'));
end
