function tests = testStage2Harness
%TESTSTAGE2HARNESS Structure, isolation, and active-off equivalence.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
cfg = stage2_config();
testCase.TestData.cfg = cfg;
testCase.TestData.source_hash = file_sha256(cfg.project.baseline_model);
testCase.TestData.stage1_hash = file_sha256(cfg.project.harness_model);
end

function teardownOnce(testCase)
if bdIsLoaded('angle_lut_stage2_harness')
    close_system('angle_lut_stage2_harness',0);
end
if bdIsLoaded('angle_lut_harness'), close_system('angle_lut_harness',0); end
verifyEqual(testCase,file_sha256( ...
    testCase.TestData.cfg.project.baseline_model), ...
    testCase.TestData.source_hash);
verifyEqual(testCase,file_sha256( ...
    testCase.TestData.cfg.project.harness_model), ...
    testCase.TestData.stage1_hash);
end

function testSavedDefaultsAreSafe(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage2_harness_model);
mw = get_param('angle_lut_stage2_harness','ModelWorkspace');
verifyFalse(testCase,logical(mw.evalin('stage2_active_enable')));
lut = mw.evalin('stage2_runtime_lut_e_rad');
verifySize(testCase,lut,[512,1]);
verifyEqual(testCase,lut,zeros(512,1),'AbsTol',0);
verifyEqual(testCase,mw.evalin('stage2_runtime_nodes'),512);
end

function testControlAndIdentificationFramesAreSeparated(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage2_harness_model);
model = 'angle_lut_stage2_harness';
raw = get_param([model '/Position_Sensing_Encoder_Latency_Theta'], ...
    'PortHandles');
observer = get_param([model '/Stage1_Observer_Taps'],'PortHandles');
comp = get_param([model '/Stage2_Active_LUT_Compensation'],'PortHandles');
park = get_param([model '/MATLAB Function4'],'PortHandles');
antiPark = get_param([model '/MATLAB Function5'],'PortHandles');
verifyEqual(testCase,local_source(observer.Inport(5)),raw.Outport(1));
verifyEqual(testCase,local_source(comp.Inport(1)),raw.Outport(1));
verifyEqual(testCase,local_source(park.Inport(3)),comp.Outport(1));
verifyEqual(testCase,local_source(antiPark.Inport(3)),comp.Outport(1));
end

function testTruthTorqueIsSinkOnly(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage2_harness_model);
model = 'angle_lut_stage2_harness';
torqueLog = [model '/Stage2_Observer_Taps/torque_true_Nm_log'];
verifyEqual(testCase,get_param(torqueLog,'BlockType'),'ToWorkspace');
ports = get_param(torqueLog,'PortHandles');
verifyEmpty(testCase,ports.Outport);
deployFiles = {fullfile(cfg.project.root,'src','+anglelut', ...
    'scheme4_update.m'),fullfile(cfg.project.root,'src','+anglelut', ...
    'scheme4_init.m')};
for k = 1:numel(deployFiles)
    code = lower(fileread(deployFiles{k}));
    verifyFalse(testCase,contains(code,'truth'));
    verifyFalse(testCase,contains(code,'plant'));
    verifyFalse(testCase,contains(code,'torque'));
end
end

function testInheritedDisplayIsSuppressed(testCase)
cfg = testCase.TestData.cfg;
load_system(cfg.project.stage2_harness_model);
root = sfroot;
chart = root.find('-isa','Stateflow.EMChart','Path', ...
    'angle_lut_stage2_harness/MATLAB Function2');
verifyTrue(testCase,contains(chart.Script,'CMPA = 1- CMPA;'));
verifyTrue(testCase,contains(chart.Script,'CMPB = 1- CMPB;'));
verifyTrue(testCase,contains(chart.Script,'CMPC = 1- CMPC;'));
end

function testFrozenPairInitializationUsesActiveLut(testCase)
cfg=testCase.TestData.cfg; matrix=stage2_case_matrix(cfg);
c=matrix.training(4); fixedBias=c.fixed_error_e_rad/cfg.motor.pole_pairs;
runtime=c.fixed_error_e_rad*ones(cfg.stage2.runtime_nodes,1);
off=compute_frozen_equilibrium_initialization(c,cfg,fixedBias,false,runtime);
on=compute_frozen_equilibrium_initialization(c,cfg,fixedBias,true,runtime);
verifyGreaterThan(testCase,off.speed_pi_output_A,on.speed_pi_output_A);
verifyLessThan(testCase,abs(on.control_error_e_rad),deg2rad(4));
verifyGreaterThan(testCase,on.mean_torque_factor,0.99);
verifyTrue(testCase,on.frozen_compensation_applied);
end

function testActiveOffNumericallyEqualsStage1(testCase)
cfg = testCase.TestData.cfg;
matrix = stage2_case_matrix(cfg);
c = matrix.training(8);
c.stop_time_s = 0.02;
zero = zeros(cfg.stage2.runtime_nodes,1);
[stage1,~] = simulate_stage2_case(c,cfg,false,zero, ...
    'rapid-accelerator','angle_lut_harness');
[stage2,~] = simulate_stage2_case(c,cfg,false,zero, ...
    'rapid-accelerator','angle_lut_stage2_harness');
names = {'stage1_iabc_meas','stage1_duty_applied', ...
    'stage1_theta_m_raw','stage1_theta_re','stage1_vabc_plant', ...
    'stage1_omega_m_sensed'};
for k = 1:numel(names)
    a = stage1.get(names{k});
    b = stage2.get(names{k});
    verifyEqual(testCase,double(a.Time(:)),double(b.Time(:)),'AbsTol',0);
    verifyEqual(testCase,double(a.Data),double(b.Data),'AbsTol',0);
end
end

function source = local_source(port)
line = get_param(port,'Line');
assert(line ~= -1,'Missing input line.');
source = get_param(line,'SrcPortHandle');
end
