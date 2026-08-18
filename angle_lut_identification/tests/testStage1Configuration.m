function tests = testStage1Configuration
%TSTAGE1CONFIGURATION Validate the decision-complete Stage 1 contract.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.projectRoot = addProjectPaths();
end

function testDefaultEncoderAndMotorValues(testCase)
cfg = default_config();
verifyEqual(testCase, cfg.motor.pole_pairs, 21);
verifyEqual(testCase, cfg.motor.Rs_ohm, 0.09, 'AbsTol', eps);
verifyEqual(testCase, cfg.motor.Ls_H, 61e-6, 'AbsTol', eps);
verifyEqual(testCase, cfg.motor.psi_f_Wb, 0.004208, 'AbsTol', eps);
verifyEqual(testCase, cfg.motor.vdc_nominal_V, 24);
verifyEqual(testCase, cfg.timing.base_step_s, 5e-6, 'AbsTol', eps);
verifyEqual(testCase, cfg.timing.T_ident_s, 50e-6, 'AbsTol', eps);
verifyEqual(testCase, cfg.sensor.mode, uint8(1));
verifyEqual(testCase, cfg.encoder.error_mode, uint8(2));
verifyEqual(testCase, cfg.encoder.counts_per_rev, 1024);
verifyEqual(testCase, cfg.encoder.theta0_e_rad, 0);
verifyEqual(testCase, cfg.encoder.legacy_offset_e_rad, 0);
verifyEqual(testCase, rad2deg(cfg.encoder.periodic_amp1_m_rad), 0.60, ...
    'AbsTol', 10*eps);
verifyEqual(testCase, rad2deg(cfg.encoder.periodic_amp2_m_rad), 0.30, ...
    'AbsTol', 10*eps);
verifyEqual(testCase, cfg.encoder.periodic_phase2_rad, pi/4, ...
    'AbsTol', eps);
verifyEqual(testCase, rad2deg(cfg.encoder.default_peak_bound_e_rad), 18.9, ...
    'AbsTol', 100*eps);
verifyFalse(testCase, cfg.stage1.enable_lut_learning);
verifyEqual(testCase, cfg.stage1.control_compensation_e_rad, 0);
verifyEqual(testCase, cfg.random_seed, uint32(20260818));
end

function testCodeFacingResidualConfig(testCase)
cfg = default_config();
r = cfg.residual;
required = ["Ts_s", "Rs_Ohm", "Ls_H", "psi_f_Wb", ...
    "speed_observable_min_e_radps", "speed_weight_corner_e_radps", ...
    "iq_limit_A", "vdc_nominal_V", "vdc_tolerance_fraction", ...
    "timestamp_tolerance_s", "residual_ratio_min", "residual_ratio_max"];
verifyTrue(testCase, all(isfield(r, required)));
verifyEqual(testCase, r.Ts_s, cfg.timing.T_ident_s);
verifyEqual(testCase, [r.residual_ratio_min, r.residual_ratio_max], ...
    [0.25, 4]);
verifyEqual(testCase, r.vdc_tolerance_fraction, 0.10);
verifyEqual(testCase, cfg.direction.enter_threshold_e_radps, 10);
verifyEqual(testCase, cfg.direction.exit_threshold_e_radps, 5);
end

function testStageGates(testCase)
g = stage_gates();
verifyEqual(testCase, sort(g.allowed_status), sort(["PASS", "FAIL", "BLOCKED"]));
verifyEqual(testCase, rad2deg(g.stage1.fixed_5deg_mean_error_max_e_rad), ...
    0.5, 'AbsTol', 10*eps);
verifyEqual(testCase, g.stage1.fixed_fit_slope_range, [0.9, 1.1]);
verifyEqual(testCase, rad2deg(g.stage1.nonideal_rmse_max_e_rad), ...
    2, 'AbsTol', 10*eps);
verifyEqual(testCase, g.stage1.ideal_voltage_reconstruction_rms_max_V, 1e-6);
verifyEqual(testCase, g.stage1.periodic_minimum_mechanical_cycles, 4);
verifyTrue(testCase, g.stage1.stop_on_failure);
verifyFalse(testCase, g.stage1.allow_predictor_switch_to_mask_failure);
end

function testRunStage0ArtifactContract(testCase)
contract = stage0_artifact_contract();
verifyTrue(testCase, isfile(contract.entrypoint));
verifyTrue(testCase, all(arrayfun(@isfile, contract.required_project_files)));
verifyTrue(testCase, isfile(contract.latest_pointer));

runDir = strtrim(string(fileread(contract.latest_pointer)));
verifyTrue(testCase, isfolder(runDir));
for name = contract.required_run_files
    verifyTrue(testCase, isfile(fullfile(runDir, name)), ...
        sprintf('Missing Stage 0 artifact: %s', name));
end

