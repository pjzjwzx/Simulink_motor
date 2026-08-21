function tests = testStage4Harness
%TESTSTAGE4HARNESS Independent harness, safe defaults, and frame isolation.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
cfg = stage4_config();
guardPaths = {cfg.project.baseline_model,cfg.project.harness_model, ...
    cfg.project.stage2_harness_model,cfg.project.stage3_harness_model};
testCase.TestData.guard_paths = guardPaths;
testCase.TestData.guard_hashes = cellfun(@file_sha256,guardPaths, ...
    'UniformOutput',false);
build_stage4_harness();
testCase.TestData.cfg = cfg;
end

function teardownOnce(testCase)
for model = ["angle_lut_stage3_harness","angle_lut_stage4_harness"]
    if bdIsLoaded(model), close_system(model,0); end
end
for k = 1:numel(testCase.TestData.guard_paths)
    verifyEqual(testCase,file_sha256(testCase.TestData.guard_paths{k}), ...
        testCase.TestData.guard_hashes{k});
end
end

function testBuilderPreservesPassedHarnessHashes(testCase)
for k = 1:numel(testCase.TestData.guard_paths)
    verifyEqual(testCase,file_sha256(testCase.TestData.guard_paths{k}), ...
        testCase.TestData.guard_hashes{k});
end
end

function testSavedDefaultsAreSafe(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage4_harness_model);
mw = get_param('angle_lut_stage4_harness','ModelWorkspace');
verifyFalse(testCase,logical(mw.evalin('stage4_active_enable')));
verifyEqual(testCase,mw.evalin('stage4_runtime_lut_e_rad'), ...
    zeros(512,1),'AbsTol',0);
verifyEqual(testCase,mw.evalin('stage4_runtime_nodes'),512);
verifyEqual(testCase,get_param( ...
    'angle_lut_stage4_harness/Stage4_Active_LUT_Compensation/runtime_lut', ...
    'Value'),'stage4_runtime_lut_e_rad');
verifyEqual(testCase,get_param( ...
    'angle_lut_stage4_harness/Stage4_Active_LUT_Compensation/active_enable', ...
    'Value'),'stage4_active_enable');
end

function testRawIdentificationAndControlFramesAreSeparated(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage4_harness_model);
model = 'angle_lut_stage4_harness';
raw = get_param([model '/Position_Sensing_Encoder_Latency_Theta'], ...
    'PortHandles');
encoder = get_param([model '/Position_Sensing_Encoder'],'PortHandles');
observer = get_param([model '/Stage1_Observer_Taps'],'PortHandles');
comp = get_param([model '/Stage4_Active_LUT_Compensation'],'PortHandles');
park = get_param([model '/MATLAB Function4'],'PortHandles');
antiPark = get_param([model '/MATLAB Function5'],'PortHandles');

verifyEqual(testCase,local_source(observer.Inport(5)),raw.Outport(1));
verifyEqual(testCase,local_source(comp.Inport(1)),raw.Outport(1));
verifyEqual(testCase,local_source(comp.Inport(2)),encoder.Outport(3));
verifyEqual(testCase,local_source(park.Inport(3)),comp.Outport(1));
verifyEqual(testCase,local_source(antiPark.Inport(3)),comp.Outport(1));
end

function testStage4ObserverIsEvaluationSinkOnly(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage4_harness_model);
observer = 'angle_lut_stage4_harness/Stage4_Observer_Taps';
verifyEmpty(testCase,find_system(observer,'SearchDepth',1, ...
    'LookUnderMasks','all','BlockType','Outport'));
logs = find_system(observer,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','ToWorkspace');
variables = sort(string(get_param(logs,'VariableName')));
expected = sort(["stage4_control_theta_e","stage4_lut_compensation_e", ...
    "stage4_torque_true_Nm"].');
verifyEqual(testCase,variables,expected);
for k = 1:numel(logs)
    ports = get_param(logs{k},'PortHandles');
    verifyEmpty(testCase,ports.Outport);
end
end

function testActiveOffNumericallyEqualsStage3(testCase)
cfg = testCase.TestData.cfg;
stage3 = local_simulate('angle_lut_stage3_harness', ...
    cfg.project.stage3_harness_model,'stage3');
stage4 = local_simulate('angle_lut_stage4_harness', ...
    cfg.project.stage4_harness_model,'stage4');
names = {'stage1_iabc_meas','stage1_duty_applied','stage1_theta_m_raw', ...
    'stage1_theta_re','stage1_vabc_plant','stage1_omega_m_sensed'};
for k = 1:numel(names)
    a = stage3.get(names{k}); b = stage4.get(names{k});
    verifyEqual(testCase,double(a.Time(:)),double(b.Time(:)),'AbsTol',0);
    verifyEqual(testCase,double(a.Data),double(b.Data),'AbsTol',0);
end
verifyEqual(testCase,double(stage3.get('stage3_control_theta_e').Data), ...
    double(stage4.get('stage4_control_theta_e').Data),'AbsTol',0);
verifyEqual(testCase,double(stage3.get('stage3_lut_compensation_e').Data), ...
    double(stage4.get('stage4_lut_compensation_e').Data),'AbsTol',0);
end

function simOut = local_simulate(model,modelPath,prefix)
if ~bdIsLoaded(model), load_system(modelPath); end
simIn = Simulink.SimulationInput(model);
simIn = simIn.setVariable([prefix '_active_enable'],false, ...
    'Workspace',model);
simIn = simIn.setVariable([prefix '_runtime_lut_e_rad'],zeros(512,1), ...
    'Workspace',model);
simIn = simIn.setVariable([prefix '_runtime_nodes'],512, ...
    'Workspace',model);
simIn = simIn.setModelParameter('StopTime','0.02', ...
    'SimulationMode','rapid-accelerator','ReturnWorkspaceOutputs','on', ...
    'SaveTime','off','SaveOutput','off','SaveState','off');
simOut = sim(simIn);
end

function source = local_source(port)
line = get_param(port,'Line');
assert(line ~= -1,'Missing input line.');
source = get_param(line,'SrcPortHandle');
end
