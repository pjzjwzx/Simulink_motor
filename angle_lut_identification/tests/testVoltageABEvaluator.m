function tests = testVoltageABEvaluator
%TESTVOLTAGEABEVALUATOR Pure tests for the evaluation-only voltage A/B path.
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'));
addpath(fullfile(root,'scripts'));
addpath(fullfile(root,'src'));
end

function testIdenticalPlantAndReconstructionAreEquivalent(testCase)
[identificationBus,deployment,cfg] = fixture();
plant_vabc_V = deployment.vabc_reconstructed_V;

out = evaluate_voltage_ab(identificationBus,deployment,plant_vabc_V,cfg);

verifyEqual(testCase,out.plant_evaluation.residual_A, ...
    out.reconstructed.residual_A,'AbsTol',1e-13);
verifyEqual(testCase,out.plant_evaluation.y_A, ...
    out.reconstructed.y_A,'AbsTol',1e-13);
verifyEqual(testCase,out.plant_evaluation.z_rad, ...
    out.reconstructed.z_rad,'AbsTol',1e-13);
verifyEqual(testCase,out.delta.vabc_V,zeros(1,3),'AbsTol',1e-14);
verifyEqual(testCase,out.summary.voltage_delta_rms_V,0,'AbsTol',1e-14);
verifyEqual(testCase,out.summary.pseudo_angle_delta_rms_e_rad,0, ...
    'AbsTol',1e-13);
verifyFalse(testCase,out.summary.branches_numerically_distinct);
end

function testPlantVoltageCreatesIndependentResidual(testCase)
[identificationBus,deployment,cfg] = fixture();
plant_vabc_V = deployment.vabc_reconstructed_V + [1,-0.5,-0.5];

out = evaluate_voltage_ab(identificationBus,deployment,plant_vabc_V,cfg);

Ts_s = cfg.timing.T_ident_s;
thetaMid = identificationBus.theta_e_rad(1) + ...
    0.5*Ts_s*identificationBus.omega_e_radps(1);
deltaPredAb_A = Ts_s/cfg.motor.Ls_H * ...
    anglelut.clarke_abc([1;-0.5;-0.5]);
expectedDeltaResidual_A = anglelut.park_alphabeta(deltaPredAb_A,thetaMid).';
verifyEqual(testCase,out.delta.residual_A,expectedDeltaResidual_A, ...
    'AbsTol',1e-12);
verifyEqual(testCase,out.delta.y_A,expectedDeltaResidual_A, ...
    'AbsTol',1e-12);
verifyGreaterThan(testCase,abs(out.delta.z_rad),1e-6);
verifyTrue(testCase,out.summary.branches_numerically_distinct);
verifyEqual(testCase,out.source_a,"reconstructed_duty_vdc");
verifyEqual(testCase,out.source_b,"plant_applied_evaluation_only");
end

function testPlantVoltageCannotChangeDeploymentGate(testCase)
[identificationBus,deployment,cfg] = fixture();
plantNominal = deployment.vabc_reconstructed_V;
plantExtreme = [1e6,-5e5,-5e5];

nominal = evaluate_voltage_ab(identificationBus,deployment,plantNominal,cfg);
extreme = evaluate_voltage_ab(identificationBus,deployment,plantExtreme,cfg);

verifyEqual(testCase,nominal.valid,deployment.valid);
verifyEqual(testCase,extreme.valid,deployment.valid);
verifyEqual(testCase,extreme.summary.valid_sample_count,nnz(deployment.valid));
verifyEqual(testCase,extreme.gate_source,"reconstructed_deployment_only");
verifyGreaterThan(testCase,extreme.plant_evaluation.amplitude_A,8e5);
end

function testInvalidDeploymentSampleStaysInvalid(testCase)
[identificationBus,deployment,cfg] = fixture();
deployment.valid(:) = false;
deployment.z_rad(:) = 0;

out = evaluate_voltage_ab(identificationBus,deployment,[1e6,-5e5,-5e5],cfg);

verifyFalse(testCase,out.valid);
verifyEqual(testCase,out.plant_evaluation.z_rad,0);
verifyEqual(testCase,out.summary.valid_sample_count,0);
verifyTrue(testCase,isnan(out.summary.pseudo_angle_delta_rms_e_rad));
end

function testLeadingUnsupportedDelayRowIsSkipped(testCase)
[identificationBus,deployment,cfg] = fixture();
validPlant_vabc_V = deployment.vabc_reconstructed_V;