gate = jsondecode(fileread(fullfile(runDir, 'gate.json')));
manifest = jsondecode(fileread(fullfile(runDir, 'run_manifest.json')));
result = jsondecode(fileread(fullfile(runDir, 'result.json')));
verifyTrue(testCase, any(string(gate.status) == contract.allowed_status));
verifyEqual(testCase, string(gate.status), "PASS");
verifyEqual(testCase, string(manifest.final_status), string(gate.status));
verifyEqual(testCase, string(result.final_status), string(gate.status));
verifyEqual(testCase, manifest.stage, 0);
verifyGreaterThan(testCase, manifest.baseline_elapsed_s, 0);
verifyEqual(testCase, lower(string(manifest.model_sha256_before)), ...
    lower(string(manifest.model_sha256_after)));

verifyTrue(testCase, all(isfield(gate.checks, contract.required_gate_checks)));
verifyTrue(testCase, all(structfun(@logical, gate.checks)));
verifyTrue(testCase, all(isfield(manifest, contract.required_manifest_fields)));
end

function testBusDefinitions(testCase)
d = bus_definitions(false);
identNames = string({d.IdentificationBus.Name});
truthNames = string({d.EvaluationTruthBus.Name});
verifyTrue(testCase, all(ismember(["iabc_A", "duty_abc", "vdc_V", ...
    "theta_m_raw_rad", "theta_m_unwrapped_rad", "theta_e_rad", ...
    "omega_e_radps", "direction_sign", "direction_valid", ...
    "current_timestamp_s", "angle_timestamp_s", ...
    "voltage_timestamp_s"], identNames)));
verifyTrue(testCase, all(ismember(["theta_m_true_rad", "theta_e_true_rad", ...
    "omega_m_true_radps", "omega_e_true_radps", ...
    "injected_error_e_rad", "plant_vabc_V"], truthNames)));
verifyEqual(testCase, intersect(identNames, truthNames), "timestamp_s");

withObjects = bus_definitions(true);
verifyClass(testCase, withObjects.objects.IdentificationBus, 'Simulink.Bus');
verifyClass(testCase, withObjects.objects.EvaluationTruthBus, 'Simulink.Bus');
verifyEqual(testCase, numel(withObjects.objects.IdentificationBus.Elements), ...
    numel(d.IdentificationBus));
end

function testCaseMatrixCoverageAndExplicitFields(testCase)
cfg = default_config();
cases = case_matrix(cfg);
ids = [cases.case_id];
verifyEqual(testCase, numel(unique(ids)), numel(ids));
verifyEqual(testCase, numel(cases), 36);
verifyTrue(testCase, all([cases.random_seed] == cfg.random_seed));
verifyEqual(testCase, cases(1).expected_class, "baseline_equivalence");

fixed = cases([cases.group] == "fixed_error");
verifyEqual(testCase, sort(rad2deg([fixed.fixed_error_e_rad])), [0, 5, 10, 20], ...
    'AbsTol', 1e-12);
verifyTrue(testCase, all([fixed.error_mode] == cfg.encoder.ERROR_FIXED));

speedCases = cases([cases.group] == "speed_direction");
verifyEqual(testCase, sort([speedCases.omega_m_radps]), [-20, -10, -5, 5, 10, 20]);
loadCases = cases([cases.group] == "load");
verifyEqual(testCase, sort([loadCases.load_torque_Nm]), [0, 1, 2]);

verifyTrue(testCase, any(ids == "periodic_constant"));
verifyTrue(testCase, any(ids == "periodic_1x"));
verifyTrue(testCase, any(ids == "periodic_2x"));
verifyTrue(testCase, any(ids == "periodic_combined"));
verifyTrue(testCase, any(ids == "angle_sync_20kHz"));
verifyTrue(testCase, any(ids == "angle_timestamped_1kHz"));
verifyTrue(testCase, any(ids == "nonideal_combined"));

periodic = cases([cases.group] == "periodic_error");
evaluatedCycles = abs([periodic.omega_m_radps]) .* ...
    ([periodic.stop_time_s] - cfg.simulation.steady_state_time_s) ./ (2*pi);
verifyGreaterThanOrEqual(testCase,evaluatedCycles, ...
    cfg.gates.stage1.periodic_minimum_mechanical_cycles);

for k = 1:numel(cases)
    expectedStop = 1 + max(2, 8*pi/abs(cases(k).omega_m_radps)) + ...
        cfg.simulation.identification_flush_margin_s;
    verifyEqual(testCase, cases(k).stop_time_s, expectedStop, 'AbsTol', 1e-12);
end

plantCases = cases([cases.voltage_source] == "plant_evaluation");
verifyEqual(testCase, numel(plantCases), 1);
verifyEqual(testCase, plantCases.group, "voltage_ab");
end

function testCaseStopTimesUseSuppliedConfiguration(testCase)
cfg = default_config();
cfg.simulation.steady_state_time_s = 1.25;
cfg.simulation.minimum_evaluation_time_s = 2.5;
cfg.simulation.minimum_mechanical_cycles = 5;
cases = case_matrix(cfg);
for k = 1:numel(cases)
    expectedStop = 1.25 + max(2.5, ...
        2*pi*5/abs(cases(k).omega_m_radps)) + ...
        cfg.simulation.identification_flush_margin_s;
    verifyEqual(testCase, cases(k).stop_time_s, expectedStop, ...
        'AbsTol', 1e-12);
end
end

function root = addProjectPaths()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'src'));
end
