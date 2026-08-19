function tests = testStage2Scheme4
%TESTSTAGE2SCHEME4 Unit contracts for Stage-2 Scheme 4.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.cfg = stage2_config();
end

function testE09PeriodicContinuity(testCase)
lut = deg2rad((1:64).');
left = anglelut.periodic_lut_interp(2*pi-1e-12,lut);
right = anglelut.periodic_lut_interp(1e-12,lut);
verifyLessThan(testCase,abs(left-right),1e-9);
end

function testE20LocalUnwrapAndInnovationClip(testCase)
cfg = testCase.TestData.cfg;
cfg.stage2.initial_effective_weight_per_node = 1e9;
state = anglelut.scheme4_init64(cfg);
state.shadow_lut_e_rad(:) = deg2rad(170);
sample = local_sample(0,deg2rad(-170),1,0,0,true);
[state,event] = anglelut.scheme4_update64(state,sample,cfg);
verifyFalse(testCase,event.triggered);
% The locally unwrapped innovation is +20 degrees, not -340 degrees.
verifyEqual(testCase,state.b(1),deg2rad(190),'AbsTol',1e-12);

state = anglelut.scheme4_init64(cfg);
sample = local_sample(0,deg2rad(80),1,0,0,true);
state = anglelut.scheme4_update64(state,sample,cfg);
verifyEqual(testCase,state.b(1),cfg.stage2.innovation_clip_e_rad, ...
    'AbsTol',1e-12);
end

function testE21TwoNodeStatisticsMatchBatch(testCase)
cfg = testCase.TestData.cfg;
cfg.stage2.initial_effective_weight_per_node = 1e9;
M = 64;
alpha = 0.25;
phi = (3+alpha)*2*pi/M;
z = 0.2;
chi = 0.7;
state = anglelut.scheme4_init64(cfg);
state = anglelut.scheme4_update64(state, ...
    local_sample(phi,z,chi,0,0,true),cfg);
h = zeros(M,1);
h(4) = 1-alpha;
h(5) = alpha;
A = chi*(h*h.');
b = chi*h*z;
verifyEqual(testCase,state.diag_A,diag(A),'AbsTol',1e-14);
verifyEqual(testCase,state.neighbor_A(4),A(4,5),'AbsTol',1e-14);
verifyEqual(testCase,state.b,b,'AbsTol',1e-14);
verifyEqual(testCase,state.S,chi,'AbsTol',1e-14);
end

function testFixedSolversMatchMldivide64(testCase)
local_verify_solver(testCase,64);
end

function testFixedSolversMatchMldivide128(testCase)
local_verify_solver(testCase,128);
end

function testTriggerRequiresWeightCoverageAndTravel(testCase)
cfg = testCase.TestData.cfg;
cfg.stage2.node_min_hits = uint32(1);
cfg.stage2.node_min_weight = 0;
cfg.stage2.initial_effective_weight_per_node = 1;
cfg.stage2.initial_travel_m_rad = 2*pi;
cfg.stage2.subsequent_effective_weight_per_node = 1;
cfg.stage2.subsequent_travel_m_rad = pi;
state = anglelut.scheme4_init64(cfg);
event.triggered = false;
for k = 1:64
    phi = (k-1)*2*pi/64;
    [state,event] = anglelut.scheme4_update64(state, ...
        local_sample(phi,0,1,phi,1e-4*k,true),cfg);
end
verifyFalse(testCase,event.triggered); % full coverage, insufficient travel
[state,event] = anglelut.scheme4_update64(state, ...
    local_sample(0,0,1,2*pi,0.01,true),cfg);
verifyTrue(testCase,event.triggered);
verifyEqual(testCase,double(state.solve_count),1);
end

function testConstraintHandlingAndUncoveredProtection(testCase)
cfg = testCase.TestData.cfg;
M = 64;
active = deg2rad(linspace(-3,3,M).');
shadow = deg2rad(80*sin((0:M-1).'*2*pi/M));
valid = true(M,1);
valid(9:13) = false;
[projected,info] = anglelut.project_lut(shadow,active,valid,cfg);
verifyTrue(testCase,info.constraints_satisfied);
verifyLessThanOrEqual(testCase,max(abs(projected)), ...
    cfg.stage2.max_abs_lut_e_rad+1e-12);
verifyEqual(testCase,projected(~valid),active(~valid),'AbsTol',0);
verifyFalse(testCase,info.is_exact_euclidean_projection);
end

function testFusionRateLimitAndUncoveredProtection(testCase)
cfg = testCase.TestData.cfg;
active = zeros(64,1);
projected = deg2rad(25)*ones(64,1);
valid = true(64,1);
valid(10) = false;
[next,info] = anglelut.fuse_active_lut(active,projected,valid,cfg);
verifyLessThanOrEqual(testCase,max(abs(next-active)), ...
    cfg.stage2.max_active_step_e_rad+1e-15);
verifyEqual(testCase,next(10),active(10),'AbsTol',0);
verifyTrue(testCase,info.uncovered_unchanged);
end

function testLearningSampleRejectsTruth(testCase)
cfg = testCase.TestData.cfg;
state = anglelut.scheme4_init64(cfg);
sample = local_sample(0,0,1,0,0,true);
sample.truth_error_e_rad = 0;
verifyError(testCase,@()anglelut.scheme4_update64(state,sample,cfg), ...
    'anglelut:Scheme4SampleSchema');
end

function testStateIsFixedSizeAndStoresNoHistory(testCase)
cfg = testCase.TestData.cfg;
for M = [64,128]
    state = anglelut.scheme4_init(M,cfg);
    verifySize(testCase,state.diag_A,[M,1]);
    verifySize(testCase,state.neighbor_A,[M,1]);
    verifySize(testCase,state.b,[M,1]);
    names = lower(string(fieldnames(state)));
    verifyFalse(testCase,any(contains(names,"history") | ...
        contains(names,"sample_buffer") | contains(names,"truth")));
end
end

function testRuntime512WrapContinuity(testCase)
phi = (0:63).'*2*pi/64;
lut = deg2rad(6*sin(phi)+3*sin(2*phi+pi/4));
runtime = anglelut.resample_periodic_lut(lut,512);
verifySize(testCase,runtime,[512,1]);
left = anglelut.periodic_lut_interp(2*pi-1e-10,runtime);
right = anglelut.periodic_lut_interp(1e-10,runtime);
verifyLessThan(testCase,abs(left-right),1e-8);
end

function testDeterministicReplay(testCase)
cfg = testCase.TestData.cfg;
n = 30000;
theta = linspace(0,20*pi,n).';
trace.time_s = (0:n-1).'*cfg.timing.T_ident_s;
trace.theta_m_raw_rad = mod(theta,2*pi);
trace.theta_m_unwrapped_rad = theta;
trace.z_euler_rad = deg2rad(6*sin(theta)+3*sin(2*theta+pi/4));
trace.quality_weight = ones(n,1);
trace.valid = true(n,1);
trace.evaluation_mask = true(n,1);
trace.truth_error_e_rad = trace.z_euler_rad;
[s1,m1,h1] = stream_scheme4_trace(trace,64,cfg);
[s2,m2,h2] = stream_scheme4_trace(trace,64,cfg);
verifyEqual(testCase,s1,s2);
verifyEqual(testCase,m1,m2);
verifyEqual(testCase,h1,h2);
end

function testFrozenCompensationReducesFullPmResidual(testCase)
amplitude = ones(3,1);
truthError = deg2rad([5;10;-8]);
stage1Residual = [sin(truthError),cos(truthError)];
off = anglelut.compensated_prediction_residual( ...
    stage1Residual,amplitude,ones(3,1),zeros(3,1));
on = anglelut.compensated_prediction_residual( ...
    stage1Residual,amplitude,ones(3,1),truthError);
verifyGreaterThan(testCase,norm(off,'fro'),0.1);
verifyLessThan(testCase,norm(on,'fro'),1e-12);
end

function testLearningMetricsShowActiveFusionProgress(testCase)
M = 64;
reference.lut_e_rad = deg2rad(8*sin((0:M-1).'*2*pi/M));
reference.valid_mask = true(M,1);
history.solve_count = (1:3).';
history.sample_index = (100:100:300).';
history.time_s = [1;2;3];
history.travel_m_rad = 2*pi*[1;2;3];
history.coverage_fraction = ones(3,1);
history.reference_relative_difference = 1e-15*ones(3,1);
history.normal_equation_relative_residual = 1e-15*ones(3,1);
history.rcond = 0.2*ones(3,1);
history.active_update_rms_e_rad = deg2rad([2;1;0.5]).';
history.shadow_lut_e_rad = repmat(reference.lut_e_rad.',3,1);
history.active_lut_e_rad = [0.4;0.7;0.9].*reference.lut_e_rad.';
[metrics,summary] = compute_stage2_learning_metrics(history,reference);
verifyTrue(testCase,summary.active_rmse_monotonic_nonincreasing);
verifyTrue(testCase,summary.improvement_monotonic_nondecreasing);
verifyGreaterThan(testCase,metrics.active_improvement_percent(end), ...
    metrics.active_improvement_percent(1));
end

function local_verify_solver(testCase,M)
cfg = testCase.TestData.cfg;
state = anglelut.scheme4_init(M,cfg);
state.S = 1000;
rng(M,'twister');
state.diag_A = 10+rand(M,1);
state.neighbor_A = 0.1*rand(M,1);
state.b = randn(M,1);
reference = anglelut.scheme4_solve_reference(state);
banded = anglelut.scheme4_solve_banded(state);
relative = norm(reference.lut_e_rad-banded.lut_e_rad) / ...
    max(norm(reference.lut_e_rad),eps);
verifyLessThanOrEqual(testCase,relative,1e-9);
verifyLessThanOrEqual(testCase, ...
    banded.normal_equation_relative_residual,1e-9);
end

function sample = local_sample(phi,z,chi,travel,time,valid)
sample = struct('phi_m_rad',phi,'z_e_rad',z, ...
    'quality_weight',chi,'theta_m_unwrapped_rad',travel, ...
    'timestamp_s',time,'valid',valid);
end