% interval_average intentionally emits no value before its first complete
% delayed PWM interval.  That unsupported row must remain invalid/NaN.
identificationBus.iabc_A = [nan(1,3);identificationBus.iabc_A];
identificationBus.duty_abc = [nan(1,3);identificationBus.duty_abc];
identificationBus.vdc_V = [NaN;identificationBus.vdc_V];
identificationBus.theta_e_rad = [NaN;identificationBus.theta_e_rad];
identificationBus.omega_e_radps = [NaN;identificationBus.omega_e_radps];
identificationBus.direction_sign = [NaN;identificationBus.direction_sign];

deployment.residual_A = [nan(1,2);deployment.residual_A];
deployment.y_A = [nan(1,2);deployment.y_A];
deployment.z_rad = [0;deployment.z_rad];
deployment.amplitude_A = [NaN;deployment.amplitude_A];
deployment.valid = [false;deployment.valid];
deployment.vabc_reconstructed_V = ...
    [nan(1,3);deployment.vabc_reconstructed_V];
plant_vabc_V = [nan(1,3);validPlant_vabc_V];

out = evaluate_voltage_ab(identificationBus,deployment,plant_vabc_V,cfg);

verifyFalse(testCase,out.valid(1));
verifyTrue(testCase,out.valid(2));
verifyTrue(testCase,all(isnan(out.plant_evaluation.residual_A(1,:))));
verifyTrue(testCase,all(isnan(out.plant_evaluation.y_A(1,:))));
verifyTrue(testCase,isnan(out.plant_evaluation.amplitude_A(1)));
verifyTrue(testCase,all(isnan(out.plant_evaluation.vabc_V(1,:))));
verifyEqual(testCase,out.plant_evaluation.z_rad(1),0);
verifyTrue(testCase,all(isnan(out.delta.residual_A(1,:))));
verifyTrue(testCase,isnan(out.delta.z_rad(1)));
verifyEqual(testCase,out.summary.valid_sample_count,1);
verifyEqual(testCase,out.summary.voltage_delta_rms_V,0,'AbsTol',1e-14);
verifyEqual(testCase,out.summary.residual_delta_rms_A,0,'AbsTol',1e-13);
verifyEqual(testCase,out.summary.pseudo_angle_delta_rms_e_rad,0, ...
    'AbsTol',1e-13);
verifyFalse(testCase,out.summary.branches_numerically_distinct);
end

function testTruthFieldInIdentificationBusIsRejected(testCase)
[identificationBus,deployment,cfg] = fixture();
identificationBus.theta_e_true_rad = zeros(2,1);

verifyError(testCase,@() evaluate_voltage_ab(identificationBus,deployment, ...
    deployment.vabc_reconstructed_V,cfg),'anglelut:VoltageABTruthLeak');
end

function testPlantResultCannotMasqueradeAsDeploymentInput(testCase)
[identificationBus,deployment,cfg] = fixture();
deployment.source = "plant_applied_evaluation_only";

verifyError(testCase,@() evaluate_voltage_ab(identificationBus,deployment, ...
    zeros(1,3),cfg),'anglelut:VoltageABDeploymentSource');
end

