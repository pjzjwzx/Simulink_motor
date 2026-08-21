function tests = testScheme2Core
%TESTSCHEME2CORE E40 sign, source isolation, statistics, and replay.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.cfg = stage4_config();
end

function testLockedCoreConfiguration(testCase)
cfg = testCase.TestData.cfg;
verifyEqual(testCase,cfg.stage4.default_nodes,64);
verifyEqual(testCase,cfg.stage4.scan_nodes,[64 128]);
verifyEqual(testCase,cfg.stage4.runtime_nodes,512);
verifyEqual(testCase,cfg.stage4.mu2,0.005,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.epsilon2,0.01,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.update_decimation,1);
verifyEqual(testCase,cfg.stage4.smoothing_strength,0,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.innovation_clip_e_rad,deg2rad(30), ...
    'AbsTol',0);
verifyEqual(testCase,cfg.stage4.atan2_free_epsilon_A,0.05,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.sweep_mu2,[0.0025 0.005 0.01 0.02]);
verifyEqual(testCase,cfg.stage4.sweep_epsilon2,[0 0.01 0.1]);
verifyEqual(testCase,cfg.stage4.sweep_update_decimation,[1 2 4]);
verifyEqual(testCase,cfg.stage4.sweep_smoothing_strength,[0 0.001 0.01]);
verifyEqual(testCase,cfg.stage4.sweep_gamma,[0.1 0.2 0.4]);
verifyEqual(testCase,cfg.stage4.noise_sigma_A,0.0510213456924654, ...
    'AbsTol',0);
verifyEqual(testCase,cfg.stage4.noise_95_half_width_A,0.1,'AbsTol',0);
verifyEqual(testCase,cfg.stage4.adc_current_lsb_A,0.02442002442, ...
    'AbsTol',0);
end

function testE40PositiveSignAndInnovationClip(testCase)
cfg = local_no_trigger(testCase.TestData.cfg);
state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
phi = 7.25*2*pi/64;
sample = local_atan2_sample(phi,pi/2,1,phi,1,true);
[state,event] = anglelut.scheme2_update64(state,sample,cfg);
alpha = 0.25;
h = [1-alpha;alpha];
expectedGain = cfg.stage4.mu2*sin(deg2rad(30))/( ...
    cfg.stage4.epsilon2+sum(h.^2));
expected = zeros(64,1);
expected(8) = expectedGain*h(1);
expected(9) = expectedGain*h(2);
verifyEqual(testCase,state.shadow_lut_e_rad,expected,'AbsTol',1e-14);
verifyEqual(testCase,event.innovation_e_rad,deg2rad(30),'AbsTol',1e-14);
verifyGreaterThan(testCase,event.local_step0_e_rad,0);

state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
sample.z_e_rad = -pi/2;
[state,event] = anglelut.scheme2_update64(state,sample,cfg);
verifyLessThan(testCase,event.local_step0_e_rad,0);
verifyLessThan(testCase,state.shadow_lut_e_rad(8),0);
end

function testCircularInnovationUsesShortBranch(testCase)
cfg = local_no_trigger(testCase.TestData.cfg);
state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
state.shadow_lut_e_rad([1 2]) = deg2rad(179);
sample = local_atan2_sample(0,deg2rad(-179),1,0,1,true);
[~,event] = anglelut.scheme2_update64(state,sample,cfg);
verifyEqual(testCase,event.innovation_e_rad,deg2rad(2),'AbsTol',1e-12);
end

function testAtan2FreeFormulaAndNoAtan2Call(testCase)
cfg = local_no_trigger(testCase.TestData.cfg);
state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2_FREE);
sample = local_free_sample(0,0.8,0.6,1,0,1,true);
[state,event] = anglelut.scheme2_update_atan2_free64(state,sample,cfg);
raw = 0.8/sqrt(0.8^2+0.6^2+cfg.stage4.atan2_free_epsilon_A^2);
expectedSine = min(raw,sin(cfg.stage4.innovation_clip_e_rad));
expectedStep = cfg.stage4.mu2*expectedSine/(cfg.stage4.epsilon2+1);
verifyEqual(testCase,event.raw_sine_innovation,raw,'AbsTol',1e-14);
verifyEqual(testCase,event.sine_innovation,expectedSine,'AbsTol',1e-14);
verifyEqual(testCase,state.shadow_lut_e_rad(1),expectedStep,'AbsTol',1e-14);
verifyTrue(testCase,isnan(event.innovation_e_rad));
code = lower(fileread(fullfile(cfg.project.root,'src','+anglelut', ...
    'scheme2_update_atan2_free.m')));
