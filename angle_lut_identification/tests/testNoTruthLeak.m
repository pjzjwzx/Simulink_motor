function tests = testNoTruthLeak
%TNOTRUTHLEAK Structural truth-isolation checks for deployment code.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.projectRoot = addProjectPaths();
end

function testIdentificationBusContainsNoTruthFields(testCase)
d = bus_definitions(false);
identNames = lower(string({d.IdentificationBus.Name}));
forbidden = lower(["theta_m_true_rad", "theta_e_true_rad", ...
    "omega_m_true_radps", "omega_e_true_radps", ...
    "injected_error_m_rad", "injected_error_e_rad", ...
    "plant_vabc_V", "plant_vdq_V"]);
verifyEmpty(testCase, intersect(identNames, forbidden));
end

function testDeploymentSourcesDoNotReferenceTruthInterface(testCase)
root = testCase.TestData.projectRoot;
sourceDir = fullfile(root, 'src', '+anglelut');
deploymentFiles = ["physical_residual.m", "quality_gates.m", ...
    "reconstruct_voltage.m", "estimate_speed_step.m", ...
    "direction_hysteresis.m"];
forbidden = ["EvaluationTruthBus", "theta_m_true", "theta_e_true", ...
    "omega_m_true", "omega_e_true", "injected_error", ...
    "plant_vabc", "plant_vdq"];
for file = deploymentFiles
    path = fullfile(sourceDir, file);
    assert(isfile(path), 'Required deployment source is missing: %s', path);
    code = string(fileread(path));
    for token = forbidden
        verifyFalse(testCase, contains(code, token, 'IgnoreCase', true), ...
            sprintf('%s references forbidden truth token "%s".', file, token));
    end
end
end

function testOnlySimulationOrEvaluationFunctionsAcceptTruth(testCase)
root = testCase.TestData.projectRoot;
sourceDir = fullfile(root, 'src', '+anglelut');
allowedTruthConsumers = ["encoder_forward_model.m", ...
    "aggregate_reference_lut.m"];
files = dir(fullfile(sourceDir, '*.m'));
for k = 1:numel(files)
    code = string(fileread(fullfile(files(k).folder, files(k).name)));
    usesTruth = contains(code, "theta_true", 'IgnoreCase', true) ...
        || contains(code, "true_error", 'IgnoreCase', true);
    if usesTruth
        verifyTrue(testCase, any(string(files(k).name) == allowedTruthConsumers), ...
            sprintf('Unexpected truth consumer: %s', files(k).name));
    end
end
end

function testSignalMapMarksPlantVoltageEvaluationOnly(testCase)
map = signal_map();
verifyEqual(testCase, map.truth.plant_vabc_V.source_block, ...
    "FOC_fw_hifi_v1_0709backup/Inverter_Nonideal");
verifyTrue(testCase, any(map.forbidden_identification_sources == "plant_vabc_V"));
verifyTrue(testCase, contains(map.truth_use_policy, "evaluation", ...
    'IgnoreCase', true));
end

function testHarnessBuilderDoesNotMislabelRawSourceBuses(testCase)
root = testCase.TestData.projectRoot;
builder = string(fileread(fullfile(root,'models','build_angle_lut_harness.m')));

verifyTrue(testCase,contains(builder,'RawIdentificationSourceBus_Creator'));
verifyTrue(testCase,contains(builder,'RawEvaluationTruthSourceBus_Creator'));
verifyTrue(testCase,contains(builder,'stage1_raw_identification_source_bus'));
verifyTrue(testCase,contains(builder,'stage1_raw_evaluation_truth_source_bus'));
verifyFalse(testCase,contains(builder,"[observer '/IdentificationBus_Creator']"));
verifyFalse(testCase,contains(builder,"[observer '/EvaluationTruthBus_Creator']"));
verifyFalse(testCase,contains(builder,"'VariableName', 'stage1_identification_bus'"));
verifyFalse(testCase,contains(builder,"'VariableName', 'stage1_truth_bus'"));
end

function testFormalBusAssemblyPolicyIsExplicit(testCase)
d = bus_definitions(false);
map = signal_map();
verifyTrue(testCase,contains(d.source_bus_policy, ...
    'IdentificationBus must be assembled completely before the residual loop'));
verifyTrue(testCase,contains(d.source_bus_policy, ...
    'EvaluationTruthBus is assembled only after that loop'));
verifyEqual(testCase,map.raw_source_buses.identification, ...
    "RawIdentificationSourceBus");