function testAnalyzerIntegrationOrderAndPrimaryPath(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
code = string(fileread(fullfile(root,'scripts','analyze_stage1_case.m')));
deploymentAt = token_position(code, ...
    'DEPLOYMENT_RESIDUAL_LOOP_USES_FORMAL_IDENTIFICATION_BUS');
truthAt = token_position(code, ...
    'FORMAL_EVALUATION_TRUTH_BUS_ASSEMBLED_AFTER_RESIDUAL');
abAt = token_position(code,'voltageAB = evaluate_voltage_ab');

verifyLessThan(testCase,deploymentAt,truthAt);
verifyLessThan(testCase,truthAt,abAt);
verifyTrue(testCase,contains(code, ...
    'metrics.rmse_e_rad = local_rms(errorEuler_rad(accepted));'));
verifyTrue(testCase,contains(code,'trace.estimate_e_rad = z_euler_rad;'));
verifyTrue(testCase,contains(code, ...
    'selectedVoltageSource = string(caseCfg.voltage_source);'));
verifyTrue(testCase,contains(code, ...
    'assert(isequal(voltageAB.valid,valid)'));
end

function testRunnerPersistsVoltageABContract(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
code = string(fileread(fullfile(root,'run_stage1.m')));
required = ["manifest.voltage_ab_contract", ...
    "manifest.voltage_ab_cases", ...
    "voltage_ab_selected_source", ...
    "voltage_ab_selected_branch_rmse_e_deg", ...
    "voltage_ab_pseudo_angle_delta_rms_e_deg", ...
    "voltage_ab_residual_delta_rms_A", ...
    "voltage_ab_voltage_delta_rms_V", ...
    "voltage_ab_branches_numerically_distinct"];
for token = required
    verifyTrue(testCase,contains(code,token), ...
        sprintf('run_stage1 is missing A/B result field %s.',token));
end
end

function testAnalyzerPersistsRequiredResidualDiagnostics(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
code = string(fileread(fullfile(root,'scripts','analyze_stage1_case.m')));
required = ["trace.y_A = y_A", ...
    "trace.residual_amplitude_A = residualAmplitude_A", ...
    "trace.expected_amplitude_A = expectedAmplitude_A", ...
    "trace.z_rk2_rad = z_rk2_rad", ...
    "trace.z_heun_rad = z_heun_rad", ...
    "trace.timestamp_ok = timestampOK", ...
    "trace.residual_ratio_ok = residualRatioOK", ...
    "trace.gates = gateTrace"];
for token = required
    verifyTrue(testCase,contains(code,token), ...
        sprintf('Analyzer does not persist required diagnostic %s.',token));
end
verifyTrue(testCase,contains(code, ...
    'gateTrace.(gateName)(k) = r.gates.(gateName);'));
end

function [identificationBus,deployment,cfg] = fixture()
cfg = default_config();
Ts_s = cfg.timing.T_ident_s;
omegaE = 100;
delta = deg2rad(5);
direction = int8(1);

expectedAmplitude_A = Ts_s*cfg.motor.psi_f_Wb*abs(omegaE)/cfg.motor.Ls_H;
rawResidual_dq_A = expectedAmplitude_A*[sin(delta);cos(delta)];
thetaMid = 0.5*Ts_s*omegaE;
measuredKp1_ab_A = -inversePark(rawResidual_dq_A,thetaMid);

s0 = validSample(0,omegaE,direction);
s1 = validSample(Ts_s,omegaE,direction);
s1.iabc_A = inverseClarke(measuredKp1_ab_A);
r = anglelut.physical_residual(s0,s1,cfg);
assert(r.valid,'The pure A/B fixture must pass the deployment gate.');

identificationBus = struct();
identificationBus.iabc_A = [s0.iabc_A.';s1.iabc_A.'];
identificationBus.duty_abc = [s0.duty_abc.';s1.duty_abc.'];
identificationBus.vdc_V = [s0.vdc_V;s1.vdc_V];
identificationBus.theta_e_rad = [s0.theta_e_rad;s1.theta_e_rad];
identificationBus.omega_e_radps = [s0.omega_e_radps;s1.omega_e_radps];
identificationBus.direction_sign = [s0.direction_sign;s1.direction_sign];

deployment = struct();
deployment.source = "reconstructed_duty_vdc";
deployment.residual_A = r.euler.residual_A.';
deployment.y_A = r.euler.y_A.';
deployment.z_rad = r.euler.z_rad;
deployment.amplitude_A = r.euler.amplitude_A;
deployment.valid = r.valid;
deployment.vabc_reconstructed_V = r.vabc_reconstructed_V.';
end

function s = validSample(timestamp_s,omegaE,direction)
s.iabc_A = zeros(3,1);
s.duty_abc = 0.5*ones(3,1);
s.vdc_V = 24;
s.theta_e_rad = 0;
s.omega_e_radps = omegaE;
s.direction_sign = direction;
s.direction_valid = true;
s.adc_valid = true;
s.encoder_valid = true;
s.pwm_saturated = false;
s.pwm_overmodulated = false;
s.min_pulse_clipped = false;
s.current_limited = false;
s.timestamp_s = timestamp_s;
s.current_timestamp_s = timestamp_s;
s.angle_timestamp_s = timestamp_s;
s.voltage_timestamp_s = timestamp_s;
end

function abc = inverseClarke(ab)
abc = [ab(1); ...
    -0.5*ab(1)+sqrt(3)*0.5*ab(2); ...
    -0.5*ab(1)-sqrt(3)*0.5*ab(2)];
end

function ab = inversePark(dq,theta)
c = cos(theta);
s = sin(theta);
ab = [c,-s;s,c]*dq;
end

function position = token_position(code,token)
matches = strfind(code,string(token));
assert(~isempty(matches),'Required integration token is missing: %s',token);
position = matches(1);
end