verifyFalse(testCase,contains(code,'atan2('));
end

function testStrictAndSeparateSampleWhitelists(testCase)
cfg = testCase.TestData.cfg;
standard = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
s = local_atan2_sample(0,0,1,0,0,true);
s.truth_error_e_rad = 0;
verifyError(testCase,@()anglelut.scheme2_update64(standard,s,cfg), ...
    'anglelut:Scheme2Atan2SampleSchema');
s = rmfield(s,'truth_error_e_rad'); s.y_d_A = 0;
verifyError(testCase,@()anglelut.scheme2_update64(standard,s,cfg), ...
    'anglelut:Scheme2Atan2SampleSchema');

diagnostic = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2_FREE);
d = local_free_sample(0,0,1,1,0,0,true); d.z_e_rad = 0;
verifyError(testCase,@()anglelut.scheme2_update_atan2_free64( ...
    diagnostic,d,cfg),'anglelut:Scheme2Atan2FreeSampleSchema');
d = rmfield(d,'z_e_rad'); d.trace = struct();
verifyError(testCase,@()anglelut.scheme2_update_atan2_free64( ...
    diagnostic,d,cfg),'anglelut:Scheme2Atan2FreeSampleSchema');
verifyError(testCase,@()anglelut.scheme2_update64(diagnostic, ...
    local_atan2_sample(0,0,1,0,0,true),cfg), ...
    'anglelut:Scheme2SourceModeMismatch');
end

function testDecimationCountsOnlyEligibleSamples(testCase)
cfg = local_no_trigger(testCase.TestData.cfg);
cfg.stage4.update_decimation = 3;
state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
invalid = local_atan2_sample(0,0,1,0,0,false);
[state,event] = anglelut.scheme2_update64(state,invalid,cfg);
verifyFalse(testCase,event.accepted);
for k = 1:2
    [state,event] = anglelut.scheme2_update64(state, ...
        local_atan2_sample(0,0.1,1,k,k,true),cfg);
    verifyTrue(testCase,event.accepted);
    verifyTrue(testCase,event.decimated);
    verifyFalse(testCase,event.updated);
end
[state,~] = anglelut.scheme2_update64(state,invalid,cfg);
[state,event] = anglelut.scheme2_update64(state, ...
    local_atan2_sample(0,0.1,1,3,3,true),cfg);
verifyTrue(testCase,event.updated);
verifyFalse(testCase,event.decimated);
verifyEqual(testCase,double(state.sample_count),5);
verifyEqual(testCase,double(state.accepted_count),3);
verifyEqual(testCase,double(state.update_count),1);
verifyEqual(testCase,double(state.decimated_count),2);
end

function testWelfordVarianceAndCumulativeGain(testCase)
cfg = local_no_trigger(testCase.TestData.cfg);
state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
z = deg2rad([5 -3 2]);
steps = zeros(numel(z),1);
for k = 1:numel(z)
    [state,event] = anglelut.scheme2_update64(state, ...
        local_atan2_sample(0,z(k),1,k,k,true),cfg);
    steps(k) = event.local_step0_e_rad;
end
verifyEqual(testCase,double(state.node_hits(1)),3);
verifyEqual(testCase,state.node_step_mean_e_rad(1),mean(steps), ...
    'AbsTol',1e-15);
verifyEqual(testCase,state.node_step_M2_e_rad2(1), ...
    sum((steps-mean(steps)).^2),'AbsTol',1e-15);
expectedGain = 3*cfg.stage4.mu2/(cfg.stage4.epsilon2+1);
verifyEqual(testCase,state.node_cumulative_gain(1),expectedGain, ...
    'AbsTol',1e-15);
end

function testExactlyTwoNodesUpdateForM64AndM128(testCase)
cfg = local_no_trigger(testCase.TestData.cfg);
for M = [64 128]
    state = anglelut.scheme2_init(M,cfg,cfg.stage4.MODE_ATAN2);
    sample = local_atan2_sample(3.4*2*pi/M,0.2,1,1,1,true);
    if M == 64
        state = anglelut.scheme2_update64(state,sample,cfg);
    else
        state = anglelut.scheme2_update128(state,sample,cfg);
    end
    verifyEqual(testCase,nnz(state.shadow_lut_e_rad),2);
end
end

function testSmootherIsPeriodicMeanPreservingAndEventOnly(testCase)
w = [1;zeros(62,1);-0.5];
smoothed = anglelut.scheme2_smooth_periodic(w,0.01);
verifyEqual(testCase,mean(smoothed),mean(w),'AbsTol',1e-15);
verifyLessThan(testCase,norm(diff([smoothed;smoothed(1)])), ...
    norm(diff([w;w(1)])));

