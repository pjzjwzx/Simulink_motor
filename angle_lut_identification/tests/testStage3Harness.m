function tests = testStage3Harness
%TESTSTAGE3HARNESS Independent harness, raw-frame isolation, and safe defaults.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
cfg=stage3_config();
if ~isfile(cfg.project.stage3_harness_model), build_stage3_harness(); end
testCase.TestData.cfg=cfg;
testCase.TestData.source_hash=file_sha256(cfg.project.baseline_model);
testCase.TestData.stage1_hash=file_sha256(cfg.project.harness_model);
testCase.TestData.stage2_hash=file_sha256(cfg.project.stage2_harness_model);
end

function teardownOnce(testCase)
if bdIsLoaded('angle_lut_stage3_harness'), close_system('angle_lut_stage3_harness',0); end
cfg=testCase.TestData.cfg;
verifyEqual(testCase,file_sha256(cfg.project.baseline_model),testCase.TestData.source_hash);
verifyEqual(testCase,file_sha256(cfg.project.harness_model),testCase.TestData.stage1_hash);
verifyEqual(testCase,file_sha256(cfg.project.stage2_harness_model),testCase.TestData.stage2_hash);
end

function testSavedDefaultsAreSafe(testCase)
cfg=testCase.TestData.cfg; load_system(cfg.project.stage3_harness_model);
mw=get_param('angle_lut_stage3_harness','ModelWorkspace');
verifyFalse(testCase,logical(mw.evalin('stage3_active_enable')));
verifyEqual(testCase,mw.evalin('stage3_runtime_lut_e_rad'),zeros(512,1),'AbsTol',0);
verifyEqual(testCase,mw.evalin('stage3_runtime_nodes'),512);
end

function testRawIdentificationAndControlFramesAreSeparated(testCase)
cfg=testCase.TestData.cfg; load_system(cfg.project.stage3_harness_model); model='angle_lut_stage3_harness';
raw=get_param([model '/Position_Sensing_Encoder_Latency_Theta'],'PortHandles');
observer=get_param([model '/Stage1_Observer_Taps'],'PortHandles');
comp=get_param([model '/Stage3_Active_LUT_Compensation'],'PortHandles');
park=get_param([model '/MATLAB Function4'],'PortHandles');
antiPark=get_param([model '/MATLAB Function5'],'PortHandles');
verifyEqual(testCase,local_source(observer.Inport(5)),raw.Outport(1));
verifyEqual(testCase,local_source(comp.Inport(1)),raw.Outport(1));
verifyEqual(testCase,local_source(park.Inport(3)),comp.Outport(1));
verifyEqual(testCase,local_source(antiPark.Inport(3)),comp.Outport(1));
end

function testTruthIsSinkOnlyAndUpdaterIsTruthFree(testCase)
cfg=testCase.TestData.cfg; load_system(cfg.project.stage3_harness_model);
log="torque_true_Nm_log";
for name=log
    blocks=find_system('angle_lut_stage3_harness/Stage3_Observer_Taps', ...
        'LookUnderMasks','all','BlockType','ToWorkspace');
    vars=string(get_param(blocks,'VariableName'));
    index=find(contains(vars,extractBefore(name,"_log")),1);
    verifyNotEmpty(testCase,index);
    ports=get_param(blocks{index},'PortHandles'); verifyEmpty(testCase,ports.Outport);
end
code=lower(fileread(fullfile(cfg.project.root,'src','+anglelut','scheme5_update.m')));
verifyFalse(testCase,contains(code,'truth')); verifyFalse(testCase,contains(code,'plant'));
verifyFalse(testCase,contains(code,'torque'));
end

function testActiveOffNumericallyEqualsStage2(testCase)
cfg=testCase.TestData.cfg; matrix=stage3_case_matrix(cfg); c=matrix.training(8);
c.stop_time_s=0.02; zero=zeros(cfg.stage3.runtime_nodes,1);
[stage2,~]=simulate_stage2_case(c,cfg,false,zero, ...
    'rapid-accelerator','angle_lut_stage2_harness');
[stage3,~]=simulate_stage2_case(c,cfg,false,zero, ...
    'rapid-accelerator','angle_lut_stage3_harness');
names={'stage1_iabc_meas','stage1_duty_applied','stage1_theta_m_raw', ...
    'stage1_theta_re','stage1_vabc_plant','stage1_omega_m_sensed'};
for k=1:numel(names)
    a=stage2.get(names{k}); b=stage3.get(names{k});
    verifyEqual(testCase,double(a.Time(:)),double(b.Time(:)),'AbsTol',0);
    verifyEqual(testCase,double(a.Data),double(b.Data),'AbsTol',0);
end
verifyEqual(testCase,double(stage2.get('stage2_control_theta_e').Data), ...
    double(stage3.get('stage3_control_theta_e').Data),'AbsTol',0);
end

function source=local_source(port)
line=get_param(port,'Line'); assert(line~=-1,'Missing input line.');
source=get_param(line,'SrcPortHandle');
end