verifyEqual(testCase,map.raw_source_buses.truth, ...
    "RawEvaluationTruthSourceBus");
end

function testAnalyzerUsesFormalIdentificationBusBeforeResidual(testCase)
root = testCase.TestData.projectRoot;
code = string(fileread(fullfile(root,'scripts','analyze_stage1_case.m')));

assemblyPosition = local_token_position(code, ...
    'FORMAL_IDENTIFICATION_BUS_ASSEMBLED_BEFORE_RESIDUAL');
loopPosition = local_token_position(code, ...
    'DEPLOYMENT_RESIDUAL_LOOP_USES_FORMAL_IDENTIFICATION_BUS');
truthPosition = local_token_position(code, ...
    'FORMAL_EVALUATION_TRUTH_BUS_ASSEMBLED_AFTER_RESIDUAL');
verifyLessThan(testCase,assemblyPosition,loopPosition);
verifyLessThan(testCase,loopPosition,truthPosition);
verifyTrue(testCase,contains(code, ...
    'local_assert_bus_schema(identificationBus,''IdentificationBus'')'));
verifyTrue(testCase,contains(code, ...
    's0 = local_identification_sample(identificationBus,k)'));
verifyTrue(testCase,contains(code, ...
    's1 = local_identification_sample(identificationBus,k+1)'));
verifyTrue(testCase,contains(code, ...
    'trace.IdentificationBus = local_bus_rows(identificationBus,1:n-1)'));
verifyTrue(testCase,contains(code, ...
    'trace.EvaluationTruthBus = evaluationTruthBus'));
end

function testIdentificationSampleAdapterCannotCaptureRawOrTruthArrays(testCase)
root = testCase.TestData.projectRoot;
code = string(fileread(fullfile(root,'scripts','analyze_stage1_case.m')));
startToken = 'function sample = local_identification_sample';
endToken = 'function local_assert_bus_schema';
startPosition = local_token_position(code,startToken);
endPosition = local_token_position(code,endToken);
adapter = extractBetween(code,startPosition,endPosition-1);

verifyTrue(testCase,contains(adapter, ...
    'local_identification_sample(identificationBus,index)'));
forbidden = ["simOut", "EvaluationTruthBus", "evaluationTruthBus", ...
    "theta_e_true", "omega_m_true", "injected_error", "plant_vabc", ...
    "duty_effective(index", "theta_e_raw_rad(index", ...
    "omega_e_est_radps(index"];
for token = forbidden
    verifyFalse(testCase,contains(adapter,token), ...
        sprintf('Formal sample adapter references forbidden source "%s".',token));
end
verifyTrue(testCase,contains(adapter,'identificationBus.iabc_A(index,:)'));
verifyTrue(testCase,contains(adapter,'identificationBus.voltage_timestamp_s(index)'));
end

function testSavedRawTruthSourceBusIsSinkOnly(testCase)
root = testCase.TestData.projectRoot;
harnessPath = fullfile(root,'models','angle_lut_harness.slx');
verifyTrue(testCase,isfile(harnessPath));
[~,model] = fileparts(harnessPath);
load_system(harnessPath);
cleanup = onCleanup(@() close_system(model,0));

observer = [model '/Stage1_Observer_Taps'];
truthCreator = [observer '/RawEvaluationTruthSourceBus_Creator'];
identCreator = [observer '/RawIdentificationSourceBus_Creator'];
verifyGreaterThan(testCase,getSimulinkBlockHandle(truthCreator),0);
verifyGreaterThan(testCase,getSimulinkBlockHandle(identCreator),0);
verifyEqual(testCase,getSimulinkBlockHandle( ...
    [observer '/EvaluationTruthBus_Creator']),-1);
verifyEqual(testCase,getSimulinkBlockHandle( ...
    [observer '/IdentificationBus_Creator']),-1);

ports = get_param(truthCreator,'PortHandles');
lineHandle = get_param(ports.Outport(1),'Line');
verifyNotEqual(testCase,lineHandle,-1);
destinations = get_param(lineHandle,'DstBlockHandle');
destinations = destinations(destinations ~= -1);
verifyNumElements(testCase,destinations,1);
verifyEqual(testCase,get_param(destinations,'BlockType'),'ToWorkspace');
verifyEqual(testCase,get_param(destinations,'VariableName'), ...
    'stage1_raw_evaluation_truth_source_bus');
end

function position = local_token_position(code,token)
locations = strfind(code,string(token));
assert(isscalar(locations),'Expected exactly one token "%s".',token);
position = locations(1);
end

function root = addProjectPaths()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'src'));
end