cfg = testCase.TestData.cfg;
cfg.stage4.node_min_hits = uint32(1);
cfg.stage4.node_min_weight = 0;
cfg.stage4.initial_effective_weight_per_node = 1;
cfg.stage4.initial_travel_m_rad = 2*pi;
cfg.stage4.smoothing_strength = 0.01;
state = anglelut.scheme2_init64(cfg,cfg.stage4.MODE_ATAN2);
for k = 1:64
    phi = (k-1)*2*pi/64;
    [state,event] = anglelut.scheme2_update64(state, ...
        local_atan2_sample(phi,0.1*sin(phi),1,phi,k,true),cfg);
    verifyFalse(testCase,event.smoothing_applied);
end
[state,event] = anglelut.scheme2_update64(state, ...
    local_atan2_sample(0,0,1,2*pi,100,true),cfg);
verifyTrue(testCase,event.triggered);
verifyTrue(testCase,event.smoothing_applied);
verifyEqual(testCase,double(state.smoothing_event_count),1);
end

function testFixedStateHasNoHistoryTruthPlantOrBuffer(testCase)
cfg = testCase.TestData.cfg;
for M = [64 128]
    state = anglelut.scheme2_init(M,cfg,cfg.stage4.MODE_ATAN2);
    verifySize(testCase,state.shadow_lut_e_rad,[M 1]);
    verifySize(testCase,state.active_lut_e_rad,[M 1]);
    verifySize(testCase,state.node_step_M2_e_rad2,[M 1]);
    verifySize(testCase,state.node_cumulative_gain,[M 1]);
    names = lower(string(fieldnames(state)));
    verifyFalse(testCase,any(contains(names, ...
        ["history","truth","plant","buffer","trace"])));
end
end

function testDeterministicReplayBothModesAndRuntime512(testCase)
cfg = testCase.TestData.cfg;
trace = local_trace(cfg,26000);
for mode = ["atan2","atan2_free"]
    [s1,m1,h1,r1,l1] = stream_scheme2_trace(trace,64,cfg,mode);
    [s2,m2,h2,r2,l2] = stream_scheme2_trace(trace,64,cfg,mode);
    verifyEqual(testCase,s1,s2);
    verifyEqual(testCase,m1,m2);
    verifyEqual(testCase,h1,h2);
    verifyEqual(testCase,r1,r2);
    verifyEqual(testCase,l1,l2);
    verifySize(testCase,l1,[512 1]);
    verifyGreaterThan(testCase,double(s1.fusion_count),0);
    verifyFalse(testCase,isfield(s1,'history'));
end
end

function testFixedWrappersPassCodeGenerationScreener(testCase)
info = coder.screener('anglelut.scheme2_update64', ...
    'anglelut.scheme2_update128', ...
    'anglelut.scheme2_update_atan2_free64', ...
    'anglelut.scheme2_update_atan2_free128');
verifyEmpty(testCase,info.Messages);
verifyEmpty(testCase,info.UnsupportedCalls);
end

function cfg = local_no_trigger(cfg)
cfg.stage4.initial_effective_weight_per_node = 1e12;
cfg.stage4.subsequent_effective_weight_per_node = 1e12;
end

function sample = local_atan2_sample(phi,z,chi,travel,time,valid)
sample = struct('phi_m_rad',phi,'z_e_rad',z,'quality_weight',chi, ...
    'theta_m_unwrapped_rad',travel,'timestamp_s',time,'valid',valid);
end

function sample = local_free_sample(phi,yd,yq,chi,travel,time,valid)
sample = struct('phi_m_rad',phi,'y_d_A',yd,'y_q_A',yq, ...
    'quality_weight',chi,'theta_m_unwrapped_rad',travel, ...
    'timestamp_s',time,'valid',valid);
end

function trace = local_trace(cfg,n)
theta = linspace(0,20*pi,n).';
truth = deg2rad(6*sin(theta)+3*sin(2*theta+pi/4));
trace = struct('time_s',(0:n-1).'*cfg.timing.T_ident_s, ...
    'theta_m_raw_rad',mod(theta,2*pi), ...
    'theta_m_unwrapped_rad',theta,'z_euler_rad',truth, ...
    'y_A',[sin(truth),cos(truth)],'quality_weight',ones(n,1), ...
    'valid',true(n,1),'evaluation_mask',true(n,1), ...
    'truth_error_e_rad',truth);
end
